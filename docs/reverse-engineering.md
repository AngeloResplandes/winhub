**English** · [Português (Brasil)](pt-BR/reverse-engineering.md)

# Reverse engineering: what was studied in CrossOver

> **Last reviewed:** 2026-10-12 · **Target:** CrossOver 26.3.0 for macOS

WinHub reproduces behaviour of CrossOver 26.3 that was studied **from the outside**: what the app does, how its
bundle is laid out, which files and settings it uses. This page records what was studied in the app itself (the
catalog and bottles). The engine (Wine, Direct3D, the per-game rules) has its own page in winhub-engine:
[How CrossOver runs games](https://angeloresplandes.github.io/winhub-engine/reverse-engineering.html).

## Rules

- We study **what CrossOver does**, never copy how it is written.
- **Never** copy code, binaries, texts, translations, icons or data from CrossOver. WinHub does not read, copy or
  redistribute CrossOver's catalog, its compatibility database or its interface.
- Code CodeWeavers publishes under the LGPL (CrossOver's Wine tree) is used by winhub-engine, with attribution.
- This documentation describes behaviour. Decompiled code, addresses, internal symbol names and analysis logs
  stay out of the repository.

## Method

1. **Bundle inspection.** How `CrossOver.app` is organized: the main executable, the interface files, the bundled
   Python modules that manage the catalog and bottles, the launcher scripts (Perl, readable text), the bottle
   templates and the data files.
2. **Static analysis** with [REA](https://github.com/morluto/rea) (Hopper provider) of the main executable and the
   interface files, to learn the order of decisions: what the search field sends, how the list is filtered,
   sorted and cut, where the catalog comes from and how it is updated.
3. **Confirmation by behaviour.** The results WinHub's search computed were compared, before looking, with
   screenshots of CrossOver's own interface (system in Brazilian Portuguese): the empty search showed the same
   8 featured titles in the same order, and `excel` the same 16 results in the same order, including localized
   names and "Otoshimizu Excellent" (the pattern also matches inside words). An earlier prototype was also checked
   against a copy of the catalog on the analyst's machine: 4,489 titles, no differences in name, rating or
   listing. That catalog never entered any repository.

## Catalog search

What CrossOver's "install a Windows application" screen does:

- The search is **local and in memory**, over the catalog file CrossOver keeps in the user's Library (a signed
  XML file of about 24 MB). Nothing goes to the network while searching.
- The search field is **continuous**: it searches while you type, with macOS's usual small delay.
- The typed text is split into words, which become a `*word1*word2*` pattern, compared **without case or
  accents** (`LIKE[cd]` semantics) against **only the name**, in the user's language.
- With the field empty, the screen shows the titles the catalog marks as **featured for the Mac**.
- "Show untested applications" is **on by default**. When off, titles whose rating is "untested" or "will not
  install" are hidden.
- The list is sorted by name in **natural order** (`localizedStandardCompare`) and cut at **128 items**.
- Ratings go from 0 to 5 (untested, will not install, installs but will not run, limited functionality, runs
  well, runs great), plus "untrusted" for sources the app does not trust.
- The catalog has one entry per recipe and CrossOver version; when an application appears more than once, the
  app keeps one by a score that prefers the same product, the recipe closest to the installed CrossOver version
  and newer dates. The medal shown is the one for the installed version, or the newest earlier one.
- The catalog is updated in the background at most once a day: when the file is older than two hours, the app
  makes a conditional download, checks its SHA-256 signature against a public key in the bundle and only then
  replaces the file.

**How WinHub reproduces it:**

| CrossOver | WinHub |
|---|---|
| words → `*a*b*` pattern | `CatalogSearchEngine.likePattern(for:)` |
| `LIKE[cd]` comparison | `WildcardPattern` (own matcher, case-, accent- and width-insensitive) |
| name in the user's language | `CatalogEntry.displayName(preferredLanguages:)` |
| featured when empty | `CatalogEntry.isFeatured` |
| untested shown by default | `Options.showUntested = true`; `Rating.isTested` |
| natural order, 128 items | `localizedStandardCompare`, `defaultResultLimit = 128` |
| signed catalog updated in the background | `RemoteDataSync`: WinHub's own `catalog.json` from `main`, kept only if it decodes |

The catalog itself is WinHub's own, written from WinHub's tests. Full specification: [Catalog search](catalog-search.md).

## Bottles and the launcher

What the bottle templates and the launcher scripts (readable text in the bundle) do, and what WinHub does with it:

| CrossOver | WinHub |
|---|---|
| The launcher sets `ROSETTA_ADVERTISE_AVX=1` and `DOTNET_EnableWriteXorExecute=0` for every Wine process | `WineEnvironment` sets the same two variables |
| The graphics choice is a per-bottle setting read by the engine; nothing is copied into the bottle since CrossOver 25 | `Bottle.graphics` → `WINHUB_GRAPHICS_BACKEND`; per-program choices become rules ([Graphics](graphics.md)) |
| The templates remove DXVK DLLs older versions copied into bottles and convert old settings | `migrateToDispatchedGraphics` removes WinHub's own old copies and overrides |
| msync is a per-bottle setting (`WINEMSYNC`) | `Bottle.msync` |
| D3DMetal is bundled | D3DMetal only from the user's own Game Porting Toolkit (Apple's license) |

How close the result is: [Parity with CrossOver](crossover-parity.md).
