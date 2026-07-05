import AppKit
import FantaTennisCore
import Foundation

@main
@MainActor
enum FantaTennisLauncherMain {
    private static let delegate = FantaTennisLauncherAppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class FantaTennisLauncherAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private let logView = NSTextView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let installButton = NSButton(title: "Install / Update", target: nil, action: nil)
    private let launchButton = NSButton(title: "Launch", target: nil, action: nil)
    private let doctorButton = NSButton(title: "Doctor", target: nil, action: nil)
    private let runtimeButton = NSButton(title: "Get CrossOver", target: nil, action: nil)
    private let destination = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Applications/FantaTennis", directoryHint: .isDirectory)

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenu()
        showMainWindow()
        append("FantaTennis macOS launcher")
        append("Install: \(destination.path)")
        append("Native updater manifest: \(LauncherConfig.official.updaterManifestURL.absoluteString)")
        refreshRuntimeStatus()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshRuntimeStatus()
    }

    private func configureMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Quit FantaTennis",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }

    private func showMainWindow() {
        let launcherWindow = window ?? makeWindow()
        window = launcherWindow
        launcherWindow.center()
        launcherWindow.makeKeyAndOrderFront(nil)
        launcherWindow.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "FantaTennis"
        window.isReleasedWhenClosed = false
        window.delegate = self

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        root.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "FantaTennis")
        title.font = .systemFont(ofSize: 24, weight: .semibold)

        let subtitle = NSTextField(labelWithString: "Native macOS installer and launcher for the official JFTSE Windows client payload.")
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byWordWrapping
        statusLabel.textColor = .secondaryLabelColor

        let buttons = NSStackView(views: [installButton, launchButton, doctorButton, runtimeButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        for button in [installButton, launchButton, doctorButton, runtimeButton] {
            button.bezelStyle = .rounded
            button.target = self
        }
        installButton.action = #selector(installOrUpdate)
        launchButton.action = #selector(launchGame)
        doctorButton.action = #selector(runDoctor)
        runtimeButton.action = #selector(openRuntimeDownload)

        let scroll = NSScrollView()
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        scroll.documentView = logView
        logView.isEditable = false
        logView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)

        root.addArrangedSubview(title)
        root.addArrangedSubview(subtitle)
        root.addArrangedSubview(statusLabel)
        root.addArrangedSubview(buttons)
        root.addArrangedSubview(scroll)
        window.contentView = root
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            root.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            root.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 260),
        ])

        return window
    }

    @objc private func installOrUpdate() {
        setButtons(enabled: false)
        Task {
            do {
                let installer = LauncherInstaller()
                let manifest = try await installer.fetchUpdateManifest()
                append("Manifest: \(manifest.entries.count) files, \(manifest.totalByteCount) bytes")
                append("Downloading and verifying official payload. This is about \(manifest.totalByteCount / 1_048_576) MiB.")
                _ = try await installer.downloadPayload(manifest: manifest, destination: destination)
                _ = try installer.writeRuntimeWrapper(
                    in: destination,
                    launcherPath: "FT_Launcher.exe",
                    runtime: LauncherInstaller.resolveWindowsRuntimeDetails()
                )
                append("Install/update complete.")
                refreshRuntimeStatus()
            } catch {
                append("ERROR: \(error)")
            }
            setButtons(enabled: true)
        }
    }

    @objc private func launchGame() {
        let launcherPath = installedLauncherPath()
        guard let launcherPath else {
            append("No installed launcher found. Run Install / Update first.")
            return
        }
        guard let runtime = LauncherInstaller.resolveWindowsRuntimeDetails() else {
            refreshRuntimeStatus()
            append("Install CrossOver, then press Launch again.")
            return
        }
        do {
            let installer = LauncherInstaller()
            let wrapper = try installer.writeRuntimeWrapper(
                in: destination,
                launcherPath: launcherPath,
                runtime: runtime
            )
            guard FileManager.default.isExecutableFile(atPath: wrapper.path) else {
                append("No executable wrapper found. Run Install / Update first.")
                return
            }
            let process = Process()
            process.executableURL = wrapper
            try process.run()
            append("Launch requested with \(runtime.displayName).")
        } catch {
            append("ERROR: \(error)")
        }
    }

    private func installedLauncherPath() -> String? {
        let candidates = ["FT_Launcher.exe", LauncherConfig.official.seedLauncherPath]
        for candidate in candidates {
            if FileManager.default.fileExists(atPath: destination.appending(path: candidate).path) {
                return candidate
            }
        }
        return nil
    }

    @objc private func openRuntimeDownload() {
        NSWorkspace.shared.open(URL(string: "https://www.codeweavers.com/crossover/download")!)
    }

    @objc private func runDoctor() {
        Task {
            do {
                let installer = LauncherInstaller()
                for url in [
                    LauncherConfig.official.seedArchiveURL,
                    LauncherConfig.official.updaterManifestURL,
                    LauncherConfig.official.newsURL,
                    LauncherConfig.official.rankingURL,
                ] {
                    let probe = try await installer.probe(url)
                    append("\(probe.state.rawValue)\t\(probe.statusCode)\t\(url.absoluteString)")
                }
                append("extractor\t\(try LauncherInstaller.locateExtractor())")
                let runtime = LauncherInstaller.resolveWindowsRuntimeDetails()
                append("runtime\t\(runtime.map { "\($0.displayName)\t\($0.executablePath)" } ?? "missing")")
                refreshRuntimeStatus()
            } catch {
                append("ERROR: \(error)")
            }
        }
    }

    private func refreshRuntimeStatus() {
        if let runtime = LauncherInstaller.resolveWindowsRuntimeDetails() {
            statusLabel.stringValue = "Runtime: \(runtime.displayName)"
            append("Runtime: \(runtime.displayName) at \(runtime.executablePath)")
        } else {
            statusLabel.stringValue = "Runtime: missing. Install CrossOver to launch the Windows game client."
            append("Runtime: missing; install CrossOver to launch.")
        }
    }

    private func setButtons(enabled: Bool) {
        DispatchQueue.main.async {
            self.installButton.isEnabled = enabled
            self.launchButton.isEnabled = enabled
            self.doctorButton.isEnabled = enabled
        }
    }

    private func append(_ line: String) {
        DispatchQueue.main.async {
            self.logView.string += line + "\n"
            self.logView.scrollToEndOfDocument(nil)
        }
    }
}
