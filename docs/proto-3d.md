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
Pitch fixo de 50°, por trás dos heróis, sem rotação; zoom pela roda/pinça por distância (9–30 m,
padrão 17 m); mira presa dentro da arena; tremor em golpes pesados.
**Enquadramento (correção posterior):** a extensão dos heróis na tela (cabeça do mais avançado → anel
do mais recuado) fica centralizada na faixa livre do HUD, entre o painel do topo e o botão FOCAR.
Quando o grupo se espalha além dessa faixa, a câmera recua só o necessário (até 30 m), por cima do zoom
do jogador, e volta à distância escolhida quando o grupo se junta. Pitch e zoom padrão não mudaram.

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
- **Recuo automático da câmera**: resolve o botão FOCAR, mas recua em ~40–60 % dos frames (até +13 m)
  quando Orin/Yara ficam longe do grupo. Validar a sensação em mão (pode pedir um teto menor para o
  recuo ou um HUD mais compacto).
- **Goblins sob o painel do topo**: o enquadramento prioriza os heróis; goblins à frente ficam sob o
  painel em ~15–26 % dos frames.
- **Rotação de câmera** (fora do escopo desta fase) e câmera em paisagem/desktop.
- **Desempenho**: medir FPS no navegador e em celular real (aqui só desktop + Chrome headless).
- **Balance 3D**: refazer a medição com variância (frame rate/jogador) como na v1.
- **Luzes pontuais**: o protótipo usa só direcional + ambiente; se a arte final pedir tochas/omni,
  testar o chão lavado em Compatibility (ressalva da Fase 0).

## Correções (2026-10-26)
| Correção | Como foi verificada |
|---|---|
| Rótulos não se sobrepõem: empilhamento vertical (de baixo para cima; quem colidiria sobe o mínimo, com fio até a cabeça) | sonda por frame em 2 batalhas completas: 0 sobreposições; captura com os 4 heróis + 5 goblins agrupados: 9 rótulos, 0 sobreposições |
| Nenhum herói no botão FOCAR: enquadramento pela faixa livre do HUD + recuo temporário | sonda por frame: 0 frames com herói sobre o botão/barra (antes: 50 % sem FOCAR, 13 % com FOCAR); reduzir a mira à frente não bastava (0 m ainda deixava 2–16 % dos frames) |
| Export 2D sem o protótipo: `exclude_filter="proto3d/*"` no preset "Web" | nenhum arquivo de `proto3d/` no pck 2D; v1 roda no navegador sem erros; preset "Web Proto3D" intacto |
