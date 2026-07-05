import Foundation

public struct InstallReport: Sendable {
    public let installDirectory: URL
    public let seedArchiveSHA256: String
    public let extractedFiles: [String]
    public let winePath: String?
    public let config: LauncherConfig

    public init(
        installDirectory: URL,
        seedArchiveSHA256: String,
        extractedFiles: [String],
        winePath: String?,
        config: LauncherConfig
    ) {
        self.installDirectory = installDirectory
        self.seedArchiveSHA256 = seedArchiveSHA256
        self.extractedFiles = extractedFiles.sorted()
        self.winePath = winePath
        self.config = config
    }

    public func renderPlainText() -> String {
        let runtimeLine = winePath.map { "Wine runtime: \($0)" }
            ?? "Wine runtime: Wine or CrossOver is required to run the Windows game binary on macOS."
        let files = extractedFiles.isEmpty ? "none" : extractedFiles.joined(separator: ", ")

        return """
        FantaTennis macOS launcher port

        Install directory: \(installDirectory.path)
        Seed archive SHA-256: \(seedArchiveSHA256)
        Extracted seed files: \(files)

        Reverse-engineered Windows launcher contract:
        - Title: \(config.title)
        - News: \(config.newsURL.absoluteString)
        - Ranking: \(config.rankingURL.absoluteString)
        - Register: \(config.registerURL.absoluteString)
        - Discord: \(config.discordURL.absoluteString)
        - Updater base: \(config.updaterBaseURL.absoluteString)
        - Installed launcher seed: \(config.seedLauncherPath)
        - Launch file after update: \(config.launchFile)

        \(runtimeLine)

        This port installs and inspects the official JFTSE launcher seed. The game executable is still a Windows binary; use Wine or CrossOver to run \(config.seedLauncherPath), then let that official launcher update and start \(config.launchFile).
        """
    }

    public func write(to url: URL) throws {
        try renderPlainText().write(to: url, atomically: true, encoding: .utf8)
    }
}
