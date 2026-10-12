**English** · [Português (Brasil)](pt-BR/gaps.md)

# Gaps

> **Last reviewed:** 2026-10-12

Known gaps, ranked by how many people and games they block. Engine-only gaps are detailed in
[winhub-engine's gaps](https://angeloresplandes.github.io/winhub-engine/gaps.html). Parity numbers:
[Parity with CrossOver](crossover-parity.md).

| # | Gap | Blocks | Likely path |
|---|---|---|---|
| 1 | **Direct3D 12 without D3DMetal** | Direct3D 12-only games ([The Witcher 3](compat/the-witcher-3.md), Resident Evil 4 Remake, Hogwarts Legacy) for people without the Game Porting Toolkit | engine work: DXMT's Direct3D 12 or vkd3d-proton |
| 2 | **Small catalog** | finding a title and knowing it works: 31 titles, 1 recipe | add titles and recipes as they are tested; a [compatibility report](compat/README.md) per game |
| 3 | **Empty rule database** | games that need a specific Direct3D, variable or argument to start | one rule per tested game in winhub-engine's `data/compatdb.json` |
| 4 | **Game videos** | cutscenes and intros in many games | GStreamer and H.264 in the engine |
| 5 | **16:9 display modes** | 1920×1080 and other modes that are not the Mac screen's own ratio | partly done: **Resoluções extras** turns on Wine's emulated modes (`EmulateModeset`), with 16:9 up to the screen size in points (1280×720 on a 1470×956 Mac); 1920×1080 there needs `RetinaMode` (prefix-wide) or a change in the engine's `win32u` |
| 6 | **Interface only in Brazilian Portuguese** | people who do not read Portuguese | move the texts to String Catalogs and translate, starting with English |
| 7 | **Bottle export and import** | moving a bottle to another Mac, backups | archive the bottle folder with its `bottle.json` |
| 8 | **Program icons** | recognizing programs in the lists and shortcuts | done: read from the `.exe` the shortcut points to, in the lists and on `.app` shortcuts |
| 9 | **Unnotarized releases** | a smooth first launch (macOS asks for "Abrir Mesmo Assim") | sign and notarize with a Developer ID (the release workflow already supports it) |
| 10 | **x86_64 only** | the future: Rosetta 2's general support ends in macOS 28 | follow upstream Wine's ARM64 work for macOS |
