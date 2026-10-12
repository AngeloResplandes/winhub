**English** · [Português (Brasil)](pt-BR/development.md)

# Development

## Requirements

- macOS 14 or newer; Apple silicon Macs also need **Rosetta 2** (the Wine engine is x86_64).
- Xcode 16 or newer (Swift 6). `@State`, `#Preview` and `@Previewable` need Xcode; the Command Line Tools lack
  the macro plug-in.
- To package the app: mingw-w64 (`brew install mingw-w64`), which builds the Steam wrapper.

## Build, test, run

```bash
swift build
swift test            # 116 tests; the ones that need a real Wine stay off
swift run WinHub      # runs without packaging
open Package.swift    # opens in Xcode
```

With `swift run`, `.app` shortcuts and `winhub://` links do not work, and app updates are off (only the catalog
and manifests update).

### Steam with `swift run`

Without the wrapper, Steam's window stays black ([why](decisions.md#2026-10-11-replace-steamwebhelper-with-a-wrapper)).
Build it and point WinHub to it:

```bash
./scripts/build-steam-wrapper.sh
```

```bash
WINHUB_STEAMWEBHELPER_WRAPPER=.build/steamwebhelper-wrapper.exe swift run WinHub
```

### Tests with a real Wine

They need the engine already downloaded by the app (`~/Library/Application Support/WinHub/Runtimes`):

```bash
RUN_WINE_TESTS=1 swift test --filter ComponentIntegrationTests
```

`WINHUB_DXVK_ARCHIVE` and `WINHUB_WINETRICKS` use local files instead of downloading; `WINHUB_CABEXTRACT_VERB=corefonts`
also tests cabextract. To download and install the first engine in `runtimes.json` for real:

```bash
RUN_WINE_TESTS=1 WINHUB_INSTALL_ENGINE=1 swift test --filter EngineInstallTests
```

## Packaging

```bash
./scripts/package-app.sh
```

It builds `dist/WinHub.app` (universal) and `dist/WinHub.zip` with an ad-hoc signature, drawing the icon from
code (`scripts/make-icon.swift`) and building the Steam wrapper. With `DEVELOPER_ID` and `NOTARY_PROFILE` set, it
signs and notarizes. To check a UI change, open the packaged app: `open dist/WinHub.app`.

## Releases

Every push to `main` that changes more than Markdown and docs runs `.github/workflows/release.yml`, which tests,
packages and publishes `v<VERSION>.<run number>` (for example `v0.2.57`) with `WinHub.zip`. Installed apps find it
and update themselves. Edit `VERSION` to change the major or minor number. The signing and notarization secrets
are listed at the top of the workflow.

The CI (`ci.yml`) uses Swift 6.1 (Xcode 16.4), which is stricter than recent local Swift about isolation:
`async` closures passed to `@MainActor` methods must be marked `@MainActor` (or return a `Sendable` result).

## Testing a local engine

To try an engine build from [winhub-engine](https://github.com/AngeloResplandes/winhub-engine) before it is
released (this is how revision 2 was tested on 2026-10-12):

1. Build the engine (`./scripts/package.sh` in winhub-engine writes the overlay and `winhub-manifests.json` to
   `work/dist`).
2. Install it as WinHub would, into `~/Library/Application Support/WinHub/Runtimes/<id>/`: unpack the official
   Wine build, remove the folders listed in `overlay.replace`, unpack the overlay over it, and write the
   `runtime` entry of `winhub-manifests.json` to `.winhub-runtime.json` **last**.
3. Put that entry first in `~/Library/Application Support/WinHub/Remote/runtimes.json` (keep a copy of the file).
4. Turn off **Ajustes → Atualizações → Procurar atualizações automaticamente**, or the next check replaces
   `runtimes.json` with the one from `main`.
5. Test on a **copy** of a bottle (on APFS, `cp -c` makes an instant clone) and never run two Steam instances of
   the same bottle at once ([why](decisions.md#2026-10-11-never-run-two-steam-instances-of-one-bottle)).

To undo: restore the copy of `runtimes.json`, turn automatic checks back on and remove the engine folder.

## Conventions

- **Interface texts are written in Brazilian Portuguese** (the source language) and translated in
  `Sources/WinHub/Resources/Localizable.xcstrings`; code, identifiers and comments in English. Text that is not a
  SwiftUI literal (errors, progress, enum titles) uses `String(localized:)`, in any module. After changing the
  interface, run `./scripts/update-strings.sh` and translate the new keys; `LocalizationTests` fails on a key without
  English or with different arguments. `package-app.sh` copies the compiled `.lproj` folders into the app, so with
  `swift run` the interface stays in Portuguese. Catalog entries translate through `localizedNames` and
  `localizedSummaries`.
- Short comments, only where the "why" is not obvious.
- New `Codable` models use `decodeIfPresent` with a default, so older JSON (`bottle.json`, user catalogs) keeps
  decoding, and changes to the published JSON must stay decodable by older app versions.
- Tests use **Swift Testing** (`import Testing`, `@Suite`, `@Test`, `#expect`).
- Logic goes in Core or Runtime where it can be tested; the UI only orchestrates through the stores.
- Installers and components only from official URLs; SHA-256 is required for components and optional for
  installers the vendor updates in place (such as `SteamSetup.exe`).
- Commits: English, imperative mood.
