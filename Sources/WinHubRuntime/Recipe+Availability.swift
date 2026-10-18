import Foundation
import WinHubCore

extension Recipe {
    /// Older apps hide the Install button when this is false. A missing or unreadable `minAppVersion` is allowed.
    public func isSupported(by version: AppVersion) -> Bool {
        guard let minAppVersion, let needed = AppVersion(minAppVersion) else { return true }
        return version >= needed
    }

    /// Direct3D, msync, environment and DLL overrides from the recipe. Call only when the bottle was just created.
    public func applySettingsIfCreating(_ bottle: inout Bottle) {
        guard let settings else { return }
        if let raw = settings.graphics, let backend = GraphicsBackend(rawValue: raw) {
            bottle.graphics = backend
        }
        if let msync = settings.msync { bottle.msync = msync }
        if let environment = settings.environment { bottle.environment = environment }
        if let dllOverrides = settings.dllOverrides { bottle.dllOverrides = dllOverrides }
    }
}
