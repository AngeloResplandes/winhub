**English** · [Português (Brasil)](../pt-BR/compat/hollow-knight.md)

# Hollow Knight (Steam, app 367520): tests in WinHub

Our own results, measured in WinHub. The version tested is the Windows one, opened through Steam in a WinHub
bottle. The game also has a native Mac version.

## Environment

| Item | Value |
|---|---|
| Date | 2026-10-11 (revision 2: 2026-10-12) |
| Mac | Apple M5, macOS 27.0.1 |
| Engine | WineHQ wine-devel 11.18 (x86_64, Rosetta 2); later `winhub-wine-11.18-r1` and `winhub-wine-11.0-r2` |
| Bottle | Steam, Windows 10, `steamwebhelper` wrapper active |
| Game | build 22529139, Unity 6000.0.61f1, Direct3D 11 |
| Window | 1280×720, windowed (`-screen-fullscreen 0 -screen-width 1280 -screen-height 720`) |

## Results

| Backend | Starts? | Measurement | Notes |
|---|---|---|---|
| Wine (wined3d, OpenGL) | **No** | — | `d3d11: failed to create device and context (80004005)` → "Failed to initialize graphics". Wine's log: `wined3d_device_init Failed to create command stream`. The process hangs on Unity's error box. |
| DXVK-macOS 1.10.3 | **Yes** | Metal HUD: steady 60 FPS (vsync), GPU 1.0–2.1 ms per frame, 1.47 GB app memory | D3D11 "level 11.0". Reaches the language screen. DXVK's HUD shows about 120 presents/s (`IMMEDIATE` mode); Metal delivers 60 to the screen. |
| DXMT v0.80 (test engine) | **Yes** | Metal HUD: steady 60 FPS (vsync) in 6 samples over 12 s, GPU 0.64–1.22 ms per frame, Metal memory 430–530 MB, app 1.13–1.22 GB | D3D11 "level 11.1", renderer "Apple M5". The Steam overlay works. Harmless Unity warning: `Failed to create ID3D11Fence`. |
| DXMT, engine `winhub-wine-11.18-r1` (release), **game only** | **Yes** | Metal HUD: 60 FPS in 4 samples over 12 s, GPU 0.66–0.67 ms per frame, Metal memory 427 MB, app 1.14 GB | Final flow: WinHub installs the official Wine and the overlay, and `applyProgramGraphics(.dxmt)` puts DXMT in the game's folder, with `AppDefaults\hollow_knight.exe`. Steam's interface stays on Wine (its process does not load `winemetal`) and works normally. |
| DXMT, engine `winhub-wine-11.0-r2` (local build), **game only** | **Yes** | played by a person | Wine from CrossOver's LGPL sources; the engine picks DXMT for the game from the bottle's rule, nothing copied into the bottle. D3D11 "level 11.1". Steam opened with its saved login. The same harmless `ID3D11Fence` warning. |

Compared with DXVK, DXMT used about half the Metal memory (≈480 MB against 890 MB) and a little less GPU per
frame. Both are capped at 60 FPS by vsync, with plenty of headroom.

The "test engine" was the official wine-devel 11.18 with two changes:

1. `winemac.so` rebuilt with the patch `winhub-engine/patches/wine/0001-winemac.drv-Export-a-function-table-for-DXMT.patch`
   (revision 1). The patch exports `macdrv_functions` in the shape DXMT expects and creates a client surface when
   the window has no `client_view`.
2. DXMT v0.80 (`dxmt-v0.80-builtin.tar.gz`, SHA-256 `8f260e36…529d`) installed in builtin mode:
   - `d3d11`, `dxgi` and `d3d10core` in place of Wine's, in `lib/wine/{x86_64,i386}-windows`;
   - `winemetal.so` and `winemetal.dll` in the engine;
   - `winemetal.dll` also in the bottle's `system32`/`syswow64`.

DXMT's "builtin" build **does not work** when put in the game's folder: Wine sees the builtin mark and loads its
own version (wined3d) instead. Choosing the backend per game needs the build with `wine_builtin_dll=false`, or
swapping the DLLs in the engine. Revision 2 solves this differently: the engine puts DXMT's folder first in Wine's
DLL path for the game's process.

### Playing (DXMT)

Tested by a person playing, on revision 1 (2026-10-11) and revision 2 (2026-10-12): the game runs well, with
sound, and the controller (Xbox 360) is recognized. Keys injected with `SendInput` inside Wine do not reach
Unity 6 (Input System), so gameplay has no automated test.

### Fullscreen and resolution

- **Resolutions:** the game lists the modes Wine reports, and Wine's Mac driver only offers the macOS modes. On
  this screen (1470×956 points) that is 14 modes, from 960×600 to 2560×1664, all in the Mac screen's ratio.
  **There is no 1920×1080 nor any other 16:9 mode.**
- **Fullscreen:** starting the game in fullscreen works in both Unity modes, "fullscreen window" and exclusive
  (the window fills the screen, 1470×956). Switching from Options → Video also worked: Wine changes the Mac's
  mode (for example to 1280×800) and restores it on exit.
- In a first session, switching from the menu had no effect. The game had started **windowed** at an unusual size
  (1369×797). It could not be reproduced later, and no code changed between the two sessions.
- Wine's Mac driver only changes the display mode while the app is in front; otherwise it keeps the change for
  later. To investigate, reopen Steam with `WINEDEBUG=fixme-all,+display,warn+win` and look at the
  `macdrv_ChangeDisplaySettings` and "Setting display mode" (DXMT) lines.

## How to reproduce

- The game must be opened through Steam. Opened directly, it quits with "Application was not launched through
  Steam!", even with `steam_appid.txt`.
- In WinHub: in the Steam bottle, **Gráficos por programa → Escolher programa…** and pick `hollow_knight.exe`, then
  choose DXMT; or click **Usar DXMT neste jogo (recomendado)** on the game's catalog page.
- By hand, DXVK for the game only on an older engine (Steam's interface stays on wined3d):
  1. Copy `x64/d3d11.dll` and `x64/d3d10core.dll` from DXVK-macOS into the game's folder.
  2. Run `wine reg add 'HKCU\Software\Wine\AppDefaults\hollow_knight.exe\DllOverrides' /v d3d11 /d native,builtin /f`.
  3. Repeat step 2 with `d3d10core`.
  4. Open the game with `steam.exe -noverifyfiles -applaunch 367520`.
- Measuring: `MTL_HUD_ENABLED=1` (Metal HUD), `DXVK_HUD=fps,devinfo` and `WINEDEBUG=+fps` in Steam's environment
  (the game inherits it).

## Conclusions for WinHub

- **Catalog rating:** Bom (4). Graphics: DXMT for the game only (`steamGame.graphics` in `catalog.json`; the game's
  page offers "Usar DXMT neste jogo").
- wined3d does not work for Unity 6 games in D3D11 on macOS. Such games need DXVK, DXMT or D3DMetal.
- DXMT is the best result measured so far, on both revision 1 and revision 2.
- With per-program graphics, Steam never uses DXMT; only the game does, so the risk of Steam's window on DXMT
  goes away.
- The backend must be choosable **per game** inside the Steam bottle, because switching the whole bottle affects
  Steam's interface.
