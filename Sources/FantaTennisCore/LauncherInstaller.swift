import Crypto
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum LauncherInstallError: Error, CustomStringConvertible {
    case missingExtractor
    case missingSeedLauncher(String)
    case unexpectedArchiveHash(expected: String, actual: String)
    case unexpectedFileDigest(path: String, expected: String, actual: String)
    case unexpectedFileSize(path: String, expected: Int, actual: Int)
    case processFailed(command: String, status: Int32)
    case httpDownloadFailed(URL, Int)
    case invalidHTTPResponse(URL)

    public var description: String {
        switch self {
        case .missingExtractor:
            "7z or 7zz is required to extract the official FantaTennis.7z archive."
        case let .missingSeedLauncher(path):
            "The installed launcher seed is missing at \(path)."
        case let .unexpectedArchiveHash(expected, actual):
            "Downloaded FantaTennis.7z SHA-256 \(actual) did not match expected \(expected)."
        case let .unexpectedFileDigest(path, expected, actual):
            "\(path) MD5 \(actual) did not match expected \(expected)."
        case let .unexpectedFileSize(path, expected, actual):
            "\(path) size \(actual) did not match expected \(expected)."
        case let .processFailed(command, status):
            "\(command) exited with status \(status)."
        case let .httpDownloadFailed(url, status):
            "Download failed for \(url.absoluteString) with HTTP \(status)."
        case let .invalidHTTPResponse(url):
            "No HTTP status was returned for \(url.absoluteString)."
        }
    }
}

public struct LauncherInstaller {
    public let config: LauncherConfig
    public let fileManager: FileManager

    public init(config: LauncherConfig = .official, fileManager: FileManager = .default) {
        self.config = config
        self.fileManager = fileManager
    }

