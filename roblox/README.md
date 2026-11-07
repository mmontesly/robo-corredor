# Nodex: Robô Corredor — protótipo Roblox da Fábrica

Adaptação jogável, em Luau, da corrida da **Fábrica** do app React Native/Expo *Nodex: Robô Corredor*.

O app original não foi alterado. Não há deploy, upload para a Roblox, conta nova nem pagamento. Este lugar é para o dono abrir no **Roblox Studio (Windows ou Mac)** e testar.

No modo de edição o Workspace parece vazio. A pista **não está desenhada no arquivo**: o servidor constrói a Fábrica quando o Play começa, só com `Part`s. Não usa Toolbox, decal, mesh, som nem animação da plataforma.

## Se o Play mostrar só o céu

Isso foi o que aconteceu na primeira abertura. O arquivo antigo gravava `FallenPartsDestroyHeight = -80` com o Workspace **sem nenhum chão**. O cliente também não desenhava a interface enquanto esperava um remote que só existe depois da fábrica pronta. Qualquer erro antes disso apagava o personagem e deixava a câmera no céu, sem cartão.

O servidor cria um chão laranja e uma placa **antes** de montar o robô e a pista. O cliente mostra uma faixa no topo assim que o script dele começa, e aponta a câmera para esse chão mesmo sem avatar. `Workspace.FallenPartsDestroyHeight` e `Workspace.StreamingEnabled` não são gravados por script: o primeiro só pode ser definido por plugin (o Play mostrou `PluginOrOpenCloud`) e o segundo a documentação marca como não scriptável. Quem cai abaixo de Y = -30 é teletransportado de volta ao chão. Streaming continua `false` só no arquivo do lugar.

1. Abra o `.rbxlx` novo e aperte **Play**.
2. Aba **View → Output**.
3. A primeira linha do servidor tem de ser exatamente:

   `[Nodex] boot: script do servidor iniciou`

4. Em seguida: `[Nodex] boot: chão de segurança pronto` e `[Nodex] boot: Fábrica pronta`.
5. No cliente: `[Nodex] cliente: script iniciou`.

Se a linha do **boot** não existir, o script do servidor não rodou (o Output fica só com mensagens padrão do Studio). Se existir `[Nodex] FALHA NO BOOT`, o erro completo está nessa mensagem e numa placa vermelha no mundo. A faixa de cima do cliente repete o mesmo texto. Não fica mais uma espera infinita sem aviso.

Na corrida o robô olha para a chegada (+X). A frente do modelo do Roblox é -Z; o rosto fica nesse lado. **Q** solta o foguetinho (freia quem está à frente, alcance curto, 2,5 s) e **E** larga óleo atrás (freia quem passar por cima no chão). Os dois compartilham **8 s** de recarga, com **2 s** de espera no começo. Sozinho o tiro aparece mesmo sem alvo. No computador as setas grandes de toque ficam escondidas.

## O que este protótipo já faz

- Sala de **1 a 8** robôs. **Treino solo** funciona (não precisa de outra pessoa para ver a corrida).
- Lobby com os **12 apelidos** fechados do app e as **8 primeiras cores** (Azul, Rosa, Roxo, Verde, Laranja, Amarelo, Anil, Marrom).
- Anfitrião é quem entrou primeiro. **Pronto** em todo mundo começa sozinho. O anfitrião também pode **Começar** e puxar a sala inteira.
- Contagem do servidor: **3, 2, 1, Já!**
- Corrida automática para a frente. Pulo com **Espaço** ou o botão **Pular**. **W/S** ou **▲▼** desviam para não emperrar no vizinho.
- Uma pista fixa da Fábrica: engrenagem, óleo e bateria.
- **4 postos** no caminho. Cair ou apertar **Voltar ao posto** volta ao último arco, sem pular a volta.
- Chegada, tempo, baterias e pódio. Quem não cruzar em **20 s** depois do primeiro fica como tempo esgotado (DNF).
- **Nova corrida** devolve todo mundo ao lobby. Vitórias desta sessão aparecem no cartão (não é a série melhor-de-N do app).
- Quem entra no meio espera a próxima. Quem sai no meio não trava os outros.

## Abrir o lugar (sem Rojo)

1. Copie `Nodex-Robo-Corredor.rbxlx` para o Windows ou o Mac.
2. Abra o **Roblox Studio** e use **File → Open** nesse arquivo.
3. Aperte **Play** (F5). Não precisa publicar.
4. Abra a janela **Output**. Deve aparecer uma linha nesta forma:

   `[Nodex] Robô Corredor — Fábrica pronta. Chegada em 748 studs, 4 postos. Até 8 robôs; treino solo permitido.`

5. O céu amarelo, a esteira laranja e o cartão **Nodex: Robô Corredor** aparecem depois do Play, não antes.

## Teste solo no Studio

