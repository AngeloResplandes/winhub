[English](CONTRIBUTING.md) · **Português (Brasil)**

# Como contribuir

Obrigado pelo interesse no WinHub.

## Regras de "sala limpa" (obrigatórias)

- **Estudamos o CrossOver só pelo comportamento:** o que ele faz, como o pacote é organizado, que arquivos e
  configurações usa. Os achados vão para [`docs/reverse-engineering.md`](docs/reverse-engineering.md) e o espelho em
  [`docs/pt-BR/`](docs/pt-BR/reverse-engineering.md), descritos como comportamento.
- **Nunca copie** código, scripts, textos, traduções, ícones ou dados do CrossOver. Isso inclui o catálogo
  (`crossover.tie`), o banco de compatibilidade (`compatdb-*.dat`, cifrado; nunca o decifre) e a interface.
- **O código que a CodeWeavers publica sob a LGPL** (a árvore do Wine do CrossOver) é usado pelo winhub-engine, com
  atribuição.
- **Não commite** código descompilado, endereços, nomes de símbolos internos nem logs da análise. Nomes que aparecem
  em material público (variáveis lidas pelo código LGPL, nomes de arquivos do pacote) podem ser citados.
- **Nunca redistribua o D3DMetal da Apple.**
- **Nada de binários de terceiros no repositório.** Componentes são baixados em tempo de execução, da fonte
  oficial, com o SHA-256 no manifesto, e listados no [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.pt-BR.md).

Ao abrir um pull request, você declara que a contribuição é sua e segue estas regras.

## Desenvolvimento

Veja [Desenvolvimento](docs/pt-BR/development.md). Antes de um pull request:

- `swift build` e `swift test` passam;
- uma mudança na interface foi conferida no app empacotado (`./scripts/package-app.sh`, `open dist/WinHub.app`);
- mudanças no JSON publicado (`catalog.json`, `runtimes.json`, `components.json`) continuam decodificáveis pelas
  versões antigas do app.

## Receitas do catálogo

As receitas (como instalar um programa) ficam em `Sources/WinHub/Resources/catalog.json`. Descreva só passos que
você mesmo testou e use apenas URLs oficiais de download dos fabricantes. A nota de um jogo e a recomendação de
Direct3D devem vir com um [relatório de compatibilidade](docs/pt-BR/compat/README.md).

## Documentação

Inglês e português do Brasil andam juntos: toda página de `docs/` tem o espelho em `docs/pt-BR/`, e toda página da
raiz tem o seu `.pt-BR.md`. Mude os dois no mesmo pull request.

## Commits

Pequenos e focados, com o assunto em inglês no imperativo.
