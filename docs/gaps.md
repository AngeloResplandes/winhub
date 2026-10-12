**English** · [Português (Brasil)](pt-BR/gaps.md)

# Gaps

> **Last reviewed:** 2026-10-12

Known gaps, ranked by how many people and games they block. Engine-only gaps are detailed in
[winhub-engine's gaps](https://angeloresplandes.github.io/winhub-engine/gaps.html). Parity numbers:
[Parity with CrossOver](crossover-parity.md).

| # | Gap | Blocks | Likely path |
|---|---|---|---|
| 1 | **Engine revision 2 not published** | everything revision 2 brings (Automático, D3DMetal, DXVK and msync from the engine, rules) for users who install from releases | release `wine-11.0-r2` in winhub-engine, then put it first in `runtimes.json` ([order](https://angeloresplandes.github.io/winhub-engine/releasing.html#order-with-winhub)) |
| 2 | **Direct3D 12 without D3DMetal** | Direct3D 12-only games ([The Witcher 3](compat/the-witcher-3.md), Resident Evil 4 Remake, Hogwarts Legacy) for people without the Game Porting Toolkit | engine work: DXMT's Direct3D 12 or vkd3d-proton |
| 3 | **Small catalog** | finding a title and knowing it works: 31 titles, 1 recipe | add titles and recipes as they are tested; a [compatibility report](compat/README.md) per game |
| 4 | **Empty rule database** | games that need a specific Direct3D, variable or argument to start | one rule per tested game in winhub-engine's `data/compatdb.json` |
| 5 | **Game videos** | cutscenes and intros in many games | GStreamer and H.264 in the engine |
| 6 | **16:9 display modes** | 1920×1080 and other modes that are not the Mac screen's own ratio | emulate modes in `winemac.drv` |
| 7 | **Interface only in Brazilian Portuguese** | people who do not read Portuguese | move the texts to String Catalogs and translate, starting with English |
| 8 | **Bottle export and import** | moving a bottle to another Mac, backups | archive the bottle folder with its `bottle.json` |
| 9 | **Program icons** | recognizing programs in the lists and shortcuts | extract the icon from the `.exe` |
| 10 | **Unnotarized releases** | a smooth first launch (macOS asks for "Abrir Mesmo Assim") | sign and notarize with a Developer ID (the release workflow already supports it) |
| 11 | **x86_64 only** | the future: Rosetta 2's general support ends in macOS 28 | follow upstream Wine's ARM64 work for macOS |