1. Play.
2. No cartão, confira o mundo **Fábrica** e as frases *Pule as engrenagens e o óleo!* e *Baterias dão turbo!*.
3. Toque um apelido (por exemplo **Turbo**). O nome acima do robô muda. Um apelido de fora da lista é ignorado pelo servidor.
4. Toque **Pronto** ou **Começar treino**.
5. Veja **3**, **2**, **1**, **Já!**. O robô só anda depois do Já.
6. A corrida vai sozinha para a direita da tela. **Espaço** pula. **W** e **S** chegam mais perto ou mais longe da câmera.
7. Sem pular, a primeira engrenagem **segura** o robô e o HUD mostra **DEVAGAR**.
8. Pulando por cima, a engrenagem não aplica devagar de novo nessa peça (cada peça só conta uma vez).
9. Passar pelo óleo no chão também deixa devagar por **1 s**, na metade da velocidade.
10. Bateria baixa (no chão) e bateria alta (no pulo) mostram **TURBO** por **1,2 s** e sobem o contador 🔋. A mesma bateria não conta duas vezes.
11. Passe pelos arcos **POSTO 1** a **POSTO 4**. No tabuleiro do Studio (tecla Tab) a coluna **Posto** acompanha.
12. No meio da pista, toque **Voltar ao posto**. O robô volta ao último arco e **não** ganha a chegada.
13. Cruze o arco **CHEGADA**. O tempo para. O pódio mostra lugar, tempo e baterias.
14. Toque **Nova corrida** (ou espere uns 16 s). O lobby volta e dá para repetir.
15. Caia da borda de propósito (pule para fora no lobby). O servidor devolve você à plataforma.

## Teste multijogador no Studio (2, 4 e 8)

O Studio não usa a internet do jogo publicado. O teste local é **Test → Start → Server & Clients** (em versões antigas: **Start Server + Players** / **Clients and Servers**).

1. Na aba **Test**, mude o modo de **Play** para **Server and Clients** (ou o nome equivalente da sua versão).
2. Coloque **Players = 2**.
3. Aperte **Start**. Abrem a janela do servidor e uma janela por cliente.
4. No **Output do servidor**, confira a frase da Fábrica pronta.
5. O **Cliente 1** costuma ser o anfitrião (quem entrou primeiro). O cartão dele tem **Começar**. O outro mostra *O anfitrião pode começar*.
6. Teste os dois jeitos, em rodadas separadas:
   - os dois tocam **Pronto** (a contagem começa sozinha);
   - só o anfitrião toca **Começar** (entra quem está na sala, mesmo sem Pronto).
7. A contagem **3, 2, 1, Já!** tem de ser a mesma nas duas janelas. Quem manda é o servidor.
8. Um jogador pega bateria (fica mais rápido). O outro pisa no óleo (fica devagar). O 🔋 de um **não** sobe no outro.
9. Quem cruza a chegada primeiro fica com o menor tempo no pódio.
10. O outro ainda pode chegar. Se passar **20 s** depois do primeiro, o HUD avisa **Tempo esgotado!** e o pódio marca DNF.
11. Feche a janela de um cliente no meio da corrida. O outro não pode ficar preso. O cartão avisa que essa pessoa **saiu**.
12. **Nova corrida** devolve os dois ao lobby.
13. Repita com **Players = 4** e **Players = 8**. No nono cliente o lugar recusa (máximo 8). Se a sua versão do Studio deixar entrar mais gente, o servidor expulsa com a frase da sala cheia.
14. Entre com um cliente **depois** que a contagem já começou. Esse robô fica no lobby com *Corrida em andamento. Você entra na próxima.*

Atalho de teclado no cliente: **WASD** ou setas, **Espaço** pula. No celular (quando publicar um teste, fora deste protótipo) os botões **◀ ▶ ▲ ▼** e **Pular** são grandes de propósito. **◀ ▶** só existem no lobby; na corrida o robô anda sozinho.

## Rojo (opcional)

Só precisa disso para **editar os scripts** e reconstruir o lugar. Para jogar, o `.rbxlx` basta.

Foi gerado com **Rojo 7.7.1**.

```bash
# na pasta roblox/
rojo build default.project.json -o Nodex-Robo-Corredor.rbxlx

# edição ao vivo: no Studio, plugin do Rojo, Connect em localhost:34872
rojo serve default.project.json
```

O `default.project.json` aponta `src/shared`, `src/server` e `src/client`. Não há pasta `ios/` nem `android/` envolvida. O mapa continua sendo criado em tempo de execução por `CourseBuilder`.

## Onde está o código

| Arquivo | Função |
| --- | --- |
| `src/shared/Config.luau` | Nome, apelidos, cores e frases do app |
| `src/shared/Rules.luau` | Velocidade, turbo, devagar, pódio, DNF |
| `src/shared/Course.luau` | A pista única e as regras de acerto |
| `src/server/CourseBuilder.luau` | Geometria da Fábrica |
| `src/server/RobotFactory.luau` | Robô de blocos com Humanoid |
| `src/server/RaceService.luau` | Lobby, corrida, validação |
| `src/server/Main.server.luau` | Liga tudo uma vez |
| `src/client/Main.client.luau` | Câmera lateral, teclado, toque |
| `src/client/Hud.luau` | Cartão, contagem, pódio |
| `tests/check.luau` | Testes fora do Roblox |

