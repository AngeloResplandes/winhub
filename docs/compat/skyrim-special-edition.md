**English** · [Português (Brasil)](../pt-BR/compat/skyrim-special-edition.md)

# The Elder Scrolls V: Skyrim Special Edition (Steam, app 489830): tests in WinHub

## Environment

| Item | Value |
|---|---|
| Date | 2026-10-15 |
| Mac | Apple M5, macOS 27.0.1 |
| Engine | `winhub-wine-11.0-r3` (Wine 11.0 from CrossOver's sources, x86_64, Rosetta 2) |
| D3DMetal | not installed |
| Bottle | APFS clone of the Steam bottle, Windows 10, msync off, Metal HUD on, Direct3D "Automático"; the clone's `Documents` is a copy, not the link to the Mac's `~/Documents` |
| Game | build 24914197 (Anniversary Upgrade not installed), Direct3D 11, 64-bit; the launcher picked the Ultra preset |

Tested with [`scripts/game-test.swift`](README.md#testing-with-scriptsgame-testswift) and by running
`SkyrimSE.exe` directly with `SteamAppId`/`SteamGameId` set, while the bottle's Steam was open.

## Results

| Backend | Starts? | Measurement | Notes |
|---|---|---|---|
| DXMT ("Automático") | **No** | — | The window opens and the game ends about 12 s later, before the title screen. The last log line is `err: Pure virtual function called`. Same result through Steam and run directly. |
| DXVK | **Yes, playable** | Title screen: 60 FPS, GPU about 6 ms per frame. New game, the opening cart ride (Ultra, 1470×956): 37 FPS, GPU about 21 ms per frame | Through Steam and run directly. Keyboard works in the menus. |
| Wine (wined3d) | not tried | — | wined3d only reaches feature level 9_3 on macOS; the game needs 11_0. |

The launcher (`SkyrimSELauncher.exe`) uses Direct3D 9 through Wine and works: hardware detection, Play.

## Rules by Steam app id do not reach the game

The first rule tried matched the Steam app (`steam_game_id` 489830) and it did not apply when Steam started the
game: the engine logged `SteamGameId (null)` for the launcher and for `SkyrimSE.exe`. Steam puts `SteamGameId` in the
game's Windows environment, and the engine reads it from the process's Unix environment, which Wine does not fill
from the Windows one. A rule that matches the executable's path (`path_suffix`) works through Steam. The same applies
to the Dark Souls Remastered rule. Fixing the engine to read the Windows environment is a separate task.

## What WinHub should do

- Catalog: rating 4, `steamGame.graphics` = `dxvk` (`installDir` `Skyrim Special Edition`, `SkyrimSE.exe`).
- Rule (winhub-engine's database): `graphics_backend` = `dxvk` for the path suffix
  `\Skyrim Special Edition\SkyrimSE.exe`. Without it, "Automático" picks DXMT, which closes the game.
