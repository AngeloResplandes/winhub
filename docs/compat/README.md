**English** · [Português (Brasil)](../pt-BR/compat/README.md)

# Compatibility reports

Our own results, measured in WinHub. Each report says the Mac, the engine, the bottle and the game build, what
was tried and what worked, so it can be reproduced. Catalog ratings and per-game Direct3D recommendations come
from these reports.

| Game | Direct3D | Result | Best choice |
|---|---|---|---|
| [Hollow Knight](hollow-knight.md) | 11 (Unity 6) | runs, 60 FPS | DXMT for the game only |
| [The Witcher 3](the-witcher-3.md) | 12 only | installs, does not start | needs D3DMetal or Direct3D 12 in the engine |

## Writing a report

1. Test on an APFS clone of the bottle, with one Steam open at a time ([why](../decisions.md#2026-10-11-never-run-two-steam-instances-of-one-bottle)).
2. Record: date, Mac and macOS, engine (`runtimes.json` id), bottle settings, game build and Direct3D version.
3. For each Direct3D tried: does it start, measurements (Metal HUD: `MTL_HUD_ENABLED=1`) and relevant log lines.
4. End with what WinHub should do (catalog rating, `steamGame.graphics`, a rule).
5. Write the page in English and its mirror in `docs/pt-BR/compat/`.
