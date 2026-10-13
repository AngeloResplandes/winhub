# CLAUDE.md

O guia completo do projeto (regras, arquitetura, comandos, decisões e armadilhas) está em `AGENTS.md`:

@AGENTS.md

## Notas específicas do Claude Code

- Responda ao usuário em **português do Brasil**.
- Antes de afirmar que algo funciona, rode `swift build` e `swift test`. Para mudanças na interface,
  confira a tela (app empacotado com `./scripts/package-app.sh` e `open dist/WinHub.app`).
- Mudanças em código assíncrono ou de isolamento: lembre que o CI usa Swift 6.1 (Xcode 16.4) e é mais
  rígido que o Swift local; veja "Swift 6.1 compatibility" no `AGENTS.md`.
- Faça commit ou push só quando o usuário pedir. Nunca adicione `dist/`, `.build/` ou binários.
- Downloads (motores, componentes, instaladores) durante o desenvolvimento: informe arquivo, origem e
  tamanho e peça confirmação antes de baixar.
- Sala limpa: o CrossOver é estudado só pelo comportamento, documentado em `docs/reverse-engineering.md`.
  Nunca traga para o repositório código, dados, catálogos ou arquivos de produtos comerciais, nem código
  descompilado, endereços, nomes de símbolos internos ou logs da análise (veja a regra 1 do `AGENTS.md`).
- Documentação: inglês em `docs/` e na raiz, espelhada em português em `docs/pt-BR/` e nos `.pt-BR.md`;
  mude os dois idiomas juntos.
- `swift test` tem 116 testes.
