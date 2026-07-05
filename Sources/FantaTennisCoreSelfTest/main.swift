import FantaTennisCore
import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        Foundation.exit(1)
    }
}

let config = LauncherConfig.official
require(config.title == "FT Launcher", "launcher title")
require(config.newsURL.absoluteString == "https://jftse.com/launcher_news", "news URL")
require(config.rankingURL.absoluteString == "https://jftse.com/launcher_ranking", "ranking URL")
require(config.registerURL.absoluteString == "https://jftse.com", "register URL")
require(config.discordURL.absoluteString == "https://discord.gg/Cw2xZ6n6Wu", "Discord URL")
require(config.seedArchiveURL.absoluteString == "https://jftse.com/client/FantaTennis.7z", "seed archive URL")
require(config.seedArchiveSHA256 == "c19ca21b8e2ab091953b2f631e48853b6477400f4d7000682ac7440f9994f12e", "seed archive hash")
require(config.updaterBaseURL.absoluteString == "https://jftse.com/updater/", "updater base URL")
require(config.seedLauncherPath == "ClientSeed/FT_Launcher.exe", "installed seed launcher path")
require(config.launchFile == "FantaTennis.exe", "launch file")

require(EndpointProbe.classify(statusCode: 200) == .available, "200 classification")
require(EndpointProbe.classify(statusCode: 403) == .privateListing, "403 classification")
require(EndpointProbe.classify(statusCode: 404) == .missing, "404 classification")

let directory = FileManager.default.temporaryDirectory
    .appending(path: "fantatennis-report-\(UUID().uuidString)", directoryHint: .isDirectory)
let report = InstallReport(
    installDirectory: directory,
    seedArchiveSHA256: "abc123",
    extractedFiles: ["FT_Launcher.exe", "FT_Launcher.exe.config"],
    winePath: nil,
    config: .official
)
let text = report.renderPlainText()
require(text.contains("FT_Launcher.exe"), "report names launcher")
require(text.contains("FantaTennis.exe"), "report names game binary")
require(text.contains("Wine or CrossOver is required"), "report names runtime boundary")
require(text.contains("https://jftse.com/updater/"), "report names updater")

let installer = LauncherInstaller()
let wrapperRoot = FileManager.default.temporaryDirectory
    .appending(path: "fantatennis-wrapper-\(UUID().uuidString)", directoryHint: .isDirectory)
try FileManager.default.createDirectory(
    at: wrapperRoot.appending(path: "ClientSeed", directoryHint: .isDirectory),
    withIntermediateDirectories: true
)
let launcherURL = wrapperRoot.appending(path: config.seedLauncherPath)
try Data().write(to: launcherURL)
let wrapperURL = try installer.writeRuntimeWrapper(in: wrapperRoot, winePath: nil)
let wrapper = try String(contentsOf: wrapperURL, encoding: .utf8)
require(wrapper.contains("ClientSeed/FT_Launcher.exe"), "wrapper launches installed seed launcher")
require(!wrapper.contains("exec \"wine\" \"FantaTennis.exe\""), "wrapper does not bypass launcher seed")

let symlinkedBase = URL(fileURLWithPath: "/tmp")
    .appending(path: "fantatennis-relative-\(UUID().uuidString)", directoryHint: .isDirectory)
let nestedFile = symlinkedBase
    .appending(path: "ClientSeed", directoryHint: .isDirectory)
    .appending(path: "FT_Launcher.exe")
try FileManager.default.createDirectory(
    at: nestedFile.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try Data().write(to: nestedFile)
let relativePath = LauncherInstaller.relativePath(of: nestedFile.resolvingSymlinksInPath(), under: symlinkedBase)
require(relativePath == "ClientSeed/FT_Launcher.exe", "relative path survives symlinked destination")

print("FantaTennisCoreSelfTest passed")
