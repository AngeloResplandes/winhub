**English** · [Português (Brasil)](README.pt-BR.md)

<p align="center">
  <img src="docs/icon.svg" width="128" height="128" alt="WinHub icon">
</p>

<h1 align="center">WinHub</h1>

<p align="center">
  <b>Find, install and open Windows programs and games on the Mac, like any other app.</b>
</p>

<p align="center">
  <a href="https://github.com/AngeloResplandes/winhub/releases/latest/download/WinHub.zip">Download</a> ·
  <a href="https://angeloresplandes.github.io/winhub/">Documentation</a> ·
  <a href="ROADMAP.md">Roadmap</a> ·
  <a href="docs/reverse-engineering.md">How CrossOver was studied</a> ·
  <a href="docs/crossover-parity.md">Parity with CrossOver</a>
</p>

WinHub is a native macOS app that takes care of everything [Wine](https://www.winehq.org/) needs to run Windows
programs, with no virtual machine and no Windows install. Find a title in the catalog and install it; titles with
a recipe, like Steam, install with one click. Each program lives in a "bottle", a separate Windows with its own
settings, and installed programs get shortcuts that open from the Finder, Spotlight or the Dock.

WinHub was designed by studying **how CrossOver 26.3 behaves** (its catalog search, its bottles, how it picks
each game's Direct3D) and reproducing that behaviour with open code. Its engine,
[winhub-engine](https://github.com/AngeloResplandes/winhub-engine), is Wine 11 built from the sources CodeWeavers
publishes under the LGPL, with DXMT, DXVK and an open module that picks the Direct3D of each process. No closed
CrossOver code or data is used.

## Features

| | |
|---|---|
| **Catalog with search** | words in order, ignoring case and accents, names in your language; the same rules as CrossOver's search |
| **One-click recipes** | Steam installs and opens with one click; Steam games get "Jogar pela Steam" |
| **Any installer** | pick an `.exe` or `.msi` and a bottle (⌘I) |
| **Bottles** | each with its Windows version, Direct3D, msync, performance HUD and winetricks components |
| **Direct3D per bottle or per game** | Automático, Wine, DXMT (Metal), DXVK (Vulkan) or your own D3DMetal ([Graphics](docs/graphics.md)) |
| **Steam that works** | a small wrapper fixes Steam's black window on Wine 11 for macOS |
| **Shortcuts** | `~/Applications/WinHub/<bottle>/<program>.app`, for the Finder, Spotlight and the Dock |
| **Updates by itself** | app, catalog, engine list and signed per-game rules, all checked before use |

## Status

| | |
|---|---|
| Version | 0.2 (a release on every push to `main`) |
| Parity with CrossOver | **~57%** (estimated, [details](docs/crossover-parity.md)) |
| Tested | Steam with saved login; Hollow Knight (Direct3D 11) at 60 FPS through DXMT ([reports](docs/compat/README.md)) |
| Biggest gaps | Direct3D 12 without D3DMetal, small catalog, empty rule database ([all gaps](docs/gaps.md)) |

### Known limitations

- **D3DMetal** (Apple's Game Porting Toolkit) is not included: Apple's license does not allow redistributing it.
  If you have it, point **Ajustes → D3DMetal** to it.
- Wine's own Direct3D only reaches feature level 9_3 on macOS; Direct3D 11 games need DXMT, DXVK or D3DMetal.
- Games only see the Mac screen's own display modes (no 1920×1080 on most Macs).
- The engine is x86_64: Apple silicon Macs need **Rosetta 2**, whose general support Apple keeps until macOS 27.
- The interface is in Brazilian Portuguese only.

## Install

1. Download [`WinHub.zip` from the latest release](https://github.com/AngeloResplandes/winhub/releases/latest/download/WinHub.zip)
   and move `WinHub.app` to Applications.
2. If the app is not notarized, macOS blocks the first launch. Try to open it once, then click **Open Anyway** in
   **System Settings → Privacy & Security** (since macOS 15, right-click → Open is not enough).
3. In WinHub, click **Baixar o Wine** (about 190 MB, once).

From then on WinHub updates itself: the catalog follows this repository, and new app versions download in the
background and install when you click **Reiniciar para atualizar** (turn it off in **Ajustes → Atualizações**).

## Build

macOS 14+, Xcode 16+ (Swift 6), Rosetta 2 on Apple silicon.

```bash
swift build && swift test
```

```bash
swift run WinHub
```

Packaging, Steam with `swift run`, tests with a real Wine and testing a local engine: [Development](docs/development.md).

## Documentation

The full documentation is a book, in English and Brazilian Portuguese:
**[angeloresplandes.github.io/winhub](https://angeloresplandes.github.io/winhub/)** (sources in [`docs/`](docs/)).

## Rules

- CrossOver was studied for behaviour only; its code, data, catalog and interface are never copied. See
  [Reverse engineering](docs/reverse-engineering.md) and [CONTRIBUTING](CONTRIBUTING.md).
- No third-party binaries in the repository: Wine, components and installers are downloaded from official sources
  and checked by SHA-256.
- Apple's D3DMetal is never redistributed.

## License

MIT ([LICENSE](LICENSE)). Third-party components: [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md).

---

**Independent project.** Not affiliated with CodeWeavers, Apple, Microsoft or Valve. CrossOver is a trademark of
CodeWeavers; the name is used only to describe what was studied and where the engine's Wine sources come from.
