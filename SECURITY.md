**English** · [Português (Brasil)](SECURITY.pt-BR.md)

# Security policy

## What WinHub protects, and what it does not

Windows programs run through Wine with **the same access to your files as any app you open**. WinHub does not
sandbox them; only install programs you trust. What WinHub does protect is what it downloads and runs on your
behalf.

| Area | Protection |
|---|---|
| Engine and components | every download from an official source, checked by SHA-256 against the manifests in `Sources/WinHub/Resources/` before it is unpacked; an engine is only used once its marker is written, after everything else |
| Engine overlays | the overlay's SHA-256 is checked too; WinHub only removes the folders listed in `overlay.replace` and refuses paths that leave the Wine folder |
| Catalog and manifests | downloaded from `main` over HTTPS and kept only if this app version can decode them; a catalog the user imported is never replaced |
| Per-game rules | winhub-engine's database is installed only with a valid Ed25519 signature (key built into the app) and a newer `timestamp`, so an old file cannot be replayed |
| App updates | the SHA-256 GitHub computes for the release asset, the bundle identifier, the version and `codesign --verify`; with a Developer ID, the same Team ID |
| `winhub://` links | a shortcut can only open a `.lnk` inside its own bottle's `drive_c` |
| Wine processes | a clean environment: only `HOME`, `USER`, `LOGNAME`, `LANG`, `LC_ALL`, `TMPDIR` and `SHELL` are inherited |

## Reporting a vulnerability

Please do not open a public issue with a working exploit or a malicious file. Open an issue that only says you
have a security report and asks for a private channel, or use GitHub's private vulnerability reporting on this
repository if it is enabled. Include the WinHub version, the macOS version and Mac model, the affected area and
the steps to reproduce.

The engine's trust chain (build inputs, release checksums and the signing key) is described in
[winhub-engine's SECURITY](https://github.com/AngeloResplandes/winhub-engine/blob/main/SECURITY.md).
