import Foundation

/// Builds the environment for Wine processes of a bottle.
public enum WineEnvironment {
    public enum DebugLevel: Sendable {
        /// Errors only; Wine's many "fixme" notes are hidden (the default).
        case errors
        /// No Wine output at all.
        case silent
        /// A raw `WINEDEBUG` value, e.g. `"+relay"`.
        case custom(String)

        var value: String {
            switch self {
            case .errors: "fixme-all"
            case .silent: "-all"
            case .custom(let value): value
            }
        }
    }

    /// Variables kept from the parent environment; everything else is dropped so the
    /// user's shell configuration cannot leak into Windows programs.
    static let inherited = ["HOME", "USER", "LOGNAME", "LANG", "LC_ALL", "TMPDIR", "SHELL"]

    /// WinHub's data folder, passed to engines that read the downloaded compatibility database.
    public static var winhubHome: URL {
        URL.applicationSupportDirectory.appending(path: "WinHub", directoryHint: .isDirectory)
    }

    /// `d3dmetal`: the user's D3DMetal folder (see `D3DMetal`), if any.
    public static func make(for bottle: Bottle, runtime: InstalledRuntime, debug: DebugLevel = .errors,
                            extraOverrides: [String: String] = [:], d3dmetal: URL? = nil,
                            winhubHome: URL = winhubHome,
                            base: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        var env = base.filter { inherited.contains($0.key) }
        env["PATH"] = "\(runtime.binDirectory.path):/usr/bin:/bin:/usr/sbin:/sbin"
        env["WINEPREFIX"] = bottle.prefix.path
        env["WINEDEBUG"] = debug.value
        // Rosetta hides AVX from x86_64 code unless asked; many games need it.
        env["ROSETTA_ADVERTISE_AVX"] = "1"
        // .NET 7+ JIT under Rosetta needs W^X disabled.
        env["DOTNET_EnableWriteXorExecute"] = "0"

        if bottle.msync && runtime.manifest.supports(.msync) {
            env["WINEMSYNC"] = "1"
        }
        if runtime.dispatchesGraphics {
            // The engine's winhubcompat picks the Direct3D and reads the compatibility rules.
            env["WINHUB_GRAPHICS_BACKEND"] = bottle.graphics.rawValue
            env["WINHUB_COMPAT_RULES"] = CompatRules.url(for: bottle).path
            env["WINHUB_HOME"] = winhubHome.path
            if let d3dmetal {
                env["WINHUB_D3DMETAL_DIR"] = d3dmetal.path
                env["CX_APPLEGPTK_LIBD3DSHARED_PATH"] = D3DMetal.sharedLibrary(in: d3dmetal).path
            }
        }
        if bottle.performanceHUD {
            env["MTL_HUD_ENABLED"] = "1"
            if bottle.graphics == .dxvk { env["DXVK_HUD"] = "fps,devinfo" }
        }

        let overrides = bottle.dllOverrides.merging(extraOverrides) { _, new in new }
        if !overrides.isEmpty {
            env["WINEDLLOVERRIDES"] = overrides.sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ";")
        }
        // Bottle settings win over everything above.
        env.merge(bottle.environment) { _, bottleValue in bottleValue }
        return env
    }
}
