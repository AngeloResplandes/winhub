**English** · [Português (Brasil)](../pt-BR/compat/lethal-company.md)

# Lethal Company (Steam, app 1966720): tests in WinHub

## Environment

| Item | Value |
|---|---|
| Date | 2026-10-12 and 2026-10-13 |
| Mac | Apple M5, macOS 27 |
| Engine | `winhub-wine-11.0-r2` (Wine 11.0 from CrossOver's sources, x86_64, Rosetta 2) |
| D3DMetal | Apple's Game Porting Toolkit 3.0, in the person's own folder |
| Bottle | APFS clone of the Steam bottle, Windows 10, msync on, Resoluções extras on, Metal HUD on, Direct3D "Automático" |
| Game | build 22825947, Unity 2022.3.62f2, Direct3D 11 (level 11.1), 64-bit |

Tested with [`scripts/game-test.swift`](README.md#testing-with-scriptsgame-testswift): the script started the game
through Steam, sent keys and clicks as macOS events and read the FPS from the Metal HUD.

## Results

| Backend | Starts? | Measurement | Notes |
|---|---|---|---|
| D3DMetal ("Automático") | **Yes, playable** | 60 FPS, GPU 6–14 ms per frame | Set-up screens, LAN host (local only), the ship, walking and mouse look. Unity sees "AMD Compatibility Mode", D3DMetal's adapter. |
| DXMT | **Yes** | — | Menus render and animate. |
| DXVK | **Yes** | — | Menus render and animate. |

**The microphone hung the game before WinHub declared it** (fixed on 2026-10-13, see
[Decisions](../decisions.md#2026-10-13-declare-the-microphone-in-winhubs-infoplist)): the first set-up screen stopped
reacting. With the fix, the game lists "Microfone (MacBook Air)" and goes on; macOS asks once whether WinHub may
use the microphone.

Still to check by hand: a blurred blue and orange shape close to the camera inside the ship (probably an object of
the ship out of focus).

## What WinHub should do

- Catalog: rating 4. No rule needed: "Automático" picks D3DMetal or DXMT, and both work.
