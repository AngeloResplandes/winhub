**English** · [Português (Brasil)](../pt-BR/compat/peak.md)

# PEAK (Steam, app 3527290): tests in WinHub

## Environment

| Item | Value |
|---|---|
| Date | 2026-10-12 and 2026-10-13 |
| Mac | Apple M5, macOS 27 |
| Engine | `winhub-wine-11.0-r2` (Wine 11.0 from CrossOver's sources, x86_64, Rosetta 2) |
| D3DMetal | Apple's Game Porting Toolkit 3.0, in the person's own folder |
| Bottle | APFS clone of the Steam bottle, Windows 10, msync on, Resoluções extras on, Metal HUD on, Direct3D "Automático" |
| Game | build 25739797, Unity 6000.3.15f1, Direct3D 11, 64-bit |

Tested with [`scripts/game-test.swift`](README.md#testing-with-scriptsgame-testswift): the script started the game
through Steam, sent keys and clicks as macOS events and read the FPS from the Metal HUD.

## Results

| Backend | Starts? | Measurement | Notes |
|---|---|---|---|
| D3DMetal ("Automático") | **Yes, playable** | main menu (a 3D scene) 116–127 FPS; airport lobby 73–82 FPS, GPU 8–12 ms per frame | "Jogar offline", the airport and walking. The microphone list shows the Mac's microphone. |
| DXMT | **Yes** | — | The main menu renders and animates. |
| DXVK | **Yes** | — | The main menu renders and animates. |

**The microphone hung the game before WinHub declared it**: loading "Jogar offline" stopped after the voice recorder
asked for the microphone (Unity's log ends at `MicWrapper`; macOS logged that it refused the request because the app
had no usage description). Fixed on 2026-10-13, see
[Decisions](../decisions.md#2026-10-13-declare-the-microphone-in-winhubs-infoplist).

## What WinHub should do

- Catalog: rating 4. No rule needed.
