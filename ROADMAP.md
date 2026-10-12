**English** · [Português (Brasil)](ROADMAP.pt-BR.md)

# WinHub roadmap

**Stage: 0.2**, released on every push to `main`

> **Last reviewed:** 2026-10-12 · **Target:** CrossOver 26.3.0 for macOS

One-page summary. Detail: [parity with CrossOver](docs/crossover-parity.md) (weights and evidence),
[gaps](docs/gaps.md) (the ranked work list), [decisions](docs/decisions.md).

## Headline

| | Value | Kind |
|---|---|---|
| **WinHub parity with CrossOver** | **~53%** | estimated, weighted by dimension |
| Catalog search | same results as CrossOver in the cases compared | measured |
| Steam | installs with one click; saved login kept across engines | measured |
| Direct3D 11 game | Hollow Knight at 60 FPS through DXMT | measured |
| Catalog | 31 titles, 1 recipe | measured |

## Done

- Catalog with CrossOver-like search, recipes, bottles, any installer, shortcuts, winetricks components.
- Steam's black window fixed with a wrapper; orphaned Wine processes cleaned up.
- Automatic updates of the app, catalog and manifests.
- Direct3D per bottle and per program: Wine, DXVK, DXMT; with engine revision 2, also Automático and D3DMetal,
  chosen by the engine with nothing copied into bottles.
- Signed per-game rule database from winhub-engine.

## Next

1. **Ship engine revision 2** as the default in `runtimes.json`.
2. **More tested titles:** catalog entries, recipes and a compatibility report per game.
3. **English interface** (String Catalogs), then other languages.
4. **Bottle export and import.**
5. **Program icons** in lists and shortcuts.
6. **Notarized releases.**

## Revision history

| Date | Change |
|---|---|
| 2026-10-12 | First roadmap. |
