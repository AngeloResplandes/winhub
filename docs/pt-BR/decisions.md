[English](../decisions.md) · **Português (Brasil)**

# Decisões

Registro datado das decisões que deram forma ao WinHub, das mais novas para as mais antigas.

## 2026-10-13: Declarar o microfone no Info.plist do WinHub

O macOS conta os processos do Wine abertos pelo WinHub como sendo do WinHub nas verificações de privacidade. Sem
`NSMicrophoneUsageDescription`, ele recusa o microfone **sem perguntar** e encerra a thread que pediu; por isso jogos
com chat de voz (Lethal Company, PEAK) travavam no carregamento. O `package-app.sh` agora declara o uso (português no
`Info.plist`, inglês no `en.lproj/InfoPlist.strings`), e o macOS pergunta à pessoa na primeira vez.

## 2026-10-12: Documentar a engenharia reversa abertamente

A regra antiga proibia mencionar qualquer engenharia reversa. Agora o WinHub documenta o que foi estudado no
CrossOver e como isso é reproduzido, como outras reimplementações em "sala limpa": só comportamento, nunca código
ou dados. Código descompilado, endereços, nomes de símbolos internos e logs da análise ficam fora do repositório.
Veja [Engenharia reversa](reverse-engineering.md) e
[CONTRIBUTING](https://github.com/AngeloResplandes/winhub/blob/main/CONTRIBUTING.pt-BR.md).

## 2026-10-12: Baixar o banco de regras do motor só quando assinado

O `CompatDatabaseSync` baixa o `data/compatdb.json` do winhub-engine e a assinatura Ed25519 dele, e só o instala
quando a assinatura confere com a chave embutida no app e o banco é mais novo que o instalado. Uma regra pode mudar
o ambiente e os argumentos de um programa, então um arquivo sem assinatura ou reenviado nunca é usado. Trocar a
chave exige uma versão nova do app. Veja [SECURITY](https://github.com/AngeloResplandes/winhub/blob/main/SECURITY.pt-BR.md).

## 2026-10-11: Deixar o motor escolher o Direct3D

Com motores que declaram `backend-dispatch` (revisão 2 do winhub-engine), o WinHub não copia mais DLLs para as
garrafas: ele define `WINHUB_GRAPHICS_BACKEND` e escreve as escolhas por programa como regras, e o motor põe o
tradutor escolhido no começo do caminho de DLLs do Wine, como o CrossOver faz desde a versão 25. Garrafas da época
das cópias são migradas antes de um programa abrir. O caminho das cópias continua para os motores antigos.

## 2026-10-11: D3DMetal só do usuário

A licença da Apple não permite redistribuir o D3DMetal. O WinHub só o usa quando o usuário aponta
**Ajustes → D3DMetal** para o próprio Game Porting Toolkit; nunca o inclui nem o baixa.

## 2026-10-11: Nunca abrir duas Steams da mesma garrafa

Durante o teste de um motor, uma Steam de teste ainda estava aberta numa cópia de uma garrafa quando a Steam da
garrafa original foi aberta. Essa Steam marcou dois jogos como "arquivos faltando" e os desinstalou. Os testes agora
rodam num clone APFS da garrafa, com uma Steam aberta por vez: todos os processos do Wine do clone são encerrados
antes de a garrafa real abrir, e vice-versa.

## 2026-10-11: Um programa pode ter o próprio Direct3D

Trocar a garrafa inteira da Steam para DXVK ou DXMT também muda a janela da própria Steam. A escolha por programa
dá o Direct3D só ao `.exe` do jogo: DLLs na pasta do `.exe` com overrides em `AppDefaults` nos motores antigos, e
uma regra na revisão 2. DLLs que o próprio jogo traz nunca são trocadas.

## 2026-10-11: Trocar o steamwebhelper por um wrapper

No Wine 11 para macOS, a janela da Steam fica preta: a interface dela é um Chromium que desenha cada janela a
partir de outro processo, e o driver de macOS do Wine não mostra esse desenho. Um pequeno programa do Windows do
próprio WinHub (`Support/steamwebhelper-wrapper`) fica no lugar do `steamwebhelper.exe` e abre o original com
`--in-process-gpu`. A Steam só é aberta com `-noverifyfiles` quando o wrapper está instalado; a primeira sessão
depois de instalar a Steam fica preta porque é nela que a Steam baixa o cliente e o helper. As opções `-cef-*` da
Steam, `renderer=vulkan` e o DXVK não resolveram.

## 2026-10-11: Pacotes oficiais do WineHQ em vez do WineCX 24

O build aberto do WineCX 24 quebra a Steam no macOS 27: o sistema devolve vazia a lista de conexões TCP para apps
comuns, e a Steam rejeita o helper dela. O Wine 9.17 e mais novos montam essa tabela no `wineserver`. O WinHub
passou para os pacotes oficiais do WineHQ; a revisão 2 do motor (Wine 11.0 das fontes do CrossOver 26) também tem
a correção.

## 2026-10-11: Atalhos delegam ao WinHub

Programas abertos de dentro do processo do próprio atalho `.app` travam (a Steam para em "Verifying…"). Os atalhos
só abrem um link `winhub://`, e o WinHub inicia o programa depois de conferir que o `.lnk` está dentro da garrafa.

## 2026-10-11: Limpar processos deixados por um wineserver morto

Quando o `wineserver` morre sem encerrar os clientes, o `winedevice.exe` fica vivo para sempre, e o servidor
seguinte reusa a mesma pasta sem alcançá-lo. O `WineOrphanReaper` encerra esses processos quando ninguém segura o
`lock` da pasta do servidor (não o socket, que um servidor morto deixa para trás).