    public func probe(_ url: URL) async throws -> EndpointProbe {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LauncherInstallError.invalidHTTPResponse(url)
        }
        return EndpointProbe(url: url, statusCode: http.statusCode)
    }

    public func downloadSeedArchive(to archiveURL: URL) async throws -> String {
        try fileManager.createDirectory(
            at: archiveURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let (temporaryURL, response) = try await URLSession.shared.download(from: config.seedArchiveURL)
        guard let http = response as? HTTPURLResponse else {
            throw LauncherInstallError.invalidHTTPResponse(config.seedArchiveURL)
        }
        guard 200 ..< 300 ~= http.statusCode else {
            throw LauncherInstallError.httpDownloadFailed(config.seedArchiveURL, http.statusCode)
        }
        let actualHash = try sha256(of: temporaryURL)
        guard actualHash == config.seedArchiveSHA256 else {
            throw LauncherInstallError.unexpectedArchiveHash(expected: config.seedArchiveSHA256, actual: actualHash)
        }
        if fileManager.fileExists(atPath: archiveURL.path) {
            try fileManager.removeItem(at: archiveURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: archiveURL)
        return actualHash
    }

    public func fetchUpdateManifest() async throws -> UpdateManifest {
        let (data, response) = try await URLSession.shared.data(from: config.updaterManifestURL)
        guard let http = response as? HTTPURLResponse else {
            throw LauncherInstallError.invalidHTTPResponse(config.updaterManifestURL)
        }
        guard 200 ..< 300 ~= http.statusCode else {
            throw LauncherInstallError.httpDownloadFailed(config.updaterManifestURL, http.statusCode)
        }
        let text = String(decoding: data, as: UTF8.self)
        return try UpdateManifest(text: text)
    }

    @discardableResult
    public func downloadPayload(
        manifest: UpdateManifest,
        destination: URL,
        limit: Int? = nil,
        progress: ((UpdateManifestEntry, Int, Int) -> Void)? = nil
    ) async throws -> [UpdateManifestEntry] {
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        let selected = Array(manifest.entries.prefix(limit ?? manifest.entries.count))
        for (index, entry) in selected.enumerated() {
            progress?(entry, index + 1, selected.count)
            let target = destination.appending(path: entry.relativePath)
            if try fileMatches(entry: entry, at: target) {
                continue
            }
            try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            let remote = config.updaterBaseURL.appending(path: entry.relativePath)
            let (temporaryURL, response) = try await URLSession.shared.download(from: remote)
            guard let http = response as? HTTPURLResponse else {
                throw LauncherInstallError.invalidHTTPResponse(remote)
            }
            guard 200 ..< 300 ~= http.statusCode else {
                throw LauncherInstallError.httpDownloadFailed(remote, http.statusCode)
            }
            if fileManager.fileExists(atPath: target.path) {
                try fileManager.removeItem(at: target)
            }
            try fileManager.moveItem(at: temporaryURL, to: target)
            try verify(entry: entry, at: target)
        }
        return selected
    }

    public func extractSeedArchive(archiveURL: URL, destination: URL) throws -> [String] {
        let extractor = try Self.locateExtractor()
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: extractor)
        process.arguments = ["x", "-y", archiveURL.path, "-o\(destination.path)"]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw LauncherInstallError.processFailed(command: extractor, status: process.terminationStatus)
        }
        return try extractedRelativeFiles(in: destination)
    }

    public func writeRuntimeWrapper(
        in directory: URL,
        launcherPath: String? = nil,
        runtime: WindowsRuntime?
    ) throws -> URL {
        let wrapper = directory.appending(path: "run-windows-client.command")
        let launcherPath = launcherPath ?? config.seedLauncherPath
        let launcher = directory.appending(path: launcherPath)
        guard fileManager.fileExists(atPath: launcher.path) else {
            throw LauncherInstallError.missingSeedLauncher(launcherPath)
        }
        let script = Self.runtimeWrapperScript(launcherPath: launcherPath, runtime: runtime)
        try script.write(to: wrapper, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wrapper.path)
        return wrapper
    }

    public func writeRuntimeWrapper(
        in directory: URL,
        launcherPath: String? = nil,
        winePath: String?
    ) throws -> URL {
        let runtime = winePath.map { WindowsRuntime(kind: .wine, executablePath: $0, bottleName: nil) }
        return try writeRuntimeWrapper(in: directory, launcherPath: launcherPath, runtime: runtime)
    }

    public static func relativePath(of file: URL, under base: URL) -> String {
        let fileComponents = file.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        let baseComponents = base.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        let sharedCount = zip(fileComponents, baseComponents).prefix { $0 == $1 }.count
        let relativeComponents = fileComponents.dropFirst(sharedCount)
        return relativeComponents.joined(separator: "/")
    }

    public func sha256(of url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public func md5(of url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func locateExtractor(pathEnvironment: String? = ProcessInfo.processInfo.environment["PATH"]) throws -> String {
        for name in ["7z", "7zz"] {
            if let found = findExecutable(name, pathEnvironment: pathEnvironment) {
                return found
            }
        }
        throw LauncherInstallError.missingExtractor
    }

    public static func findExecutable(_ name: String, pathEnvironment: String?) -> String? {
        for directory in (pathEnvironment ?? "").split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory)).appending(path: name).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    private func extractedRelativeFiles(in destination: URL) throws -> [String] {
        guard let enumerator = fileManager.enumerator(at: destination, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return []
        }
        return try enumerator.compactMap { item -> String? in
            guard let file = item as? URL else { return nil }
            let values = try file.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { return nil }
            return Self.relativePath(of: file, under: destination)
        }.sorted()
    }

    private func fileMatches(entry: UpdateManifestEntry, at url: URL) throws -> Bool {
        guard fileManager.fileExists(atPath: url.path) else { return false }
        do {
            try verify(entry: entry, at: url)
            return true
        } catch {
            return false
        }
    }

    private func verify(entry: UpdateManifestEntry, at url: URL) throws {
        let size = try fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber
        let actualSize = size?.intValue ?? -1
        guard actualSize == entry.byteCount else {
            throw LauncherInstallError.unexpectedFileSize(
                path: entry.relativePath,
                expected: entry.byteCount,
                actual: actualSize
            )
        }
        let actualMD5 = try md5(of: url)
        guard actualMD5 == entry.md5 else {
            throw LauncherInstallError.unexpectedFileDigest(
                path: entry.relativePath,
                expected: entry.md5,
                actual: actualMD5
            )
        }
    }
}
