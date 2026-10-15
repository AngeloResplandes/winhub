**English** · [Português (Brasil)](../pt-BR/compat/bioshock-remastered.md)

# BioShock Remastered (Steam, app 409710): tests in WinHub

## Environment

| Item | Value |
|---|---|
| Date | 2026-10-15 |
| Mac | Apple M5, macOS 27.0.1 |
| Engine | `winhub-wine-11.0-r3` (Wine 11.0 from CrossOver's sources, x86_64, Rosetta 2) |
| D3DMetal | not installed |
| Bottle | APFS clone of the Steam bottle, Windows 10, msync off, Metal HUD on, Direct3D "Automático" |
| Game | build 8552765, Direct3D 11, **32-bit** (`Build\Final\BioshockHD.exe`) |

## Results

| Backend | Starts? | Measurement | Notes |
|---|---|---|---|
| DXMT ("Automático"), 32-bit | **Yes** | Logos: 60 FPS, GPU under 1 ms. 2K's terms screen: about 165 FPS (no cap), GPU about 4 ms | Renders at 2560×1664 in a 1470×956 window. The intro logos play; Esc skips them. |
| DXVK | not available | — | Revision 3 does not offer DXVK to 32-bit games (it needs `VK_EXT_map_memory_placed`, which MoltenVK lacks). |

The test stopped at 2K's online terms ("I agree to all"), which only the person can accept. Gameplay is not
measured yet.

## What WinHub should do

- Catalog: not added yet; it waits for a gameplay test after the terms.
- No rule: "Automático" already picks DXMT, which runs it.
