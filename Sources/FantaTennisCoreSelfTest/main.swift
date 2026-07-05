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
require(config.updaterManifestURL.absoluteString == "https://jftse.com/updater/files.md5", "updater manifest URL")
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
require(text.contains("CrossOver or a compatible Wine runtime is required"), "report names runtime boundary")
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
require(wrapper.contains("CrossOver or a compatible Wine runtime is required"), "wrapper names preferred runtime")
require(!wrapper.contains("exec \"wine\" \"FantaTennis.exe\""), "wrapper does not bypass launcher seed")

let crossoverWrapperURL = try installer.writeRuntimeWrapper(
    in: wrapperRoot,
    launcherPath: config.seedLauncherPath,
    runtime: WindowsRuntime(
        kind: .crossover,
        executablePath: "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine",
        bottleName: "FantaTennis"
    )
)
let crossoverWrapper = try String(contentsOf: crossoverWrapperURL, encoding: .utf8)
require(crossoverWrapper.contains("CX_BOTTLE=\"FantaTennis\""), "CrossOver wrapper uses dedicated bottle")
require(crossoverWrapper.contains("cxbottle\" --bottle \"$CX_BOTTLE\" --create --template win10"), "CrossOver wrapper creates missing bottle")
require(crossoverWrapper.contains("cxbottle.conf"), "CrossOver wrapper checks for a real bottle")
require(crossoverWrapper.contains("ClientSeed/FT_Launcher.exe"), "CrossOver wrapper launches installed seed launcher")

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

let manifest = try UpdateManifest(text: """
\\FantaTennis.exe;3801088;61d478b0888ed0ec39a57aefa6595792
\\Res\\Ad.res;736071;8f43af68955e3bdb9f5d1605a0f571fb
""")
require(manifest.entries.count == 2, "manifest entry count")
require(manifest.totalByteCount == 4_537_159, "manifest total bytes")
require(manifest.entries[0].relativePath == "FantaTennis.exe", "manifest root path normalization")
require(manifest.entries[1].relativePath == "Res/Ad.res", "manifest nested path normalization")
require(manifest.entries[0].md5 == "61d478b0888ed0ec39a57aefa6595792", "manifest md5")

print("FantaTennisCoreSelfTest passed")
