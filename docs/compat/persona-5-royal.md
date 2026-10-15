**English** · [Português (Brasil)](../pt-BR/compat/persona-5-royal.md)

# Persona 5 Royal (Steam, app 1687950): tests in WinHub

## Environment

| Item | Value |
|---|---|
| Date | 2026-10-15 |
| Mac | Apple M5, macOS 27.0.1 |
| Engine | `winhub-wine-11.0-r3` (Wine 11.0 from CrossOver's sources, x86_64, Rosetta 2) |
| D3DMetal | not installed |
| Bottle | APFS clone of the Steam bottle, Windows 10, msync off, Metal HUD on, Direct3D "Automático" |
| Game | build 15515071, Direct3D 11, 64-bit |

## Result: installs, but does not start

The game ends a moment after it starts, before any window has content:
`Unhandled page fault on read access to 00000000000008FF at address 00000001401D7EB9`. The address is inside
`P5R.exe` and is the same in every try:

| Try | Result |
|---|---|
| Through Steam, "Automático" (DXMT) | crash; Wine's debugger opens |
| Run directly, DXMT | same crash, right after `d3d11.dll` loads |
| Run directly, DXVK | same crash, before `d3d11.dll` loads |
| DXMT, Steam overlay off (`gameoverlayrenderer64=d`) | same crash |
| DXMT, without `ROSETTA_ADVERTISE_AVX` | same crash |

The crash comes before the game draws anything and does not depend on the Direct3D, so the cause is elsewhere (an
API Wine answers differently, or what the game reads of the system). Not tried: D3DMetal, other Windows versions,
`WINEDEBUG=+seh,+relay` around the fault.

## What WinHub should do

- Catalog: rating 2 ("Instala, mas não abre"), no `steamGame.graphics`.
- No rule.
