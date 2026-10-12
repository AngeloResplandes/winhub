**English** · [Português (Brasil)](pt-BR/README.md)

# WinHub documentation

WinHub is a native macOS app (SwiftUI) that finds, installs and runs Windows programs and games with
[Wine](https://www.winehq.org/). Each program lives in a "bottle", a separate Windows with its own settings, and
WinHub handles everything Wine needs: the engine, the bottles, installers, Windows components, Direct3D and
shortcuts that open from the Finder, Spotlight or the Dock.

WinHub was built by studying **how CrossOver 26.3 behaves** (its catalog search, how it sets up bottles and how
it picks the Direct3D of each game) and reproducing that behaviour with open code. No CrossOver code or data is
used. The engine side of that work lives in [winhub-engine](https://github.com/AngeloResplandes/winhub-engine).

## Where to start

| If you want to… | Read |
|---|---|
| Understand how the app is put together | [Architecture](architecture.md) |
| Build, test and run it from source | [Development](development.md) |
| Choose a Direct3D for a game | [Graphics](graphics.md) |
| Know exactly how catalog search behaves | [Catalog search](catalog-search.md) |
| See what was studied in CrossOver and how | [Reverse engineering](reverse-engineering.md) |
| See how close WinHub is to CrossOver | [Parity with CrossOver](crossover-parity.md) and [Gaps](gaps.md) |
| Know why things are the way they are | [Decisions](decisions.md) |
| See how specific games run | [Compatibility reports](compat/README.md) |

## The two repositories

| Repository | What it holds |
|---|---|
| [`AngeloResplandes/winhub`](https://github.com/AngeloResplandes/winhub) (this one) | The app: catalog, bottles, installers, settings, updates |
| [`AngeloResplandes/winhub-engine`](https://github.com/AngeloResplandes/winhub-engine) | The Wine engine WinHub downloads: Wine 11 from CrossOver's LGPL sources, DXMT, DXVK and `winhubcompat`, which picks each process's Direct3D ([documentation](https://angeloresplandes.github.io/winhub-engine/)) |
