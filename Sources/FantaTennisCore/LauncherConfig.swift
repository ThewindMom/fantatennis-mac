import Foundation

public struct LauncherConfig: Equatable, Sendable {
    public let title: String
    public let newsURL: URL
    public let rankingURL: URL
    public let registerURL: URL
    public let discordURL: URL
    public let seedArchiveURL: URL
    public let seedArchiveSHA256: String
    public let updaterBaseURL: URL
    public let updaterManifestURL: URL
    public let seedLauncherPath: String
    public let launchFile: String

    public static let official = LauncherConfig(
        title: "FT Launcher",
        newsURL: URL(string: "https://jftse.com/launcher_news")!,
        rankingURL: URL(string: "https://jftse.com/launcher_ranking")!,
        registerURL: URL(string: "https://jftse.com")!,
        discordURL: URL(string: "https://discord.gg/Cw2xZ6n6Wu")!,
        seedArchiveURL: URL(string: "https://jftse.com/client/FantaTennis.7z")!,
        seedArchiveSHA256: "c19ca21b8e2ab091953b2f631e48853b6477400f4d7000682ac7440f9994f12e",
        updaterBaseURL: URL(string: "https://jftse.com/updater/")!,
        updaterManifestURL: URL(string: "https://jftse.com/updater/files.md5")!,
        seedLauncherPath: "ClientSeed/FT_Launcher.exe",
        launchFile: "FantaTennis.exe"
    )
}
