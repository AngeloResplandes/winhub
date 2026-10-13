**English** · [Português (Brasil)](pt-BR/decisions.md)

# Decisions

A dated record of the decisions that shaped WinHub, newest first.

## 2026-10-13: Guard bottles against a second WinHub and a second Steam

The installed WinHub and a development build share the same bottles. With both open on the Steam bottle, Steam
uninstalled its games, as two Steams in two bottles had done on 2026-10-11. WinHub now writes
`<bottle>/session.json` (its pid and path) when it runs Wine in a bottle and checks, before every action that runs
Wine, that no other open WinHub and no other engine's `wineserver` is using it, and, when opening a program in a
bottle with Steam, that no other bottle with Steam is running. Otherwise it asks before ending them
("Encerrar e abrir"). Two WinHubs clicking at the same second on a stopped bottle are not covered.

## 2026-10-13: Declare the microphone in WinHub's Info.plist

macOS counts Wine processes started by WinHub as WinHub for privacy checks. With no
`NSMicrophoneUsageDescription`, it refuses the microphone **without asking** and ends the thread that asked, so games
with voice chat (Lethal Company, PEAK) hung while loading. `package-app.sh` now declares it (Portuguese in
`Info.plist`, English in `en.lproj/InfoPlist.strings`), and macOS asks the person the first time.

## 2026-10-12: Document the reverse engineering openly

The old rule forbade mentioning any reverse engineering. WinHub now documents what was studied in CrossOver and
how it is reproduced, like other clean-room reimplementations: behaviour only, never code or data. Decompiled
code, addresses, internal symbol names and analysis logs stay out of the repository. See
[Reverse engineering](reverse-engineering.md) and [CONTRIBUTING](https://github.com/AngeloResplandes/winhub/blob/main/CONTRIBUTING.md).

## 2026-10-12: Download the engine's rule database only when signed

`CompatDatabaseSync` downloads winhub-engine's `data/compatdb.json` and its Ed25519 signature, and installs it only
when the signature matches the key built into the app and the database is newer than the installed one. A rule
can change a program's environment and arguments, so an unsigned or replayed file is never used. Changing the
key needs a new app version. See [SECURITY](https://github.com/AngeloResplandes/winhub/blob/main/SECURITY.md).

## 2026-10-11: Let the engine pick the Direct3D

With engines that declare `backend-dispatch` (winhub-engine revision 2), WinHub no longer copies DLLs into
bottles: it sets `WINHUB_GRAPHICS_BACKEND` and writes per-program choices as rules, and the engine puts the chosen
translator first in Wine's DLL path, the way CrossOver does since version 25. Bottles from the copying era are
migrated before a program opens. The copying path stays for older engines.

## 2026-10-11: D3DMetal only from the user

Apple's license does not allow redistributing D3DMetal. WinHub uses it only when the user points
**Ajustes → D3DMetal** to their own Game Porting Toolkit; it never ships or downloads it.

## 2026-10-11: Never run two Steam instances of one bottle

While testing an engine, a test Steam was still open in a copy of a bottle when the original bottle's Steam was
opened. That Steam marked two games as "files missing" and uninstalled them. Tests now run on an APFS clone of a
bottle, with only one Steam open at a time: every Wine process of the clone is closed before the real bottle
opens, and the other way around.

## 2026-10-11: A program can have its own Direct3D

Switching a whole Steam bottle to DXVK or DXMT also changes Steam's own window. A per-program choice gives only
the game's `.exe` its Direct3D: DLLs next to the `.exe` with `AppDefaults` overrides on older engines, and a rule
on revision 2. DLLs a game ships itself are never replaced.

## 2026-10-11: Replace steamwebhelper with a wrapper

On Wine 11 for macOS, Steam's window is black: its interface is a Chromium that draws each window from another
process, and Wine's macOS driver does not show it. A small Windows program of WinHub's
(`Support/steamwebhelper-wrapper`) takes the place of `steamwebhelper.exe` and starts the original with
`--in-process-gpu`. Steam is opened with `-noverifyfiles` only when the wrapper is installed; the first session
after installing Steam stays black because Steam downloads its client and helper in it. Steam's `-cef-*` options,
`renderer=vulkan` and DXVK did not help.

## 2026-10-11: Official WineHQ builds instead of WineCX 24

The open WineCX 24 build breaks Steam on macOS 27: the system returns an empty TCP connection list to ordinary
apps, and Steam rejects its helper. Wine 9.17 and newer build that table in `wineserver`. WinHub moved to the
official WineHQ builds; engine revision 2 (Wine 11.0 from CrossOver 26 sources) also has the fix.

## 2026-10-11: Shortcuts delegate to WinHub

Programs started from inside a shortcut `.app`'s own process hang (Steam stops at "Verifying…"). Shortcuts only
open a `winhub://` link, and WinHub starts the program after checking that the `.lnk` is inside the bottle.

## 2026-10-11: Clean up processes left by a dead wineserver

When `wineserver` dies without ending its clients, `winedevice.exe` stays alive forever, and the next server
reuses the same folder without reaching it. `WineOrphanReaper` ends those processes when nobody holds the
server folder's `lock` (not the socket, which a killed server leaves behind).
