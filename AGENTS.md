# AGENTS.md: guide for coding agents

WinHub is a native macOS app (SwiftUI) that finds, installs and runs Windows programs with Wine. It is a
**public, independent** project (MIT). Read this whole file before changing anything. The full documentation is
in [`docs/`](docs/) (English) and [`docs/pt-BR/`](docs/pt-BR/) (Brazilian Portuguese).

## Rules that cannot be broken

1. **Clean room.** CrossOver (CodeWeavers) is studied for **behaviour only**, and findings are documented as
   behaviour in `docs/reverse-engineering.md`. Never copy code, scripts, texts, translations, icons, data,
   catalogs or compatibility databases from CrossOver or any commercial product. Never commit decompiled code,
   addresses, internal symbol names or analysis logs. Code CodeWeavers publishes under the LGPL is used by
   winhub-engine with attribution. Details in `CONTRIBUTING.md`.
2. **No third-party binaries in the repository.** Wine, DXVK, winetricks and installers are downloaded at run
   time from the official source and checked by SHA-256 (manifests in `Sources/WinHub/Resources/`). `dist/` and
   `.build/` stay out of Git.
3. **Apple's D3DMetal / Game Porting Toolkit: never redistribute** (Apple's license). It is used only from the
   folder the user picks in the settings (`D3DMetal.location`, default
   `~/Library/Application Support/WinHub/D3DMetal`), and only with an engine that picks the Direct3D
   (`backend-dispatch` feature).
4. **Trademarks** (Windows, Mac, Steam, CrossOver) only nominatively, never logos.
5. When adding a downloadable component, update `THIRD_PARTY_NOTICES.md` and `THIRD_PARTY_NOTICES.pt-BR.md`.
6. **Documentation in both languages.** Every page in `docs/` has its mirror in `docs/pt-BR/`, and every root page
   its `.pt-BR.md` (except this file and `CLAUDE.md`). Change both together.

## Commands

```bash
swift build                 # build
swift test                  # 138 tests (unit; the ones with a real Wine stay off)
swift run WinHub            # run without packaging (.app shortcuts and winhub:// links do not work this way)
./scripts/package-app.sh    # builds dist/WinHub.app (universal) and dist/WinHub.zip, ad-hoc signature;
                            # builds the Steam wrapper (needs: brew install mingw-w64)
swift scripts/make-icon.swift out.icns        # draws the icon (package-app.sh already calls it)
swift scripts/make-icon.swift docs/icon.svg   # the same drawing as SVG, for the README (run when the icon changes)
./scripts/build-steam-wrapper.sh   # only the wrapper, in .build/; to use Steam with swift run:
WINHUB_STEAMWEBHELPER_WRAPPER=.build/steamwebhelper-wrapper.exe swift run WinHub
open Package.swift          # open in Xcode
```

Tests with a real Wine (they need the engine already downloaded by the app in `~/Library/Application Support/WinHub/Runtimes`):

```bash
RUN_WINE_TESTS=1 swift test --filter ComponentIntegrationTests   # downloads DXVK and winetricks if missing
# WINHUB_DXVK_ARCHIVE/WINHUB_WINETRICKS use local files; WINHUB_CABEXTRACT_VERB=corefonts tests cabextract
# really downloads and installs the first engine in runtimes.json (official Wine + winhub-engine overlay) and cabextract
RUN_WINE_TESTS=1 WINHUB_INSTALL_ENGINE=1 swift test --filter EngineInstallTests
```

Testing a local engine build before it is released: `docs/development.md`, "Testing a local engine".

## Architecture

