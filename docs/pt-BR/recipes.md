[English](../recipes.md) · **Português (Brasil)**

# Receitas do catálogo

Um título do catálogo com `recipe` instala com um clique. Cópias antigas do WinHub ignoram os campos que não
conhecem (`decodeIfPresent`); uma receita que usa campos novos deve pôr `minAppVersion` para essas cópias
esconderem o Instalar.

Use só URLs oficiais de download e descreva só passos testados à mão. O catálogo ainda tem uma receita (Steam);
mais títulos entram depois de um teste em clone APFS, não só por causa deste formato.

## Steam (catálogo atual)

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

`windowsVersion` vale `win10` se faltar. `dependencies` é uma lista de verbos do winetricks, instalados antes
do pacote. O SHA-256 do instalador é opcional quando o fabricante troca o arquivo no mesmo endereço.

## Tipos de instalador

`installer.kind` é `exe`, `msi` ou `zip`. Se faltar, a extensão da URL decide (`.msi`, `.zip`, senão `.exe`).

Um zip não roda como instalador do Windows. O WinHub o descompacta com `ditto -x -k` no `drive_c` da garrafa,
em `installer.extractTo` (obrigatório no zip), por exemplo `Program Files\\App`.

## Passos extras

`steps` rodam depois do instalador, na ordem:

| `kind` | Campos | O que faz |
|---|---|---|
| `run` | `windowsPath`, `arguments` | roda esse programa na garrafa |
| `registry` | `key`, `value`, `data`, `type` opcional (`REG_SZ` por padrão) | `reg add` |
| `copy` | `from`, `to` | copia um arquivo. `to` é um caminho `C:\…` na garrafa. `from` é o mesmo, ou um nome de arquivo ao lado do instalador baixado |

## Ajustes da garrafa e regras

`settings` (`graphics`, `msync`, `environment`, `dllOverrides`) valem **só quando a garrafa é criada**. Se ela
já existe, o Direct3D e as variáveis do usuário ficam; o instalador, os passos e as regras rodam mesmo assim.

`rules` são objetos do [compatdb](https://angeloresplandes.github.io/winhub-engine/pt-BR/compatdb.html) (`desc`,
`match`, `hacks`). Entram no `compat-rules.json` da garrafa pelo `desc` e não apagam as regras `winhub-program:`
que o WinHub grava para o Direct3D por programa.

## Abrir programas

`launch` é o programa principal (para "instalado" e o Abrir padrão). `launches` lista programas extras; se
`launch` faltar, o primeiro de `launches` é o principal. O `name` opcional é o rótulo no menu Abrir.

`minAppVersion` (por exemplo `"0.2.60"`) esconde o Instalar em WinHubs mais antigos.

## Fluxo

Garrafa pelo nome (criada com os `settings` se for nova, senão reaproveitada) → `dependencies` do winetricks →
download → exe/msi ou extração do zip → `steps` → grava `rules` → confere que `launch.windowsPath` existe → abre.
