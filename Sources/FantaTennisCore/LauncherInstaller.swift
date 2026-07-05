import Crypto
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum LauncherInstallError: Error, CustomStringConvertible {
    case missingExtractor
    case missingSeedLauncher(String)
    case unexpectedArchiveHash(expected: String, actual: String)
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

    public func writeRuntimeWrapper(in directory: URL, winePath: String?) throws -> URL {
        let wrapper = directory.appending(path: "run-windows-client.command")
        let launcherPath = config.seedLauncherPath
        let launcher = directory.appending(path: launcherPath)
        guard fileManager.fileExists(atPath: launcher.path) else {
            throw LauncherInstallError.missingSeedLauncher(launcherPath)
        }
        let runtime = winePath ?? "wine"
        let script = """
        #!/bin/sh
        cd "$(dirname "$0")"
        if ! command -v "\(runtime)" >/dev/null 2>&1; then
          echo "Wine or CrossOver is required to run \(launcherPath) on macOS."
          exit 69
        fi
        exec "\(runtime)" "\(launcherPath)"
        """
        try script.write(to: wrapper, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wrapper.path)
        return wrapper
    }

    public static func resolveWindowsRuntime(pathEnvironment: String? = ProcessInfo.processInfo.environment["PATH"]) -> String? {
        findExecutable("wine", pathEnvironment: pathEnvironment)
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
}
