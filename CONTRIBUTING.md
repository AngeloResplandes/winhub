# Como contribuir

Obrigado pelo interesse no WinHub!

## Regra de "sala limpa" (obrigatória)

O WinHub é um projeto independente. Para mantê-lo livre de problemas de licença:

- **Não copie** código, scripts, textos, traduções, ícones nem dados de produtos comerciais,
  em especial do CrossOver (CodeWeavers), nem os bancos de compatibilidade deles.
- **Não envie** resultados de engenharia reversa de software proprietário (código descompilado,
  endereços, nomes de símbolos internos).
- Baseie-se em **documentação pública**: wiki e manuais do Wine (winehq.org), documentação da
  Apple e dos projetos abertos listados em `THIRD_PARTY_NOTICES.md`.
- **Não adicione binários de terceiros** ao repositório. Componentes externos são baixados em tempo
  de execução, a partir da fonte oficial, com SHA-256 registrado no manifesto.

Ao abrir um pull request, você declara que a contribuição é sua e respeita essas regras.

## Desenvolvimento

Requisitos: macOS 14+, Xcode 16+ (Swift 6) e Rosetta 2 nos Macs com Apple Silicon. Para empacotar
(`./scripts/package-app.sh`), também o mingw-w64 (`brew install mingw-w64`), que compila o wrapper da Steam.
Para usar a Steam com `swift run`, veja "Steam e a janela preta" no README.

```bash
swift build
swift test
swift run WinHub
```

## Receitas do catálogo

Receitas (como instalar um programa) ficam no catálogo JSON. Descreva só passos que você mesmo testou
e use apenas URLs oficiais de download dos fabricantes.
