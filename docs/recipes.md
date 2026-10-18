**English** · [Português (Brasil)](pt-BR/recipes.md)

# Catalog recipes

A catalog title with a `recipe` installs with one click. Older WinHub copies ignore fields they do not know
(`decodeIfPresent`); a recipe that uses new fields should set `minAppVersion` so those copies hide Install.

Use only official download URLs and describe only steps you tested by hand. The catalog still has one recipe
(Steam); more titles go in after an APFS-clone test, not from this format alone.

## Steam (current catalog)

```json
"recipe": {
  "bottleName": "Steam",
  "windowsVersion": "win10",
  "installer": {
    "url": "https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe",
    "arguments": ["/S"]
  },
  "launch": { "windowsPath": "C:\\Program Files (x86)\\Steam\\steam.exe" }
}
```

`windowsVersion` defaults to `win10`. `dependencies` is a list of winetricks verbs, installed before the
payload. SHA-256 on the installer is optional when the vendor replaces the file at the same URL.

## Installer kinds

`installer.kind` is `exe`, `msi` or `zip`. When omitted, the URL's extension decides (`.msi`, `.zip`, otherwise
`.exe`).

A zip is not run as a Windows installer. WinHub unpacks it with `ditto -x -k` into the bottle's `drive_c`
under `installer.extractTo` (required for zip), e.g. `Program Files\\App`.

## Extra steps

`steps` run after the installer, in order:

| `kind` | Fields | What it does |
|---|---|---|
| `run` | `windowsPath`, `arguments` | runs that program in the bottle |
| `registry` | `key`, `value`, `data`, optional `type` (`REG_SZ` by default) | `reg add` |
| `copy` | `from`, `to` | copies a file. `to` is a `C:\…` path in the bottle. `from` is the same, or a file name next to the downloaded installer |

## Bottle settings and rules

`settings` (`graphics`, `msync`, `environment`, `dllOverrides`) apply **only when the bottle is created**. If
the bottle already exists, the user's Direct3D and variables stay; the installer, steps and rules still run.

`rules` are [compatdb](https://angeloresplandes.github.io/winhub-engine/compatdb.html) objects (`desc`, `match`,
`hacks`). They are merged into the bottle's `compat-rules.json` by `desc` and do not remove the
`winhub-program:` rules WinHub writes for per-program Direct3D.

## Opening programs

`launch` is the primary program (used to decide "installed" and the default Open). `launches` lists extra
programs; if `launch` is omitted, the first of `launches` is the primary. Optional `name` is the Open menu
label.

`minAppVersion` (for example `"0.2.60"`) hides Install on older WinHubs.

## Flow

Bottle by name (created with `settings` if new, otherwise reused) → winetricks `dependencies` → download →
exe/msi or zip extract → `steps` → write `rules` → check that `launch.windowsPath` exists → open.
