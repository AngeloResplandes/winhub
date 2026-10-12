[English](THIRD_PARTY_NOTICES.md) · **Português (Brasil)**

# Componentes de terceiros

O código do WinHub é MIT (veja `LICENSE`). O WinHub **não inclui** binários de terceiros no
repositório nem no app: os componentes abaixo são **baixados pelo próprio usuário**, a partir das
fontes oficiais, quando ele aciona o download no app. Cada download é conferido por SHA-256.

| Componente | Para que serve | Licença | Código-fonte |
|---|---|---|---|
| Wine (pacote oficial do WineHQ para macOS) | Roda programas do Windows | LGPL-2.1 | https://gitlab.winehq.org/wine/wine · pacotes: https://github.com/Gcenx/macOS_Wine_builds |
| Bibliotecas incluídas no pacote do Wine: FreeType, GnuTLS (+ nettle, gmp, libtasn1, libidn2, libunistring, p11-kit), SDL2, brotli, bzip2 | Fontes, HTTPS, controles | FreeType (FTL/GPL-2.0), GnuTLS (LGPL-2.1+), nettle (LGPL-3.0+/GPL-2.0+), gmp (LGPL-3.0+/GPL-2.0+), SDL2 (zlib), brotli (MIT), bzip2 (bzip2) | Ver os projetos de origem |
| MoltenVK (incluído no pacote do Wine) | Vulkan sobre Metal | Apache-2.0 | https://github.com/KhronosGroup/MoltenVK |
| Motor do WinHub ([winhub-engine](https://github.com/AngeloResplandes/winhub-engine)): overlay sobre o Wine oficial | Wine 11 compilado das fontes LGPL publicadas pela CodeWeavers para o CrossOver, o `winhubcompat` (escolhe o Direct3D), o DXMT v0.80 e o DXVK 1.10.3, compilados pelo CI do winhub-engine a partir das fontes | LGPL-2.1 (Wine, winhubcompat); MIT (DXMT, cJSON); zlib (DXVK); Apache-2.0 with LLVM Exceptions (partes do LLVM 15 no `winemetal.so`) | https://github.com/AngeloResplandes/winhub-engine · https://www.codeweavers.com/crossover/source · https://github.com/3Shain/dxmt |
| cabextract 1.11 (compilado pelo winhub-engine) | Usado por alguns verbos do winetricks (opcional) | GPL-3.0-or-later (libmspack embutida: LGPL-2.1) | https://www.cabextract.org.uk · o código exato vai em cada release do winhub-engine |
| DXVK-macOS 1.10.3 | Direct3D 10/11 sobre Vulkan nos motores antigos (opcional, por garrafa) | zlib | https://github.com/Gcenx/DXVK-macOS |
| winetricks 20260125 | Instala componentes do Windows (opcional) | LGPL-2.1 | https://github.com/Winetricks/winetricks |
| Steam (instalador `SteamSetup.exe`) | Receita do catálogo | Licença da Valve | Baixado do CDN oficial da Valve só quando o usuário clica em Instalar |

O app empacotado inclui um único programa do Windows feito pelo próprio WinHub: o wrapper do
`steamwebhelper.exe` (`Support/steamwebhelper-wrapper/`, MIT), que evita a janela preta da Steam. Ele é
compilado no empacotamento com o mingw-w64, que fica só na máquina de build; o `.exe` resultante leva
o código de inicialização do runtime do mingw-w64 (ZPL-2.1 / domínio público) e partes da libgcc (GPL-3.0
com a GCC Runtime Library Exception, que permite distribuí-lo sob a licença do WinHub). Código-fonte:
https://www.mingw-w64.org · https://gcc.gnu.org

Os componentes que o winetricks instala (como os redistribuíveis do Visual C++) vêm dos sites dos
respectivos fabricantes e seguem as licenças deles. O D3DMetal (Game Porting Toolkit da Apple) **não** é
distribuído pelo WinHub; ele só é usado se o próprio usuário apontar a cópia dele ao WinHub
(**Ajustes → D3DMetal**, por padrão `~/Library/Application Support/WinHub/D3DMetal`).

## Marcas

Windows e Direct3D são marcas da Microsoft. Mac, macOS e Metal são marcas da Apple. Steam é marca da Valve.
CrossOver é marca da CodeWeavers. Os nomes aparecem apenas para descrever compatibilidade e origem.
O WinHub é um projeto independente, sem relação com essas empresas.
