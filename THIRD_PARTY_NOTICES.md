**English** · [Português (Brasil)](THIRD_PARTY_NOTICES.pt-BR.md)

# Third-party components

WinHub's code is MIT (see `LICENSE`). WinHub **includes no** third-party binaries in the repository or in the app:
the components below are **downloaded by the user**, from the official sources, when they start the download in
the app. Every download is checked by SHA-256.

| Component | What it is for | License | Source |
|---|---|---|---|
| Wine (official WineHQ build for macOS) | Runs Windows programs | LGPL-2.1 | https://gitlab.winehq.org/wine/wine · builds: https://github.com/Gcenx/macOS_Wine_builds |
| Libraries in the Wine build: FreeType, GnuTLS (+ nettle, gmp, libtasn1, libidn2, libunistring, p11-kit), SDL2, brotli, bzip2 | Fonts, HTTPS, controllers | FreeType (FTL/GPL-2.0), GnuTLS (LGPL-2.1+), nettle (LGPL-3.0+/GPL-2.0+), gmp (LGPL-3.0+/GPL-2.0+), SDL2 (zlib), brotli (MIT), bzip2 (bzip2) | See the upstream projects |
| MoltenVK (in the Wine build) | Vulkan over Metal | Apache-2.0 | https://github.com/KhronosGroup/MoltenVK |
| WinHub engine ([winhub-engine](https://github.com/AngeloResplandes/winhub-engine)): overlay over the official Wine | Wine 11 built from the LGPL sources CodeWeavers publishes for CrossOver, `winhubcompat` (picks the Direct3D), DXMT v0.80 and DXVK 1.10.3, built by winhub-engine's CI from source | LGPL-2.1 (Wine, winhubcompat); MIT (DXMT, cJSON); zlib (DXVK); Apache-2.0 with LLVM Exceptions (parts of LLVM 15 in `winemetal.so`) | https://github.com/AngeloResplandes/winhub-engine · https://www.codeweavers.com/crossover/source · https://github.com/3Shain/dxmt |
| cabextract 1.11 (built by winhub-engine) | Used by some winetricks verbs (optional) | GPL-3.0-or-later (bundled libmspack: LGPL-2.1) | https://www.cabextract.org.uk · the exact source ships with every winhub-engine release |
| DXVK-macOS 1.10.3 | Direct3D 10/11 over Vulkan on older engines (optional, per bottle) | zlib | https://github.com/Gcenx/DXVK-macOS |
| winetricks 20260125 | Installs Windows components (optional) | LGPL-2.1 | https://github.com/Winetricks/winetricks |
| Steam (`SteamSetup.exe` installer) | Catalog recipe | Valve's license | Downloaded from Valve's official CDN only when the user clicks Install |

The packaged app includes a single Windows program, made by WinHub itself: the `steamwebhelper.exe` wrapper
(`Support/steamwebhelper-wrapper/`, MIT), which avoids Steam's black window. It is built at packaging time with
mingw-w64, which stays on the build machine; the resulting `.exe` carries the mingw-w64 runtime start-up code
(ZPL-2.1 / public domain) and parts of libgcc (GPL-3.0 with the GCC Runtime Library Exception, which allows
distributing it under WinHub's license). Source: https://www.mingw-w64.org · https://gcc.gnu.org

The components winetricks installs (such as the Visual C++ redistributables) come from their vendors' sites and
follow their licenses. D3DMetal (Apple's Game Porting Toolkit) is **not** distributed by WinHub; it is only used
if the user points WinHub to their own copy (**Ajustes → D3DMetal**, by default
`~/Library/Application Support/WinHub/D3DMetal`).

## Trademarks

Windows and Direct3D are trademarks of Microsoft. Mac, macOS and Metal are trademarks of Apple. Steam is a
trademark of Valve. CrossOver is a trademark of CodeWeavers. The names are used only to describe compatibility and
origin. WinHub is an independent project, not affiliated with these companies.
