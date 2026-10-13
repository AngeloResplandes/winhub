**English** · [Português (Brasil)](../pt-BR/compat/README.md)

# Compatibility reports

Our own results, measured in WinHub. Each report says the Mac, the engine, the bottle and the game build, what
was tried and what worked, so it can be reproduced. Catalog ratings and per-game Direct3D recommendations come
from these reports.

| Game | Direct3D | Result | Best choice |
|---|---|---|---|
| [Hollow Knight](hollow-knight.md) | 11 (Unity 6) | runs, 60 FPS | DXMT for the game only |
| [The Witcher 3](the-witcher-3.md) | 12 only | installs, does not start | needs D3DMetal or Direct3D 12 in the engine |

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
  Back it up first.
- Start Steam with `open -a <WinHub.app you are testing> "winhub://open?…"`; a bare `open` may hand the link to
  another WinHub (for example `/Applications/WinHub.app`).
- The Metal HUD log has the frame number but redacts the frame time; `fps` divides frames by seconds. Only engines
  that present through the Metal HUD's layer report it (D3DMetal did; DXMT and DXVK sometimes show `inf`).
