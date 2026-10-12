**English** · [Português (Brasil)](pt-BR/architecture.md)

# Architecture

WinHub is a Swift package with three modules. The app only orchestrates; everything that can be tested without a
screen lives in the two libraries.

```
Sources/WinHubCore/      pure data, no UI and no processes
Sources/WinHubRuntime/   everything that touches disk, network and Wine processes
Sources/WinHub/          the SwiftUI app
Support/                 steamwebhelper wrapper (a Windows program, built at packaging time)
Tests/                   unit and integration tests (Swift Testing)
```

`WinHub` depends on `WinHubCore` and `WinHubRuntime`; the two libraries depend on neither each other nor the UI.

## Modules

| Module | Main types | Role |
|---|---|---|
| **WinHubCore** | `CatalogEntry`, `Rating`, `Recipe`, `CatalogLoader`, `CatalogSearchEngine`, `WildcardPattern` | The catalog and its search ([Catalog search](catalog-search.md)), install recipes |
| **WinHubRuntime** | `RuntimeManifest`, `RuntimeManager` | Downloads, checks (SHA-256) and installs the Wine engine, including engine overlays |
| | `Bottle`, `BottleStore` | A bottle is a folder with `bottle.json` and `prefix/` (the `WINEPREFIX`) |
| | `WineEnvironment` | Builds the environment of Wine processes (a pure function) |
| | `WineLauncher`, `ProgramScanner`, `WineServerStatus`, `WineOrphanReaper` | Runs Wine, finds installed programs, knows whether a bottle is running, cleans up orphaned processes |
| | `BottleArchive` | Exports a bottle to a `.winhubbottle` file and imports one as a new bottle |
| | `ShellLink`, `ProgramIcon` | Reads a shortcut's target and the program's icon from its `.exe` (rebuilt as an `.ico`) |
| | `ComponentManager`, `GraphicsBackend` | DXVK and winetricks; the bottle's and each program's Direct3D ([Graphics](graphics.md)) |
| | `CompatRules`, `D3DMetal`, `CompatDatabaseSync` | Per-bottle rules for the engine, the user's D3DMetal, the signed rule database |
| | `AppLauncherBuilder`, `SteamWebHelperWrapper` | `.app` shortcuts; the fix for Steam's black window |
| | `AppUpdater`, `RemoteDataSync` | App updates; catalog and manifests from `main` |
| **WinHub** | `WinHubApp`, `RootView`, `CatalogStore`, `WineStore`, `UpdateStore`, views | Scenes, menus, settings, `winhub://` links; observable stores the views read |

User data: `~/Library/Application Support/WinHub/{Runtimes,Components,Bottles,Remote,compat}`,
`~/Library/Caches/WinHub/{Downloads,Updates}`, shortcuts in `~/Applications/WinHub/`.

## Main flows

**Engine.** `runtimes.json` lists the engines; the first one is installed. `RuntimeManager.install` downloads the
official Wine build, checks its SHA-256 and unpacks it; when the entry has an `overlay` (a winhub-engine
release), it checks that too, removes the folders listed in `overlay.replace` (which must stay inside the Wine
folder) and unpacks the overlay over the base. The marker `.winhub-runtime.json` is written last, so a half
installed engine is never used. A newer engine in `runtimes.json` does not invalidate the installed one; the
sidebar offers "Atualizar o Wine".

**New bottle.** `BottleStore.create` → `WineLauncher.initialize`: `wineboot --init` with Mono and Gecko off,
`winecfg /v <version>`, then `wineserver -k` and `-w`.

**Recipe.** A catalog title with a `recipe` installs with one click: a bottle by name (reused if it exists) →
winetricks dependencies → download the installer → run it → check that `launch.windowsPath` exists → open.

**Opening a program.** `WineStore.launch` starts the program and does not wait for it; "running" comes from
`WineServerStatus` (someone holds the `wineserver` lock), because programs like Steam restart themselves.

