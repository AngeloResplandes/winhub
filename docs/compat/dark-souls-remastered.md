**English** · [Português (Brasil)](../pt-BR/compat/dark-souls-remastered.md)

# Dark Souls Remastered (Steam, app 570940): tests in WinHub

## Environment

| Item | Value |
|---|---|
| Date | 2026-10-12 and 2026-10-13 |
| Mac | Apple M5, macOS 27 |
| Engine | `winhub-wine-11.0-r2` (Wine 11.0 from CrossOver's sources, x86_64, Rosetta 2) |
| D3DMetal | Apple's Game Porting Toolkit 3.0, in the person's own folder |
| Bottle | APFS clone of the Steam bottle, Windows 10, msync on, Resoluções extras on, Metal HUD on, Direct3D "Automático" |
| Game | build 10943698 (app 1.03.1), Direct3D 11, 64-bit |

Tested with [`scripts/game-test.swift`](README.md#testing-with-scriptsgame-testswift): the script started the game
through Steam, sent keys and clicks as macOS events and read the FPS from the Metal HUD.

## Results

| Backend | Starts? | Measurement | Notes |
|---|---|---|---|
| D3DMetal ("Automático") | **Yes, playable** | 60 FPS (the game's cap), GPU 8–13 ms per frame in the Undead Asylum | Title, menus, character creation, the pre-rendered intro video, in-engine cut-scenes and walking in the Asylum. Saving and going back to the title works. |
| DXVK | **Yes, playable** | 60 FPS (Metal HUD log), GPU about 14 ms per frame in the Asylum | Same scenes. |
| DXMT | **No** | — | Freezes during the title screen's fade-in: no new frames, the process keeps about 110% CPU. |
| Wine (wined3d) | **No** | — | The process starts and sits idle without a window (wined3d only reaches feature level 9_3 on macOS). |

Input: the keyboard (E confirms, Q goes back, arrows, Home/End switch menu tabs) and the mouse in menus work.
Alt+F4 is ignored; quit through **Sistema → Sair do jogo**. Text entry (character name) works.

The save file is in `Documents\NBGI\DARK SOULS REMASTERED`, which in a WinHub bottle is the Mac's `~/Documents`:
every bottle of the same Mac user, and Steam Cloud, share it. Each character slot has an MD5 checksum, which is how we
checked the file after the tests.

## What WinHub should do

- Catalog: rating 5, `steamGame.graphics` = `dxvk`.
- Rule (winhub-engine's database): `graphics_backend` = `dxvk` for Steam app 570940. Without D3DMetal, "Automático"
  would pick DXMT, which freezes. D3DMetal also runs it well, at a lower GPU time; the person can still pick it.
