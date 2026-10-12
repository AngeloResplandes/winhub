**English** · [Português (Brasil)](pt-BR/graphics.md)

# Graphics (Direct3D)

Windows games draw with Direct3D. On the Mac, something has to translate Direct3D to Metal, and which translator
works best changes from game to game. WinHub lets you choose it per bottle and per program.

## The choices

| In the app | What it is | Direct3D | Needs |
|---|---|---|---|
| **Automático** | The engine picks the best one that runs here: D3DMetal, then DXMT, then Wine's | — | an engine that picks the Direct3D itself (winhub-engine revision 2) |
| **Wine** | Wine's own Direct3D (wined3d, over OpenGL) | up to feature level 9_3 on macOS | nothing; the default on older engines |
| **DXMT** | [DXMT](https://github.com/3Shain/dxmt): Direct3D straight over Metal | 10, 11 | the WinHub engine |
| **DXVK** | [DXVK](https://github.com/doitsujin/dxvk): Direct3D over Vulkan, through MoltenVK | 9 (revision 2), 10, 11 | revision 2: included, 64-bit games only; older engines: the DXVK-macOS component (2.8 MB, downloaded once) |
| **D3DMetal** | Apple's translator from the Game Porting Toolkit | 11, 12 | your own copy of the Game Porting Toolkit and revision 2 |

Wine's own Direct3D reaches only feature level 9_3 on macOS (OpenGL 4.1), so games that need Direct3D 11, such as
the ones made with Unity 6, need DXMT, DXVK or D3DMetal ([Hollow Knight](compat/hollow-knight.md)).

## Per bottle and per program

- **Gráficos (Direct3D)** in the bottle's settings applies to every program in it.
- **Gráficos por programa** gives one `.exe` its own choice. This is how a Steam game gets DXMT while Steam's own
  window stays with the bottle's choice.
- A catalog game with a tested recommendation shows **Usar … neste jogo (recomendado)**. Nothing is applied until
  you click it.

## D3DMetal

D3DMetal belongs to Apple and its license does not allow redistributing it, so WinHub never ships or downloads
it. If you have the Game Porting Toolkit:

1. Open **Ajustes → D3DMetal (opcional) → Escolher pasta…**.
2. Pick the toolkit's folder, its `redist` or its `redist/lib`; WinHub finds the right one.
3. **D3DMetal** appears in the bottles. With **Automático**, the engine prefers it for 64-bit games.

If the folder is on an external disk, D3DMetal only works while that disk is mounted.

## Fast synchronization and performance

- **Sincronização rápida (MSync)** (revision 2): cheaper synchronization in CPU-bound games. It takes effect the
  next time a program opens. If the bottle is running, close it first (**Encerrar**): Wine refuses programs whose
  setting differs from the `wineserver` already running.
- **Mostrar desempenho (FPS) nos jogos**: Metal's performance HUD (and DXVK's, when in use).

## How it works

- **Revision 2 (`backend-dispatch`).** WinHub only tells the engine what you chose (`WINHUB_GRAPHICS_BACKEND`) and
  writes per-program choices as rules in `<bottle>/compat-rules.json`. The engine's `winhubcompat` puts the chosen
  translator first in Wine's DLL search path for each process: nothing is copied into the bottle, the same way
  CrossOver works since version 25. Details: [winhubcompat](https://angeloresplandes.github.io/winhub-engine/compatdb.html).
- **Older engines (revision 1, official Wine).** WinHub copies the DLLs: DXVK or DXMT into the bottle's
  `system32`/`syswow64` with `n,b` overrides, or next to the program's `.exe` (64- or 32-bit by its PE header) with
  overrides in `HKCU\Software\Wine\AppDefaults\<exe>\DllOverrides`. Going back to Wine restores the engine's DLLs
  and removes the overrides; DLLs a game ships itself are never deleted.
- **Migration.** When a bottle set up for an older engine opens a program on revision 2, WinHub undoes the copies
  and overrides first and turns per-program choices into rules.
