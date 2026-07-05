import Foundation

public extension LauncherInstaller {
    static func resolveWindowsRuntime(pathEnvironment: String? = ProcessInfo.processInfo.environment["PATH"]) -> String? {
        resolveWindowsRuntimeDetails(pathEnvironment: pathEnvironment)?.executablePath
    }

    static func runtimeStatus(
        pathEnvironment: String? = ProcessInfo.processInfo.environment["PATH"],
        configuredWinePath: String? = ProcessInfo.processInfo.environment["FANTATENNIS_WINE"],
        sikarugirPath: String = ProcessInfo.processInfo.environment["FANTATENNIS_SIKARUGIR_PATH"]
            ?? "/Applications/Sikarugir Creator.app",
        crossoverWinePath: String? = ProcessInfo.processInfo.environment["FANTATENNIS_DISABLE_CROSSOVER"] == "1"
            ? nil
            : "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"
    ) -> RuntimeStatus {
        if let runtime = resolveWindowsRuntimeDetails(
            pathEnvironment: pathEnvironment,
            configuredWinePath: configuredWinePath,
            crossoverWinePath: crossoverWinePath
        ) {
            return .ready(runtime)
        }
        if isSikarugirCreatorInstalled(at: sikarugirPath) {
            return .sikarugirNeedsEngine
        }
        return .missing
    }

    static func isSikarugirCreatorInstalled(
        at path: String = "/Applications/Sikarugir Creator.app"
    ) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    static func resolveWindowsRuntimeDetails(
        pathEnvironment: String? = ProcessInfo.processInfo.environment["PATH"],
        configuredWinePath: String? = ProcessInfo.processInfo.environment["FANTATENNIS_WINE"],
        crossoverWinePath: String? = ProcessInfo.processInfo.environment["FANTATENNIS_DISABLE_CROSSOVER"] == "1"
            ? nil
            : "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"
    ) -> WindowsRuntime? {
        if let configuredWinePath,
           FileManager.default.isExecutableFile(atPath: configuredWinePath)
        {
            return WindowsRuntime(kind: .wine, executablePath: configuredWinePath, bottleName: nil)
        }

        let bundledWineCandidates = [
            "/Applications/Wine Stable.app/Contents/Resources/wine/bin/wine",
            "/Applications/Wine Staging.app/Contents/Resources/wine/bin/wine",
            "/Applications/Wine Devel.app/Contents/Resources/wine/bin/wine",
        ]
        if let found = bundledWineCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return WindowsRuntime(kind: .wine, executablePath: found, bottleName: nil)
        }
        if let wine = findExecutable("wine", pathEnvironment: pathEnvironment) {
            return WindowsRuntime(kind: .wine, executablePath: wine, bottleName: nil)
        }

        if let crossoverWinePath,
           FileManager.default.isExecutableFile(atPath: crossoverWinePath)
        {
            return WindowsRuntime(kind: .crossover, executablePath: crossoverWinePath, bottleName: "FantaTennis")
        }
        return nil
    }

    static func runtimeWrapperScript(launcherPath: String, runtime: WindowsRuntime?) -> String {
        guard let runtime else {
            return """
            #!/bin/sh
            cd "$(dirname "$0")"
            echo "A free Wine-compatible runtime is required to run \(launcherPath) on macOS."
            echo "Install Sikarugir or Wine, then open FantaTennis.app again and press Launch."
            exit 69
            """
        }

        switch runtime.kind {
        case .crossover:
            return crossoverWrapperScript(launcherPath: launcherPath, runtime: runtime)
        case .wine:
            return wineWrapperScript(launcherPath: launcherPath, runtime: runtime)
        }
    }

    private static func crossoverWrapperScript(launcherPath: String, runtime: WindowsRuntime) -> String {
        let bottleName = runtime.bottleName ?? "FantaTennis"
        let bottleTool = "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/cxbottle"
        return """
        #!/bin/sh
        cd "$(dirname "$0")"
        export CX_BOTTLE="\(bottleName)"
        export WINEPREFIX="$HOME/Library/Application Support/CrossOver/Bottles/$CX_BOTTLE"
        export CX_GRAPHICS_BACKEND="${CX_GRAPHICS_BACKEND:-d3dmetal}"
        export WINED3DMETAL="${WINED3DMETAL:-1}"
        if [ ! -f "$WINEPREFIX/cxbottle.conf" ]; then
          if [ ! -x "\(bottleTool)" ]; then
            echo "CrossOver bottle tool is missing: \(bottleTool)"
            exit 69
          fi
          rm -rf "$WINEPREFIX"
          "\(bottleTool)" --bottle "$CX_BOTTLE" --create --template win10 --description "FantaTennis JFTSE"
        fi
        exec "\(runtime.executablePath)" "\(launcherPath)"
        """
    }

    private static func wineWrapperScript(launcherPath: String, runtime: WindowsRuntime) -> String {
        """
        #!/bin/sh
        cd "$(dirname "$0")"
        if [ ! -x "\(runtime.executablePath)" ]; then
          echo "Configured Wine runtime is missing: \(runtime.executablePath)"
          exit 69
        fi
        exec "\(runtime.executablePath)" "\(launcherPath)"
        """
    }
}