```
Sources/WinHubCore/      pure data, no UI and no processes (testable)
  CatalogEntry, Rating, Recipe(+SteamClient), CatalogLoader(JSONCatalog),
  CatalogSearchEngine, WildcardMatcher
Sources/WinHubRuntime/   everything that touches disk, network and Wine processes
  RuntimeManifest/RuntimeManager   downloads, checks and installs the Wine engine (and overlays)
  Bottle/BottleStore                bottle = folder with bottle.json + prefix/ (WINEPREFIX)
  BottleArchive                     export/import .winhubbottle (ditto zip); import = new id, free name, profile adopted
  WineEnvironment                   builds the environment of Wine processes (pure function)
  WineLauncher                      wineboot, winecfg, installers, start /unix, wineserver -k
  ProgramScanner                    finds .lnk files in the bottle's Start Menu/Desktop
  ShellLink, ProgramIcon            reads a .lnk's target (MS-SHLLINK) and the .exe's icon (PE resources) as .ico
  WineServerStatus                  "bottle running" = someone holds the wineserver `lock`
  WineOrphanReaper                  ends processes orphaned by a dead wineserver
  BottleSession                     <bottle>/session.json: which open WinHub is running Wine in the bottle
  BottleGuard                       checks other WinHub / other engine / second Steam before running Wine
  Components                        DXVK and winetricks (ComponentManager) + GraphicsBackend
  CompatRules, D3DMetal             per-bottle engine rules; the user's D3DMetal folder
  CompatDatabaseSync                downloads winhub-engine's signed rule database
  AppLauncherBuilder                shortcuts ~/Applications/WinHub/<bottle>/<program>.app
  SteamWebHelperWrapper             puts the wrapper in place of Steam's steamwebhelper.exe
  AppUpdater                        finds the newest GitHub release, downloads, checks and swaps the .app
  RemoteDataSync                    local copy of the Resources/ JSON from the main branch
  Downloader, ProcessRunner         utilities
Sources/WinHub/          SwiftUI app
  WinHubApp (scenes, menus, Settings, onOpenURL), RootView (sidebar + sheets),
  CatalogStore (@Observable, catalog and search), WineStore (@Observable, engine/bottles/tasks),
  UpdateStore (@Observable, updates; OfficialData = downloaded JSON or the bundled one),
  CatalogView, EntryViews (cards, detail, Install/Open actions), BottleViews (bottles, programs, sheets)
  Resources/: catalog.json, runtimes.json, components.json
scripts/make-icon.swift  app icon drawn in code (CoreGraphics → .icns); no images in Git
Support/steamwebhelper-wrapper/  Windows program (C, MIT) built by package-app.sh with mingw-w64
```

Dependencies: `WinHub` → `WinHubCore` + `WinHubRuntime`. Core and Runtime depend on neither each other nor the UI.

User data: `~/Library/Application Support/WinHub/{Runtimes,Components,Bottles,Remote,compat}`,
`~/Library/Caches/WinHub/{Downloads,Updates}`, shortcuts in `~/Applications/WinHub/`.

## Main flows

- **Engine:** `runtimes.json` → `RuntimeManager.install` (download → SHA-256 → `tar` → overlay, if any → marker
  `.winhub-runtime.json` written last). Today the first entry is `winhub-wine-11.0-r3` (WineHQ
  `wine-devel-11.18-osx64` as the base + winhub-engine overlay with Wine 11.0 from CrossOver's sources; x86_64,
  needs Rosetta 2); `winhub-wine-11.0-r2` and `winhub-wine-11.18-r1` stay listed for bottles that use them.
- **New bottle:** `BottleStore.create` → `WineLauncher.initialize` (`wineboot --init` with Mono/Gecko off →
  `winecfg /v <version>` → `wineserver -k`/`-w`).
- **Recipe** (`Recipe` in the catalog): bottle by name (reused if it exists) → dependencies via winetricks →
  download the installer → `runInstaller` → check `launch.windowsPath` → open.
- **Opening a program:** `WineStore.launch` fires and does not wait; "running" comes from `WineServerStatus`, not
  from the started process (Steam restarts itself).
- **Updates** (`UpdateStore`, 10 s after launch and then every hour): (1) `RemoteDataSync` downloads
  `catalog.json`, `runtimes.json` and `components.json` from
  `raw.githubusercontent.com/<repo>/main/Sources/WinHub/Resources/` and only writes them to
  `Application Support/WinHub/Remote/` if they decode in this app version; the official catalog and manifests are
  reloaded (a catalog imported by the user is never replaced). A `runtimes.json` with a newer Wine does not
  invalidate the installed one (`RuntimeManager.installedRuntimes()`): the sidebar offers "Atualizar o Wine".
  (2) `CompatDatabaseSync` (below). (3) `AppUpdater` reads `releases/latest` (with ETag), downloads `WinHub.zip`,
  checks the SHA-256 of the `digest` GitHub computes, validates identifier, version, `codesign --verify` and, with
  a Developer ID, the same TeamIdentifier. "Reiniciar para atualizar" runs an `sh` that waits for the PID to exit,
  swaps the `.app` (rolls back on failure) and opens it. The repository comes from the `WinHubUpdateRepository`
  Info.plist key (`GITHUB_REPOSITORY` in CI). Every push to `main` makes the release `v<VERSION>.<run_number>`
  (`release.yml`).
