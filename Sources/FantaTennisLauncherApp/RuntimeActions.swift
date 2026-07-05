import AppKit
import FantaTennisCore
import Foundation

@MainActor
extension FantaTennisLauncherAppDelegate {
    @objc func openRuntimeDownload() {
        if shouldOpenSikarugirCreator() {
            openSikarugirCreator()
        } else {
            NSWorkspace.shared.open(URL(string: "https://github.com/Sikarugir-App/Sikarugir")!)
        }
    }

    func refreshRuntimeStatus() {
        switch LauncherInstaller.runtimeStatus() {
        case let .ready(runtime):
            switch runtime.kind {
            case .wine:
                statusLabel.stringValue = "Runtime: free Wine-compatible engine ready"
            case .crossover:
                statusLabel.stringValue = "Runtime: CrossOver fallback ready. Free runtime not configured."
            }
            append("Runtime: \(runtime.displayName) at \(runtime.executablePath)")
        case .sikarugirNeedsEngine:
            statusLabel.stringValue = "Runtime setup: Sikarugir Creator installed. Create or select a Wine engine."
            append("Runtime setup: Sikarugir Creator installed, but no runnable Wine engine was found.")
        case .missing:
            statusLabel.stringValue = "Runtime: missing. Install Sikarugir or Wine to launch the Windows game client."
            append("Runtime: missing; install Sikarugir or Wine to launch.")
        }
    }

    private func shouldOpenSikarugirCreator() -> Bool {
        switch LauncherInstaller.runtimeStatus() {
        case .sikarugirNeedsEngine:
            true
        case let .ready(runtime):
            runtime.kind == .crossover && LauncherInstaller.isSikarugirCreatorInstalled()
        case .missing:
            false
        }
    }

    func openSikarugirCreator() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Sikarugir Creator.app"))
    }
}
