import AppKit
import FantaTennisCore
import Foundation

@main
@MainActor
final class FantaTennisLauncherApp: NSObject, NSApplicationDelegate {
    private let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 720, height: 460),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    private let logView = NSTextView()
    private let installButton = NSButton(title: "Install / Update", target: nil, action: nil)
    private let launchButton = NSButton(title: "Launch", target: nil, action: nil)
    private let doctorButton = NSButton(title: "Doctor", target: nil, action: nil)
    private let destination = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Applications/FantaTennis", directoryHint: .isDirectory)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        configureWindow()
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        append("FantaTennis macOS launcher")
        append("Install: \(destination.path)")
        append("Native updater manifest: \(LauncherConfig.official.updaterManifestURL.absoluteString)")
        append("Runtime: \(LauncherInstaller.resolveWindowsRuntime() ?? "missing; install CrossOver or Wine to launch")")
    }

    private func configureWindow() {
        window.title = "FantaTennis"
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

        let buttons = NSStackView(views: [installButton, launchButton, doctorButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        for button in [installButton, launchButton, doctorButton] {
            button.bezelStyle = .rounded
            button.target = self
        }
        installButton.action = #selector(installOrUpdate)
        launchButton.action = #selector(launchGame)
        doctorButton.action = #selector(runDoctor)

        let scroll = NSScrollView()
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        scroll.documentView = logView
        logView.isEditable = false
        logView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)

        root.addArrangedSubview(title)
        root.addArrangedSubview(subtitle)
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
                    winePath: LauncherInstaller.resolveWindowsRuntime()
                )
                append("Install/update complete.")
            } catch {
                append("ERROR: \(error)")
            }
            setButtons(enabled: true)
        }
    }

    @objc private func launchGame() {
        let wrapper = destination.appending(path: "run-windows-client.command")
        guard FileManager.default.isExecutableFile(atPath: wrapper.path) else {
            append("No installed wrapper found. Run Install / Update first.")
            return
        }
        do {
            let process = Process()
            process.executableURL = wrapper
            try process.run()
            append("Launch requested.")
        } catch {
            append("ERROR: \(error)")
        }
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
                append("runtime\t\(LauncherInstaller.resolveWindowsRuntime() ?? "missing")")
            } catch {
                append("ERROR: \(error)")
            }
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