- **`.app` shortcuts:** the shortcut's script only runs `open "winhub://open?bottle=<uuid>&shortcut=<path>"`;
  `WineStore.handle(_:)` checks that the `.lnk` is inside the bottle's `drive_c` and opens it.

## Decisions and pitfalls (learned in practice)

Dated decisions are in `docs/decisions.md`. The pitfalls an agent must know:

- **Engine = official WineHQ base.** WineCX 24 (the open build of CodeWeavers' code) breaks Steam on macOS 27: the
  system returns an empty TCP connection list (`net.inet.tcp.pcblist`) to ordinary apps, and Steam rejects
  `steamwebhelper` ("unexpected transport error"). Wine ≥ 9.17 builds that table in wineserver and works. Do not
  go back to an engine without that fix. Engine revision 2 (CrossOver 26 sources, Wine 11.0) has it
  (`nsiproxy.sys/tcp.c` asks wineserver for `get_tcp_connections`); Steam was tested on it on 2026-10-12 and opened
  with its saved login.
- **Steam's black window (Wine 11 on macOS).** Steam's interface is a Chromium (`steamwebhelper.exe`) that draws
  each window from another process (the GPU one); Wine 11's macOS driver does not show what one process draws in
  another's window, so everything is black (with or without GPU). Fix: `SteamWebHelperWrapper` replaces
  `steamwebhelper.exe` with `Support/steamwebhelper-wrapper` (the original becomes `steamwebhelper_real.exe`),
  which starts it with `--in-process-gpu`; `WINHUB_CEF_FLAGS` overrides the options for tests. The swap is done
  only right before each launch (Steam restores the helper when it updates); while Steam runs it is always undone,
  because Steam restarts itself **without arguments** after updating and then checks its files (a periodic swap
  once caused a restart loop). With the wrapper installed, the launch carries `-noverifyfiles`
  (`SteamClient.launchArguments(wrapperInstalled:)`; in the `.lnk`, `start /unix Steam.lnk -noverifyfiles` passes
  it on), otherwise Steam notices the different size and restores the original. **Without the wrapper (first
  launch after installing) do not use the option:** the installer skips the step that downloads the client and
  stalls. That is why the first session after installing is black; from the second on it works (tested in a fresh
  bottle). Every wrapper build contains `SteamWebHelperWrapper.marker`, so an old wrapper is never mistaken for
  Steam's helper (it would start itself in a loop). These do not work: Steam's `-cef-*` options (it does not pass
  them on), `renderer=vulkan` in wined3d (the window does not even appear) and DXVK (D3D11 works, the window stays
  black). There are no more official Wine 10 builds for macOS. With `swift run` the wrapper only exists if
  `WINHUB_STEAMWEBHELPER_WRAPPER` points to it (`scripts/build-steam-wrapper.sh`); without it, black window.
- **Privacy (TCC) belongs to WinHub:** macOS treats Wine processes started by WinHub as WinHub. Without a usage
  description in the app's `Info.plist`, a protected resource is refused **without a prompt** and the asking thread is
  killed (games with voice chat hung on the microphone). `package-app.sh` declares `NSMicrophoneUsageDescription`;
  add the matching key before supporting another resource (camera, for example). With `swift run`, a `winhub://` link
  goes to whichever WinHub macOS picks (possibly `/Applications/WinHub.app`); use `open -a <app> <url>` in tests.
- **Never run Wine from inside a shortcut `.app`'s process.** Programs started that way hang (Steam stops at
  "Verifying…"). That is why shortcuts delegate to WinHub through `winhub://`.
- **One main window (`Window`, not `WindowGroup`).** A `WindowGroup` opened a new window for every `winhub://`
  link, each with its own dialogs and startup task, and macOS brought them all back on the next launch. A
  `Window` scene receives `onOpenURL` in its single window; closing it quits the app.
- **Orphans of a dead wineserver.** If wineserver dies without ending its clients (for example SIGKILL),
  `winebus.sys`'s `winedevice.exe` lives forever (an IOHID loop that never talks to the server; Wine handles
  SIGTERM by ending only one thread). The next wineserver reuses the folder `/tmp/.wine-<uid>/server-<dev>-<inode>/`
  and its `-k` does not reach the orphans. `WineOrphanReaper` ends them (SIGKILL) when nobody holds the folder's
  `lock`; it runs after `shutdown` and before each `launch`. Use the `lock`, not the `socket`, to know whether the
  server lives: a server killed with SIGKILL leaves the socket behind.
