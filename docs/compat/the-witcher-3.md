**English** · [Português (Brasil)](../pt-BR/compat/the-witcher-3.md)

# The Witcher 3: Wild Hunt (Steam, app 292030): tests in WinHub

Our own results, measured in WinHub.

## Environment

| Item | Value |
|---|---|
| Date | 2026-10-11 |
| Mac | Apple M5, macOS 27.0.1 |
| Engine | `winhub-wine-11.18-r1` (WineHQ 11.18 + winhub-engine overlay) |
| Bottle | Steam, Windows 10, bottle graphics: Wine |
| Game | "The Witcher 3: Wild Hunt — Remastered", build 25773555 (74 GB) |

## Result: installs, but does not start

- **The current version is DirectX 12 only.** `launcher-configuration.json` lists only `bin\x64_dx12\witcher3.exe`,
  and the `bin\x64` (DX11) folder does not exist. DX11 only exists in Steam's "classic" beta branch (1.32).
- **CD Projekt's launcher (`REDlauncher`, Qt WebEngine):** crashes on start with `Unhandled exception 0x80000003`
  (breakpoint) and falls into Wine's debugger. This resembles Steam's problems with its own Chromium.
- **Game opened directly (`witcher3.exe` DX12, Steam open):** shows "GPU does not meet minimal requirements.
  Support for DirectX 12 is required." Wine's D3D12 (vkd3d over MoltenVK) does not offer what the game needs, and
  DXMT v0.80 has no D3D12.

## Engine revision 2

Not retested yet: the game was uninstalled on 2026-10-11 ([why](../decisions.md#2026-10-11-never-run-two-steam-instances-of-one-bottle)).
On revision 2, the expected path is **D3DMetal** (Direct3D 12) for people who have the Game Porting Toolkit; without
it, the result should stay the same.

## The same applies to

Resident Evil 4 Remake and Hogwarts Legacy are also D3D12 only (not tested for that reason).

## Paths

1. Steam's "classic" beta branch (1.32, DX11), to test the game with DXMT or DXVK.
2. D3D12 in the engine: DXMT works on an experimental D3D12 after v0.80 (LGPL from then on); or D3DMetal from the
   user on revision 2.
3. The crashing launcher can be skipped with the `--launcher-skip` launch option in Steam, once the game itself
   works.
