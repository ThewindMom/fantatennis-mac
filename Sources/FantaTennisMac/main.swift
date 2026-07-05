import FantaTennisCore
import Foundation

@main
struct FantaTennisMac {
    static func main() async {
        do {
            try await run(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            Foundation.exit(1)
        }
    }

    static func run(arguments: [String]) async throws {
        let command = arguments.first ?? "help"
        switch command {
        case "inspect":
            printInspect()
        case "doctor":
            try await doctor()
        case "install":
            try await install(arguments: Array(arguments.dropFirst()))
        case "help", "--help", "-h":
            printHelp()
        default:
            throw CLIError.unknownCommand(command)
        }
    }

    private static func printInspect() {
        let config = LauncherConfig.official
        print("""
        \(config.title)
        seedArchive=\(config.seedArchiveURL.absoluteString)
        updaterBase=\(config.updaterBaseURL.absoluteString)
        launchFile=\(config.launchFile)
        news=\(config.newsURL.absoluteString)
        ranking=\(config.rankingURL.absoluteString)
        register=\(config.registerURL.absoluteString)
        discord=\(config.discordURL.absoluteString)
        """)
    }

    private static func doctor() async throws {
        let installer = LauncherInstaller()
        let urls = [
            LauncherConfig.official.seedArchiveURL,
            LauncherConfig.official.updaterBaseURL,
            LauncherConfig.official.newsURL,
            LauncherConfig.official.rankingURL,
        ]
        for url in urls {
            let probe = try await installer.probe(url)
            print("\(probe.state.rawValue)\t\(probe.statusCode)\t\(url.absoluteString)")
        }
        print("extractor\t\(try LauncherInstaller.locateExtractor())")
        print("windowsRuntime\t\(LauncherInstaller.resolveWindowsRuntime() ?? "missing")")
    }

    private static func install(arguments: [String]) async throws {
        let destination = try destinationURL(from: arguments)
        let installer = LauncherInstaller()
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let archive = destination.appending(path: "FantaTennis.7z")
        let sha = try await installer.downloadSeedArchive(to: archive)
        let extracted = try installer.extractSeedArchive(
            archiveURL: archive,
            destination: destination.appending(path: "ClientSeed", directoryHint: .isDirectory)
        )
        let wine = LauncherInstaller.resolveWindowsRuntime()
        _ = try installer.writeRuntimeWrapper(in: destination, winePath: wine)
        let report = InstallReport(
            installDirectory: destination,
            seedArchiveSHA256: sha,
            extractedFiles: extracted,
            winePath: wine,
            config: .official
        )
        let reportURL = destination.appending(path: "README-macOS.txt")
        try report.write(to: reportURL)
        print(report.renderPlainText())
    }

    private static func destinationURL(from arguments: [String]) throws -> URL {
        guard let index = arguments.firstIndex(of: "--destination"), arguments.indices.contains(index + 1) else {
            return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appending(path: "FantaTennis-macOS-install", directoryHint: .isDirectory)
        }
        return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
    }

    private static func printHelp() {
        print("""
        fantatennis-mac inspect
        fantatennis-mac doctor
        fantatennis-mac install [--destination PATH]
        """)
    }
}

enum CLIError: Error, CustomStringConvertible {
    case unknownCommand(String)

    var description: String {
        switch self {
        case let .unknownCommand(command):
            "Unknown command: \(command)"
        }
    }
}
