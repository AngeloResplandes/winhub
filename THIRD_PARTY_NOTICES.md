# Componentes de terceiros

O código do WinHub é MIT (veja `LICENSE`). O WinHub **não inclui** binários de terceiros no
repositório nem no app: os componentes abaixo são **baixados pelo próprio usuário**, a partir das
fontes oficiais, quando ele aciona o download no app. Cada download é conferido por SHA-256.

| Componente | Para que serve | Licença | Código-fonte |
|---|---|---|---|
| Wine (pacote oficial do WineHQ para macOS) | Roda programas do Windows | LGPL-2.1 | https://gitlab.winehq.org/wine/wine · pacotes: https://github.com/Gcenx/macOS_Wine_builds |
| Bibliotecas incluídas no pacote do Wine: FreeType, GnuTLS (+ nettle, gmp, libtasn1, libidn2, libunistring, p11-kit), SDL2, brotli, bzip2 | Fontes, HTTPS, controles | FreeType (FTL/GPL-2.0), GnuTLS (LGPL-2.1+), nettle (LGPL-3.0+/GPL-2.0+), gmp (LGPL-3.0+/GPL-2.0+), SDL2 (zlib), brotli (MIT), bzip2 (bzip2) | Ver os projetos de origem |
| MoltenVK (incluído no pacote do Wine) | Vulkan sobre Metal | Apache-2.0 | https://github.com/KhronosGroup/MoltenVK |
| DXVK-macOS 1.10.3 | Direct3D 10/11 sobre Vulkan (opcional, por garrafa) | zlib | https://github.com/Gcenx/DXVK-macOS |
| winetricks 20260125 | Instala componentes do Windows (opcional) | LGPL-2.1 | https://github.com/Winetricks/winetricks |
| Steam (instalador `SteamSetup.exe`) | Receita do catálogo | Licença da Valve | Baixado do CDN oficial da Valve só quando o usuário clica em Instalar |

Os componentes que o winetricks instala (como os redistribuíveis do Visual C++) vêm dos sites dos
respectivos fabricantes e seguem as licenças deles. O D3DMetal (Game Porting Toolkit da Apple) **não** é
usado nem distribuído pelo WinHub.

## Marcas

Windows é marca da Microsoft. Mac e macOS são marcas da Apple. Steam é marca da Valve.
CrossOver é marca da CodeWeavers. Os nomes aparecem apenas para descrever compatibilidade.
O WinHub é um projeto independente, sem relação com essas empresas.
