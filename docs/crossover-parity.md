**English** · [Português (Brasil)](pt-BR/crossover-parity.md)

# Parity with CrossOver

> **Last reviewed:** 2026-10-15 · **WinHub:** `main` (0.2) · **Target:** CrossOver 26.3.0 for macOS

How close WinHub is to CrossOver, dimension by dimension. "Measured" numbers come from tests; "estimated" ones
are judgement, with the reason next to them. The engine has its own, more detailed table:
[engine parity](https://angeloresplandes.github.io/winhub-engine/crossover-parity.html). The work list is in
[Gaps](gaps.md).

## Headline

| | Value | Kind |
|---|---|---|
| **WinHub parity** (weighted, below) | **~61%** | estimated |
| Catalog search | same results as CrossOver in the cases compared | measured |
| Steam and a Direct3D 11 game | Steam with saved login; Hollow Knight through DXMT at feature level 11.1 | measured on 2026-10-12 |

## By dimension

| Dimension | Weight | CrossOver 26.3 | WinHub | % | Kind |
|---|---:|---|---|---:|---|
| Catalog search | 10% | local, `*a*b*` pattern, localized names, 128 results | the same rules ([Catalog search](catalog-search.md)) | 100% | measured: same 8 featured titles and same 16 results for `excel` |
| Catalog content | 10% | about 4,500 applications with ratings per version | 35 titles, 9 featured, ratings from WinHub's own tests (8 compatibility reports) | 5% | measured count, weight estimated |
| Install recipes | 10% | recipes for thousands of applications | 1 recipe (Steam), any `.exe`/`.msi`, winetricks components | 15% | estimated |
| Bottles | 10% | create, Windows version, settings, templates, archives | create, Windows version, Direct3D, msync, HUD, components, export and import; no templates | 85% | estimated |
| Steam | 10% | works | works: black-window wrapper, saved login, games opened through Steam | 90% | measured |
| Graphics and engine | 20% | the engine inside CrossOver 26.3 | engine revision 4 (`wine-11.0-r4`), the default; see the engine's own parity table | 71% | estimated (engine parity) |
| Per-game rules | 10% | curated database, updated online | per-program Direct3D rules; the signed database channel works and has 2 rules | 20% | estimated |
| Desktop integration | 5% | shortcuts for installed programs | `.app` shortcuts that open from the Finder, Spotlight and the Dock | 80% | estimated |
| Updates | 5% | app, catalog and rules | app, catalog, manifests and signed rules | 95% | estimated |
| Interface and languages | 10% | several languages | Brazilian Portuguese and English | 70% | estimated |
| **Weighted** | 100% | | | **~61%** | estimated |

## Differences that are choices, not gaps

| | CrossOver | WinHub | Why |
|---|---|---|---|
| D3DMetal | bundled | only the user's own | Apple's license does not allow redistribution |
| Automatic Direct3D without D3DMetal | — | DXMT | DXMT is open and covers Direct3D 10/11 |
| Rule database | encrypted | readable JSON, signed with Ed25519 | anyone can read and propose rules |
| Catalog | CodeWeavers' | WinHub's own, versioned in this repository | clean room; every rating comes from a test we ran |
| Source | closed app | MIT, public | |

## Revision history

| Date | Change |
|---|---|
| 2026-10-12 | First assessment (~53%, engine revision 1 as the default). |
| 2026-10-12 | Engine revision 2 becomes the default: graphics and engine 50% → 68%, total ~57%. |
| 2026-10-13 | Bottles 85% (export and import), interface 40% → 70% (English), engine revision 3 the default (68% → 71%); total ~61%. |
| 2026-10-15 | Engine revision 4 the default (`steam_game_id` rules reach games Steam starts); 2 signed rules; total ~61%. |
