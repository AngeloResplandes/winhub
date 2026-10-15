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

## Result (current version): installs, but does not start

- **The current version is DirectX 12 only.** `launcher-configuration.json` lists only `bin\x64_dx12\witcher3.exe`,
  and the `bin\x64` (DX11) folder does not exist. DX11 only exists in Steam's "classic" beta branch (1.32).
- **CD Projekt's launcher (`REDlauncher`, Qt WebEngine):** crashes on start with `Unhandled exception 0x80000003`
  (breakpoint) and falls into Wine's debugger. This resembles Steam's problems with its own Chromium.
- **Game opened directly (`witcher3.exe` DX12, Steam open):** shows "GPU does not meet minimal requirements.
  Support for DirectX 12 is required." Wine's D3D12 (vkd3d over MoltenVK) does not offer what the game needs, and
  DXMT v0.80 has no D3D12.

## 2026-10-15: the "classic" branch (1.32, DX11) on engine revision 3

Same Mac (macOS 27.0.1), engine `winhub-wine-11.0-r3`, no D3DMetal, an APFS clone of the Steam bottle (Windows 10,
msync off, Metal HUD on, Direct3D "Automático"). Steam's beta branch `classic`, build 3280809, with both expansions.
`bin\x64\witcher3.exe` run directly with `SteamAppId`/`SteamGameId` while the bottle's Steam was open.

| Backend | Result |
|---|---|
| DXMT ("Automático") | **Playable start.** Main menu in Portuguese at 60 FPS (GPU under 1 ms); new game, difficulty and tutorial menus; the prologue's in-engine cut-scenes at 58–60 FPS, GPU 12–17 ms per frame, at the settings the game picked (1470×956). |
| DXVK | not tried (DXMT already runs it). |

Not checked: the current (DX12) version with D3DMetal, combat and open-world areas, the REDprelauncher that Steam
starts for this branch (the game was opened directly).

## The same applies to

Resident Evil 4 Remake and Hogwarts Legacy are also D3D12 only (not tested for that reason).

## Paths

1. Steam's "classic" beta branch (1.32, DX11): runs with DXMT (2026-10-15, above).
2. D3D12 in the engine: DXMT works on an experimental D3D12 after v0.80 (LGPL from then on); or D3DMetal from the
   user on revision 2.
3. The crashing launcher can be skipped with the `--launcher-skip` launch option in Steam, once the game itself
   works.