- **App updates:** only with the packaged `WinHub.app`, outside Gatekeeper's translocation (`/AppTranslocation/`)
  and in a writable folder; with `swift run` only data updates. An asset without `digest` is ignored. The zip
  downloaded by `URLSession` gets no quarantine attribute, so the new app opens without a new Gatekeeper prompt.
  Changes to the JSON must stay decodable by older versions (`decodeIfPresent`), or old apps ignore the update
  until they update themselves.
- **Default `WINEDEBUG` is `fixme-all`** (`err` does not hide "fixme" lines and floods the logs).
- **Isolated environment:** `WineEnvironment` only inherits `HOME, USER, LOGNAME, LANG, LC_ALL, TMPDIR, SHELL`;
  always sets `ROSETTA_ADVERTISE_AVX=1` and `DOTNET_EnableWriteXorExecute=0`. The bottle's settings win.
- **DXVK-macOS** only has `d3d10core` and `d3d11` (`dxgi` is Wine's). DXVK/DXMT → `n,b` overrides. Going back to
  Wine copies the engine's DLLs back (`lib/wine/{x86_64,i386}-windows`; in Wine 11 `system32` holds exact copies
  of them) and **removes** the overrides; only an engine without those files gets `b`.
- **Steam games in the catalog:** `steamGame` (`installDir`, `executable`, `graphics`) says where the game lives
  and which Direct3D worked best in our tests. The game's page only offers the button "Usar … neste jogo";
  nothing is applied without a click.
- **Display modes on the Mac:** `winemac.drv` only lists the macOS modes (no 16:9) and only changes the mode while
  the app is in front. See `docs/compat/hollow-knight.md`. **Resoluções extras** (`Bottle.extraDisplayModes`) sets
  `EmulateModeset` in `HKCU\Software\Wine\X11 Driver` (win32u reads it whatever the driver): Wine adds 16:9 and other
  modes up to the screen size **in points** (1280×720 on a 1470×956 Mac) and fakes the change. It is bottle-wide on
  purpose: the bottle's desktop process builds the mode list for every program when it starts, so per-program
  `AppDefaults` keys give lists that depend on which process came first, and `applyDisplayModes` ends the session
  `reg` started. Larger modes (1080p) need `RetinaMode`, which is prefix-wide and changes every program's screen.
- **Per-program graphics on older engines** (`Bottle.programGraphics`, `applyProgramGraphics`): the DLLs go to the
  `.exe`'s folder (64- or 32-bit by the PE header) and the overrides to
  `HKCU\Software\Wine\AppDefaults\<exe>\DllOverrides`. The environment's `WINEDLLOVERRIDES` beats the registry, so
  the bottle cannot force `b` on those DLLs. Only DLLs identical to the ones WinHub copied are deleted; if the game
  ships its own, the change is refused.
- **wined3d on macOS only reaches D3D feature level 9_3** (OpenGL 4.1). Unity 6 games in D3D11 (for example Hollow
  Knight) fail to create the device. They need DXVK, DXMT or D3DMetal (`docs/compat/`).
