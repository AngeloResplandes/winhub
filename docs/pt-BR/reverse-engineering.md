[English](../reverse-engineering.md) · **Português (Brasil)**

# Engenharia reversa: o que foi estudado no CrossOver

> **Última revisão:** 2026-10-12 · **Alvo:** CrossOver 26.3.0 para macOS

O WinHub reproduz comportamentos do CrossOver 26.3 estudados **de fora**: o que o app faz, como o pacote é
organizado, que arquivos e configurações usa. Esta página registra o que foi estudado no próprio app (o catálogo e
as garrafas). O motor (Wine, Direct3D, as regras por jogo) tem página própria no winhub-engine:
[Como o CrossOver roda jogos](https://angeloresplandes.github.io/winhub-engine/pt-BR/reverse-engineering.html).

## Regras

- Estudamos **o que o CrossOver faz**, nunca copiamos como ele é escrito.
- **Nunca** copiamos código, binários, textos, traduções, ícones nem dados do CrossOver. O WinHub não lê, não copia
  e não redistribui o catálogo do CrossOver, o banco de compatibilidade dele nem a interface.
- O código que a CodeWeavers publica sob a LGPL (a árvore do Wine do CrossOver) é usado pelo winhub-engine, com
  atribuição.
- Esta documentação descreve comportamento. Código descompilado, endereços, nomes de símbolos internos e logs da
  análise ficam fora do repositório.

## Método

1. **Inspeção do pacote.** Como o `CrossOver.app` é organizado: o executável principal, os arquivos de interface,
   os módulos Python embutidos que cuidam do catálogo e das garrafas, os scripts do lançador (Perl, texto legível),
   os modelos de garrafa e os arquivos de dados.
2. **Análise estática** com o [REA](https://github.com/morluto/rea) (provider Hopper) do executável principal e dos
   arquivos de interface, para aprender a ordem das decisões: o que o campo de busca envia, como a lista é
   filtrada, ordenada e cortada, de onde vem o catálogo e como ele é atualizado.
3. **Confirmação pelo comportamento.** Os resultados que a busca do WinHub calculou foram comparados, antes de
   olhar, com capturas de tela da própria interface do CrossOver (sistema em português do Brasil): a busca vazia
   mostrou os mesmos 8 destaques na mesma ordem, e `excel` os mesmos 16 resultados na mesma ordem, inclusive os
   nomes localizados e "Otoshimizu Excellent" (o padrão também casa dentro das palavras). Um protótipo anterior
   também foi conferido com uma cópia do catálogo na máquina de quem fez a análise: 4.489 títulos, nenhuma
   diferença de nome, nota ou listagem. Esse catálogo nunca entrou em nenhum repositório.

## Busca do catálogo

O que a tela "instalar um aplicativo do Windows" do CrossOver faz:

- A busca é **local e na memória**, sobre o arquivo de catálogo que o CrossOver guarda na Biblioteca do usuário
  (um XML assinado de cerca de 24 MB). Nada vai para a rede durante a busca.
- O campo de busca é **contínuo**: pesquisa enquanto você digita, com o pequeno atraso habitual do macOS.
- O texto digitado é dividido em palavras, que viram um padrão `*palavra1*palavra2*`, comparado **sem diferenciar
  maiúsculas nem acentos** (semântica do `LIKE[cd]`) com **só o nome**, no idioma do usuário.
- Com o campo vazio, a tela mostra os títulos que o catálogo marca como **destaque para o Mac**.
- "Mostrar aplicativos sem teste" vem **ligado por padrão**. Desligado, somem os títulos com nota "sem teste" ou
  "não instala".
- A lista é ordenada pelo nome em **ordem natural** (`localizedStandardCompare`) e cortada em **128 itens**.
- As notas vão de 0 a 5 (sem teste, não instala, instala mas não roda, funcionalidade limitada, funciona bem,
  funciona muito bem), mais "não confiável" para fontes em que o app não confia.
- O catálogo tem uma entrada por receita e versão do CrossOver; quando um aplicativo aparece mais de uma vez, o app
  fica com uma por uma pontuação que prefere o mesmo produto, a receita mais próxima da versão instalada do
  CrossOver e as datas mais novas. A medalha mostrada é a da versão instalada, ou a mais nova anterior a ela.
- O catálogo é atualizado em segundo plano no máximo uma vez por dia: quando o arquivo tem mais de duas horas, o
  app faz um download condicional, confere a assinatura SHA-256 dele com uma chave pública que vem no pacote e só
  então troca o arquivo.

**Como o WinHub reproduz isso:**

| CrossOver | WinHub |
|---|---|
| palavras → padrão `*a*b*` | `CatalogSearchEngine.likePattern(for:)` |
| comparação `LIKE[cd]` | `WildcardPattern` (casamento próprio, sem diferenciar maiúsculas, acentos e largura) |
| nome no idioma do usuário | `CatalogEntry.displayName(preferredLanguages:)` |
| destaques com o campo vazio | `CatalogEntry.isFeatured` |
| sem teste visíveis por padrão | `Options.showUntested = true`; `Rating.isTested` |
| ordem natural, 128 itens | `localizedStandardCompare`, `defaultResultLimit = 128` |
| catálogo assinado atualizado em segundo plano | `RemoteDataSync`: o `catalog.json` do próprio WinHub, da `main`, guardado só se decodificar |

O catálogo em si é do WinHub, escrito a partir dos testes do WinHub. Especificação completa:
[Busca do catálogo](catalog-search.md).

## Garrafas e o lançador

O que os modelos de garrafa e os scripts do lançador (texto legível no pacote) fazem, e o que o WinHub faz com isso:

| CrossOver | WinHub |
|---|---|
| O lançador define `ROSETTA_ADVERTISE_AVX=1` e `DOTNET_EnableWriteXorExecute=0` em todo processo do Wine | O `WineEnvironment` define as mesmas duas variáveis |
| A escolha de gráficos é uma configuração da garrafa lida pelo motor; nada é copiado para a garrafa desde o CrossOver 25 | `Bottle.graphics` → `WINHUB_GRAPHICS_BACKEND`; escolhas por programa viram regras ([Gráficos](graphics.md)) |
| Os modelos removem DLLs do DXVK que versões antigas copiavam para as garrafas e convertem configurações antigas | O `migrateToDispatchedGraphics` remove as cópias e os overrides antigos do próprio WinHub |
| O msync é uma configuração da garrafa (`WINEMSYNC`) | `Bottle.msync` |
| O D3DMetal vem junto | O D3DMetal só do Game Porting Toolkit do próprio usuário (licença da Apple) |

O quanto o resultado se aproxima: [Paridade com o CrossOver](crossover-parity.md).
