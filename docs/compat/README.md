**English** · [Português (Brasil)](../pt-BR/compat/README.md)

# Compatibility reports

Our own results, measured in WinHub. Each report says the Mac, the engine, the bottle and the game build, what
was tried and what worked, so it can be reproduced. Catalog ratings and per-game Direct3D recommendations come
from these reports.

| Game | Direct3D | Result | Best choice |
|---|---|---|---|
| [BioShock Remastered](bioshock-remastered.md) | 11, 32-bit | starts with DXMT; gameplay not measured yet | Automático (DXMT) |
| [Dark Souls Remastered](dark-souls-remastered.md) | 11 | playable with D3DMetal and DXVK; DXMT freezes | DXVK (rule) or D3DMetal |
| [Hollow Knight](hollow-knight.md) | 11 (Unity 6) | playable; intro video black | Automático (DXMT on revision 3), or D3DMetal |
| [Lethal Company](lethal-company.md) | 11 (Unity 2022) | playable (needs the microphone fix) | Automático |
| [PEAK](peak.md) | 11 (Unity 6) | playable (needs the microphone fix) | Automático |
| [Persona 5 Royal](persona-5-royal.md) | 11 | installs, does not start (crash in the game, any Direct3D) | — |
| [Skyrim Special Edition](skyrim-special-edition.md) | 11 | playable with DXVK; DXMT closes it | DXVK (rule) |
| [The Witcher 3](the-witcher-3.md) | 12; 11 in the "classic" branch | current version does not start; "classic" (1.32) runs with DXMT | "classic" branch, Automático (DXMT) |

## Writing a report

1. Test on an APFS clone of the bottle, with one Steam open at a time ([why](../decisions.md#2026-10-11-never-run-two-steam-instances-of-one-bottle)).
2. Record: date, Mac and macOS, engine (`runtimes.json` id), bottle settings, game build and Direct3D version.
3. For each Direct3D tried: does it start, measurements (Metal HUD: `MTL_HUD_ENABLED=1`) and relevant log lines.
4. End with what WinHub should do (catalog rating, `steamGame.graphics`, a rule).
5. Write the page in English and its mirror in `docs/pt-BR/compat/`.

## Testing with `scripts/game-test.swift`

The script plays the part of the person at the Mac: it starts a game through the bottle's running Steam, picks its
Direct3D (the same per-program rule WinHub writes), finds and captures its window, sends keys and clicks as macOS
events (games get them like real input, unlike `SendInput` inside Wine), tells which Direct3D the process loaded,
and reads the average FPS from the Metal HUD's log.

```bash
swiftc -O scripts/game-test.swift -o .build/game-test
.build/game-test launch "<bottle folder>" 570940
.build/game-test wait "dark souls"          # window id, pid, size
.build/game-test focus <window id>; .build/game-test key e; .build/game-test key w 2
.build/game-test shot <window id> shot.png 900
.build/game-test fps <pid> 8                # needs MTL_HUD_ENABLED=1 and MTL_HUD_LOG_ENABLED=1 in the bottle
```

What we learned running it:

- The person must not use the Mac during a run: the game takes the screen and every key goes to the app in front.
- Look at a capture before each step that can lose progress. **Never end a game's process while a save may be
  written**; leave to the title screen through the game's own menu first, and use a new save slot, never the
  person's.
- A bottle clone does not isolate every save: `C:\users\<user>\Documents` links to the Mac's `~/Documents`, so games
  that save there (Dark Souls Remastered: `Documents\NBGI`) share the file with the original bottle and Steam Cloud.
  Back it up first, or replace the link in the clone with a folder of its own and copy the game folders into it
  (`cp -cR ~/Documents/"My Games" …`).
- Add the clone to WinHub as a bottle of its own (a new `id` and `name` in its `bottle.json`, the folder named
  `<name>-<first 8 characters of the id>` in `Bottles/`) and open its Steam through WinHub, which swaps the
  `steamwebhelper` wrapper in and gives Steam the engine's environment. Steam started only by `game-test launch`
  showed no window and took minutes to sign in.
- `focus` brings the game forward through System Events: macOS ignores `NSRunningApplication.activate()` from a
  tool in the background, and a click then lands on whatever window is in front (Steam's store, once).
- A game run directly (outside Steam) and then ended can stay "running" for Steam, which then ignores
  `-applaunch` until it restarts.
- Rules that match `steam_game_id` do not reach games started by Steam on engine revision 3 (the engine logs
  `SteamGameId (null)`); match the executable's path instead (`path_suffix`). See
  [Skyrim Special Edition](skyrim-special-edition.md#rules-by-steam-app-id-do-not-reach-the-game).
- Start Steam with `open -a <WinHub.app you are testing> "winhub://open?…"`; a bare `open` may hand the link to
  another WinHub (for example `/Applications/WinHub.app`).
- The Metal HUD log has the frame number but redacts the frame time; `fps` divides frames by seconds. Only engines
  that present through the Metal HUD's layer report it (D3DMetal did; DXMT and DXVK sometimes show `inf`).
