[English](../gaps.md) · **Português (Brasil)**

# Lacunas

> **Última revisão:** 2026-10-12

Faltas conhecidas, em ordem de quantas pessoas e jogos elas bloqueiam. As lacunas só do motor estão detalhadas nas
[lacunas do winhub-engine](https://angeloresplandes.github.io/winhub-engine/pt-BR/gaps.html). Números de paridade:
[Paridade com o CrossOver](crossover-parity.md).

| # | Lacuna | Bloqueia | Caminho provável |
|---|---|---|---|
| 1 | **Direct3D 12 sem D3DMetal** | jogos só Direct3D 12 ([The Witcher 3](compat/the-witcher-3.md), Resident Evil 4 Remake, Hogwarts Legacy) para quem não tem o Game Porting Toolkit | trabalho no motor: o Direct3D 12 do DXMT ou o vkd3d-proton |
| 2 | **Catálogo pequeno** | achar um título e saber que funciona: 31 títulos, 1 receita | acrescentar títulos e receitas conforme forem testados; um [relatório de compatibilidade](compat/README.md) por jogo |
| 3 | **Banco de regras vazio** | jogos que precisam de um Direct3D, uma variável ou um argumento específico para abrir | uma regra por jogo testado no `data/compatdb.json` do winhub-engine |
| 4 | **Vídeos dos jogos** | cenas e vídeos de abertura de muitos jogos | GStreamer e H.264 no motor |
| 5 | **Modos de tela 16:9** | 1920×1080 e outros modos fora da proporção da tela do Mac | emular modos no `winemac.drv` |
| 6 | **Interface só em português do Brasil** | quem não lê português | passar os textos para String Catalogs e traduzir, começando pelo inglês |
| 7 | **Exportar e importar garrafas** | levar uma garrafa para outro Mac, backups | arquivar a pasta da garrafa com o `bottle.json` |
| 8 | **Ícones dos programas** | reconhecer os programas nas listas e nos atalhos | extrair o ícone do `.exe` |
| 9 | **Versões sem notarização** | uma primeira abertura sem atrito (o macOS pede "Abrir Mesmo Assim") | assinar e notarizar com um Developer ID (o workflow de versões já suporta) |
| 10 | **Só x86_64** | o futuro: o suporte geral do Rosetta 2 acaba no macOS 28 | acompanhar o trabalho do Wine oficial em ARM64 para macOS |