- **Engine revision 2 (`backend-dispatch` feature):** Wine 11 from CrossOver's LGPL sources (with msync and the
  Metal hooks DXMT and D3DMetal use), installed as an **overlay** over the official WineHQ build:
  `overlay.replace` (`["bin", "lib/wine"]`) deletes those folders of the base before unpacking, and the rest
  (libraries, wine-mono, wine-gecko) stays. The engine's `winhubcompat.so` picks each process's Direct3D from
  `WINHUB_GRAPHICS_BACKEND` (`auto`, `wined3d`, `dxmt`, `dxvk`, `d3dmetal`) and puts its folder (`lib/dxmt`,
  `lib/dxvk` or the user's D3DMetal) first in Wine's DLL path: **nothing is copied** into the bottle and the `n,b`
  overrides are not used. Programs with their own Direct3D become rules in `<bottle>/compat-rules.json`
  (`CompatRules`, `WINHUB_COMPAT_RULES`). Bottles from the time WinHub copied DLLs are migrated before a program
  opens (`migrateToDispatchedGraphics`): Wine's DLLs come back and the copies and overrides go away. Revision 3
  (release `wine-11.0-r3`, the first engine in `runtimes.json`) adds `replace_exe_path` rules and the `nvext`
  feature (DXMT's NVAPI, "Recursos da NVIDIA").
- **The engine's rule database:** `CompatDatabaseSync` (in `UpdateStore`'s periodic check) downloads
  `data/compatdb.json` and `compatdb.json.sig` from winhub-engine's `main`, checks the Ed25519 signature with the
  built-in key (`CompatDatabaseSync.publicKey`) and only writes to `Application Support/WinHub/compat/compatdb.json`
  a database with a larger `timestamp` than the current one. The private key lives outside the repositories (the
  maintainer's `~/.winhub-signing/`; see winhub-engine's `SECURITY.md`). Changing the key needs a new app version.
- **D3DMetal:** the folder comes from the settings (`D3DMetal.location`); the picker accepts the Game Porting
  Toolkit's folder, its `redist` or its `redist/lib` (`D3DMetal.resolve`).
- **Older engines (r1, no `backend-dispatch`):** DXMT comes as native DLLs in `lib/dxmt/{x64,x32}`, copied by
  `applyGraphics(.dxmt)`, and DXVK-macOS comes from the component. That path stays in the code for people still
  on those engines. `.auto` and `.d3dmetal` do not exist there.
- **msync** does not exist in official Wine; revision 2 brings CrossOver's (feature `msync`). It is per bottle
  (`Bottle.msync`). `ntdll` refuses processes whose `WINEMSYNC` differs from the running `wineserver`, so
  `WineStore.setMSync` ends a running bottle before saving (after a confirmation in the UI);
  `WineEnvironment.needsServerRestart` says which changes need that.
- **winetricks:** some verbs need `cabextract`, which macOS lacks. If `components.json` has a `cabextract`
  component, it goes into winetricks' `PATH`.
- **Testing games:** test on an APFS clone of the bottle and **never run two Steam instances of the same bottle at
  once** (on 2026-10-11 that made Steam uninstall two games from the original bottle). Never risk a user's real
  bottle.
  WinHub itself now refuses (and offers to end) a bottle used by another open WinHub or another engine, and Steam
  in a second bottle (`BottleGuard`; only between WinHub copies that have this guard); the clone is still the
  rule.
- **Swift 6.1 compatibility (Xcode 16.4, used in CI):** `async` closures passed to methods of `@MainActor` classes
  must be marked `@MainActor` (or return a `Sendable` result). Local Swift may be newer and not complain; CI does.
- `@State`, `#Preview` and `@Previewable` need Xcode (the macro plug-in is not in the Command Line Tools).

## Conventions

- **Interface texts are written in Brazilian Portuguese** (the source language) and translated in
  `Sources/WinHub/Resources/Localizable.xcstrings`; code, identifiers and comments in English. Text that is not a
  SwiftUI literal (errors, progress, enum titles) uses `String(localized:)`, in any module. After changing the
  interface, run `./scripts/update-strings.sh` and translate the new keys; `LocalizationTests` fails on a key without
  English or with different arguments. `package-app.sh` copies the compiled `.lproj` folders into the app, so with
  `swift run` the interface stays in Portuguese. Catalog entries translate through `localizedNames` and
  `localizedSummaries`.
- Short comments, only where the "why" is not obvious (follow the density of the surrounding code).
- New `Codable` models: use `decodeIfPresent` with a default to stay compatible with old JSON (`bottle.json`, user
  catalogs).
- Tests with **Swift Testing** (`import Testing`, `@Suite`, `@Test`, `#expect`). Tests that need a real Wine stay
  behind `RUN_WINE_TESTS=1`.
- Prefer pure, testable logic in Core/Runtime; the UI only orchestrates through `WineStore`/`CatalogStore`.
- Installers and components: official URLs only; SHA-256 required for components, optional for installers the
  vendor updates at the same address (for example `SteamSetup.exe`).

## CI and releases

- `.github/workflows/ci.yml`: build + tests + packaging on every push/PR (runner `macos-15`, Xcode 16.4).
- `.github/workflows/release.yml`: every push to `main` (except docs-only changes) publishes `v<VERSION>.<run_number>`
  with `WinHub.zip`; signs/notarizes if the Developer ID secrets exist (listed in the file).
- `.github/workflows/docs.yml`: builds the documentation book (mdBook, `book/en` and `book/pt-BR`) and publishes it
  to GitHub Pages from `main`.
- Commits: English messages, imperative mood. The repository author uses the GitHub noreply e-mail.

## Possible next steps

See `ROADMAP.md` and `docs/gaps.md`.
