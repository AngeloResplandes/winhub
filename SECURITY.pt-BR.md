[English](SECURITY.md) · **Português (Brasil)**

# Política de segurança

## O que o WinHub protege, e o que não protege

Programas do Windows rodam pelo Wine com **o mesmo acesso aos seus arquivos que qualquer app que você abre**. O
WinHub não os isola; instale só programas em que você confia. O que o WinHub protege é o que ele baixa e roda por
você.

| Área | Proteção |
|---|---|
| Motor e componentes | todo download de fonte oficial, conferido por SHA-256 com os manifestos em `Sources/WinHub/Resources/` antes de ser desempacotado; um motor só é usado depois que o marcador dele é gravado, por último |
| Overlays do motor | o SHA-256 do overlay também é conferido; o WinHub só remove as pastas listadas em `overlay.replace` e recusa caminhos que saiam da pasta do Wine |
| Catálogo e manifestos | baixados da `main` por HTTPS e guardados só se esta versão do app conseguir decodificá-los; um catálogo importado pelo usuário nunca é trocado |
| Regras por jogo | o banco do winhub-engine só é instalado com assinatura Ed25519 válida (chave embutida no app) e `timestamp` mais novo, para um arquivo antigo não poder ser reenviado |
| Atualizações do app | o SHA-256 que o GitHub calcula para o arquivo da versão, o identificador, a versão e o `codesign --verify`; com Developer ID, o mesmo Team ID |
| Links `winhub://` | um atalho só abre um `.lnk` dentro do `drive_c` da própria garrafa |
| Processos do Wine | ambiente limpo: só `HOME`, `USER`, `LOGNAME`, `LANG`, `LC_ALL`, `TMPDIR` e `SHELL` são herdados |

## Como reportar uma vulnerabilidade

Não abra uma issue pública com um exploit funcional ou um arquivo malicioso. Abra uma issue dizendo só que você tem
um relato de segurança e pedindo um canal privado, ou use o relato privado de vulnerabilidades do GitHub neste
repositório, se estiver ligado. Inclua a versão do WinHub, a versão do macOS e o modelo do Mac, a área afetada e os
passos para reproduzir.

A cadeia de confiança do motor (entradas do build, checksums das versões e a chave de assinatura) está descrita no
[SECURITY do winhub-engine](https://github.com/AngeloResplandes/winhub-engine/blob/main/SECURITY.pt-BR.md).