## Diferenças em relação ao app React

O app mede a corrida em **pixels** (285 px/s, gravidade 2600, pulo 980, chegada aos 7000 px, obstáculos sorteados pela semente). Aqui isso foi **reescrito em studs**, não copiado número por número:

| | App (corrida) | Este protótipo |
| --- | --- | --- |
| Andar | 285 px/s, o cenário rola | 22 studs/s, Humanoid, a câmera acompanha |
| Gravidade / pulo | 2600 e impulso 980 | gravidade padrão **196,2** e `JumpHeight` **8,5** |
| Devagar (óleo ou engrenagem) | 0,5× por **1 s**, uma vez por peça | igual |
| Turbo (bateria) | 1,35× por **1,2 s**, uma vez por peça | igual |
| Os dois juntos | 0,5 × 1,35 | igual |
| Pista | sorteada, some no scroll | **uma** Fábrica fixa, compartilhada |
| Engrenagem | atravessa e freia | **sólida**: tem que pular; o primeiro encosto também freia 1 s |
| Óleo | poça baixa | poça sem colisão; no chão freia, no alto do pulo não |
| Bateria | baixa ou alta | igual, e vale para a faixa inteira |
| Postos | não tinha | **4**, para respawn sem recomeçar a volta |
| Chegada | aos 7000 px | aos **748 studs** (volta limpa simulada ~34 s) |
| DNF | 20 s depois do 1º | igual |
| Empate no tempo | número do jogador | cor/slot menor |
| Jogadores | online até 10 pelo WebRTC | servidor Roblox, **até 8**; solo permitido |
| Série | melhor de 2, 3 ou 5 | só o placar de vitórias da sessão |
| Poderes foguete/óleo | tinha na corrida | **não** entram agora |
| Controles | toque para pular | Humanoid: teclado e botões de toque |

Cores, apelidos, título **Nodex: Robô Corredor**, mundo **Fábrica** e as frases de pulo/turbo são os do app. Vermelho e Folha (jogadores 9 e 10) não entram porque a sala cabe 8.

## Fora deste protótipo

De propósito, para uma próxima leva:

- foguetinho e poça de óleo **ofensivos** (os poderes da corrida);
- Modo História, skins e os outros mundos (Gelo, Deserto, Doces, Cidade, Vulcão, Matemática, Português, Cores, Espaço);
- modo sem fim;
- parede de eliminação no estilo de outros jogos de corrida (não faz parte do Nodex e não foi copiada).

Nada de mapa, nome ou arte de outro jogo. A referência de “corrida lado a lado com pulo” ficou só na estrutura: auto-corrida, pulo, item e chegada.

## Testes já rodados (Linux, sem Roblox)

Isto **não** é um teste dentro do Roblox Studio nem num celular. Esta máquina não executa o cliente do Roblox.

- **Luau 0.746** `luau-compile --only-parse` nos 10 arquivos `.luau` (sintaxe).
- **Lune 0.11.1** `lune run tests/check.luau`: **97 checagens**. Inclui velocidade, pódio, DNF de 20 s, apelidos, cores, a validação da pista e uma simulação cinética (mesma gravidade e o mesmo pulo) em que quem pula termina em **34,00 s** com **7 baterias** e **4 postos**, e quem não pula para na primeira engrenagem.
- **Lune** `lune run tests/boot_order.luau`: executa o boot de verdade. O chão é criado antes do robô e da pista. Se o robô ou a pista quebram, o erro é reportado e a corrida não continua em silêncio.
- **Rojo 7.7.1** `rojo build` gerou `Nodex-Robo-Corredor.rbxlx` com `MaxPlayersInternal = 8` e `StreamingEnabled = false`.

Para repetir, na pasta `roblox/`:

```bash
lune run tests/check.luau
rojo build default.project.json -o Nodex-Robo-Corredor.rbxlx
```

## O que ainda precisa de olho no Studio

Não foi possível conferir aqui:

- se o Humanoid do robô de blocos fica com o pé na esteira (se flutuar ou afundar, o número a ajustar é `Course.HIP` / `HipHeight`, hoje **3**);
- se o pulo de 8,5 studs passa folgado pela engrenagem de 3,6 sem raspar a cápsula do Humanoid;
- câmera lateral, botões no tamanho de um celular de verdade, e duas janelas do Server & Clients ao mesmo tempo;
- som: não há, de propósito (som da plataforma exigiria asset id).

Se o robô andar “dobrado” (o controle padrão do Studio e o nosso ao mesmo tempo), o cliente tenta desligar o `PlayerModule`. Confira o Output se o movimento parecer brigar com o WASD.
