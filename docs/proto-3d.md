# Protótipo 3D — câmera, legibilidade e sensação (placeholders)

Branch `muse/summon-3d-proto`. Cena 3D separada do jogo 2D (a v1 2D e o deploy não mudam).

## O que foi criado
- `proto3d/main_3d.tscn` + `main_3d.gd`: fluxo ritual (tela da v1, reaproveitada sem mudança) →
  batalha 3D → tela final da v1 → "Invocar de novo".
- `proto3d/battle_3d.gd` (`Battle3D`): arena 30×45 m (v1 1200×1800 px ÷ 40), chão + muros + 2 pilares,
  NavigationRegion3D com navmesh assada em tempo de execução, simulação no `_physics_process` com
  hit-stop, regras de combate da v1, FOCAR (6 s / recarga 12 s), vitória/derrota.
- `proto3d/unit_3d.gd` (`Unit3D`): CharacterBody3D + NavigationAgent3D; números de `Defs` (config #12,
  só leitura) convertidos para metros. Heróis = Kenney Survivors (CC0) normalizado (~1,75–1,95 m),
  skin tingida na cor de identidade, contorno Soft Toon na mesma cor e anel no chão; animações Idle/Run.
  Goblins = cápsulas com orelhas (Rastejante verde-doente, Fundeiro âmbar, Bruto verde-escuro e maior).
- `proto3d/brains_3d.gd` (`Brains3D`): as 7 IAs da v1 portadas com as mesmas regras (Muralha, Paciência,
  Triagem com cura <30 % durante o FOCAR, Oportunista, Rastejante, Fundeiro, Bruto mirando quem tem mais HP).
- `proto3d/camera_bg3.gd` (`CameraBG3`), `hud_3d.gd`, `fx_3d.gd`, `projectile_3d.gd`.
- `proto3d/debug/autotest_3d.gd`: ponta a ponta (`--autotest3d` / `?autotest3d`) e lote
  (`--proto-batch=N`).
- `proto3d/vendor/`: Soft Toon 1.0.1 (CC0) e amostra Kenney Survivors (CC0), com licenças.
- `project.godot` + `export_presets.cfg`: preset novo **"Web Proto3D"** (feature tag `proto3d` troca a
  cena inicial só nesse export; saída `build/web3d/`). O preset "Web" do jogo 2D não mudou.

Arquitetura escolhida: mesma pasta de projeto, cena isolada em `proto3d/`, reaproveitando `Defs`,
`Sfx` e as telas de ritual/final. Alternativa descartada: projeto Godot separado dentro do repo
(duplicaria dados, áudio e telas).

## Câmera
Pitch fixo de 50°, por trás dos heróis, olhando para o centroide do grupo deslocado 2,5 m para a frente
(lado inimigo) para caber a luta no retrato; segue com suavização exponencial; ponto de mira preso
dentro da arena; zoom pela roda/pinça por distância (9–30 m, padrão 17 m); tremor em golpes pesados.
Sem rotação.

## Resultados
- Lote headless (10 lutas por política, determinístico como a v1):
  - sem FOCAR: 46,7 s · 10/10 vitórias · 0 mortes;
  - FOCAR nos Fundeiros: 60,0 s · 10/10 vitórias · 1,00 morte (Kess).
  O balance difere da v1 (física, colisão de cápsulas e navmesh mudam o espaçamento) — o ajuste fino
  recomeça depois.
- Ponta a ponta (headless, Mobile e Compatibility com janela, e navegador): ritual → Lutar → zoom →
  FOCAR por toque num Fundeiro → vitória (~68–70 s, 2/4 vivos) → "Invocar de novo"; rodada 2 com
  derrota forçada. PASS em todos.
- Navmesh: 30 polígonos; caminho que contorna um pilar (6,9 m contra 6,0 m em linha reta). A sincronização
  da região é assíncrona no Godot 4.7 (< 1 s); até lá as unidades andam em linha reta.
- Export web (Compatibility / WebGL2, sem threads): exit 0; abre no Chrome sem erro de shader.

## O que o protótipo PROVOU
- Câmera estilo BG3 (pitch fixo + follow + zoom por distância) funciona no retrato e nos dois renderers.
- Os 4 heróis são distinguíveis em combate pelo anel + tinta + contorno na cor de identidade, inclusive
  a Kess dentro do grupo; goblins leem pela forma e cor.
- As IAs da v1 rodam em 3D com navmesh, física e FOCAR (toque na tela → alvo) sem mudar regras.
- Soft Toon funciona em Mobile, Compatibility e no navegador; o pipeline web 3D roda sem threads.
- A v1 2D continua intacta (mesmo resultado de autotest).

## O que AINDA falta validar antes da arte final
- **Arte e silhueta reais**: heróis hoje são o mesmo modelo Kenney tingido; a leitura com modelos finais
  diferentes (e sem tinta) precisa ser revalidada.
- **Rótulos no grupo**: nomes/barras se sobrepõem no corpo a corpo.
- **Enquadramento no retrato**: com o deslocamento de 2,5 m, o Orin (retaguarda) encosta no botão FOCAR;
  decidir entre deslocamento menor, câmera mais alta ou HUD mais compacto.
- **Rotação de câmera** (fora do escopo desta fase) e câmera em paisagem/desktop.
- **Desempenho**: medir FPS no navegador e em celular real (aqui só desktop + Chrome headless).
- **Balance 3D**: refazer a medição com variância (frame rate/jogador) como na v1.
- **Luzes pontuais**: o protótipo usa só direcional + ambiente; se a arte final pedir tochas/omni,
  testar o chão lavado em Compatibility (ressalva da Fase 0).
- **Tamanho do export 2D**: com `proto3d/` no projeto, o preset "Web" da v1 passa a empacotar também os
  arquivos do protótipo (pck ~0,4 MB maior). Para excluir, seria preciso mexer no preset 2D
  (`exclude_filter="proto3d/*"`) — decisão do João.
