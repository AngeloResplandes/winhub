**English** · [Português (Brasil)](ROADMAP.pt-BR.md)

# WinHub roadmap

**Stage: 0.2**, released on every push to `main`

> **Last reviewed:** 2026-10-12 · **Target:** CrossOver 26.3.0 for macOS

One-page summary. Detail: [parity with CrossOver](docs/crossover-parity.md) (weights and evidence),
[gaps](docs/gaps.md) (the ranked work list), [decisions](docs/decisions.md).

## Headline

| | Value | Kind |
|---|---|---|
| **WinHub parity with CrossOver** | **~57%** | estimated, weighted by dimension |
| Catalog search | same results as CrossOver in the cases compared | measured |
| Steam | installs with one click; saved login kept across engines | measured |
| Direct3D 11 game | Hollow Knight at 60 FPS through DXMT | measured |
| Catalog | 34 titles, 1 recipe, 6 compatibility reports | measured |

## Done

- Catalog with CrossOver-like search, recipes, bottles, any installer, shortcuts, winetricks components.
- Steam's black window fixed with a wrapper; orphaned Wine processes cleaned up.
- Automatic updates of the app, catalog and manifests.
- Direct3D per bottle and per program: Wine, DXVK, DXMT; with engine revision 2, also Automático and D3DMetal,
  chosen by the engine with nothing copied into bottles.
- Signed per-game rule database from winhub-engine.
- Engine revision 2 (`wine-11.0-r2`) is the default engine.
- Program icons, read from each program's `.exe`, in the lists and on `.app` shortcuts.
- English interface (String Catalog), following the macOS language; English summaries in the catalog.
- Bottle export and import (`.winhubbottle`).
- Resoluções extras: Wine's emulated display modes (16:9 and others up to the screen size) per bottle.

## Next

1. **More tested titles:** catalog entries, recipes and a compatibility report per game.
2. **Notarized releases.**
3. **More interface languages** in the same String Catalog.

## Revision history

| Date | Change |
|---|---|
| 2026-10-12 | First roadmap. |
| 2026-10-12 | Engine revision 2 is the default. |
| 2026-10-12 | Program icons and extra display modes done. |
| 2026-10-12 | English interface done. |
| 2026-10-12 | Bottle export and import done. |