**Shortcuts.** A shortcut `.app` only runs `open "winhub://open?bottle=<uuid>&shortcut=<path>"`; WinHub checks
that the `.lnk` is inside the bottle's `drive_c` before opening it. Wine never runs inside the shortcut's own
process (programs started that way hang).

**Updates.** `UpdateStore` checks 10 s after launch and then every hour:

1. `RemoteDataSync` downloads `catalog.json`, `runtimes.json` and `components.json` from `main` and keeps them
   only if this app version can decode them;
2. `CompatDatabaseSync` downloads the engine's rule database and its Ed25519 signature, and installs it only
   when the signature is valid and the database is newer;
3. `AppUpdater` reads the latest GitHub release, downloads `WinHub.zip`, checks the SHA-256 GitHub computed,
   the bundle identifier, the version and `codesign --verify`, and swaps the app on "Reiniciar para atualizar".

## The catalog and recipes

The catalog is `Sources/WinHub/Resources/catalog.json`: a list of `CatalogEntry` (`id`, `name`, `localizedNames`,
`category`, `summary`, `rating`, `isFeatured`, `steamID`, `steamGame`, `recipe`). A recipe says how to install and
open a title:

```json
"recipe": {
  "bottleName": "Steam",
  "windowsVersion": "win10",
  "dependencies": [],
  "installer": { "url": "https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe", "arguments": ["/S"] },
  "launch": { "windowsPath": "C:\\Program Files (x86)\\Steam\\steam.exe" }
}
```

`steamGame` (`installDir`, `executable`, `graphics`) says where a Steam game lives in the Steam bottle and which
Direct3D worked best in our tests. Use only official download URLs and describe only steps you tested.

## Working with the engine

Engines declare what they can do in `features` in `runtimes.json`:

| Feature | What WinHub does with it |
|---|---|
| `dxmt` | Offers DXMT. On engines without `backend-dispatch`, copies the DXMT DLLs into the bottle or next to the program |
| `dxvk` | DXVK comes with the engine instead of the DXVK-macOS component |
| `msync` | Offers the per-bottle msync switch (`WINEMSYNC=1`) |
| `backend-dispatch` | The engine picks the Direct3D itself: WinHub only sets `WINHUB_GRAPHICS_BACKEND` and writes per-program rules; offers Automático and D3DMetal |
| `compatdb` | The engine reads rule files: the bottle's (`WINHUB_COMPAT_RULES`) and the signed database (`WINHUB_HOME/compat/compatdb.json`) |
| `nvext` | Offers the per-bottle switch for DXMT's NVIDIA extensions (`DXMT_ENABLE_NVEXT=1`: NVAPI and DLSS over MetalFX) |

With `backend-dispatch`, `WineEnvironment` sets `WINHUB_GRAPHICS_BACKEND`, `WINHUB_COMPAT_RULES`, `WINHUB_HOME`
and, when the user has D3DMetal, `WINHUB_D3DMETAL_DIR` and `CX_APPLEGPTK_LIBD3DSHARED_PATH`. How the engine uses
them: [winhubcompat](https://angeloresplandes.github.io/winhub-engine/compatdb.html).

Bottles set up when WinHub copied DLLs are migrated before a program opens (`migrateToDispatchedGraphics`): Wine's
own DLLs go back, the copies and their `n,b` overrides go away, and programs with their own Direct3D become rules
in `<bottle>/compat-rules.json`.

## The process environment

`WineEnvironment` only inherits `HOME`, `USER`, `LOGNAME`, `LANG`, `LC_ALL`, `TMPDIR` and `SHELL`, always sets
`ROSETTA_ADVERTISE_AVX=1` and `DOTNET_EnableWriteXorExecute=0` (the same two variables CrossOver's launcher
sets), uses `WINEDEBUG=fixme-all` by default, and lets the bottle's own settings win.
