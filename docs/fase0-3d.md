# Fase 0 3D — ferramentas instaladas e verificadas

Data: 2026-10-26. Branch `muse/summon-3d-fase0`. Nenhum código de jogo e nenhum asset entrou no
repositório; downloads e testes ficaram em `build/3d/` (não versionado).

## Ferramentas

| Ferramenta | Versão | Status | Smoke test |
|---|---|---|---|
| Godot | 4.7.2-stable (já instalado) | — | renderizou Forward+ e Compatibility (RTX 3080) |
| Blender | 5.2.3 LTS (portátil oficial, sha256 `723f08a4…dc2fb` conferido) | ok | `blender --version` |
| uv / uvx | 0.13.5 | ok | `uv --version` |
| MCP `blender` (mcp-for-blender) | servidor "MCP for Blender" 1.30.0; addon 1.8 | ✔ Connected | PASS (ver abaixo) |
| MCP `godot` (Coding-Solo/godot-mcp) | via npx | ✔ Connected | PASS (ver abaixo) |
| Soft Toon Shader (fcidade) | 1.0.1, CC0 | — | compila e funciona em Forward+ e Compatibility |
| Kenney Animated Characters — Survivors | CC0 (amostra grátis) | — | modelo + 3 animações importam e animam sem erro |

### Observações de instalação
- **Blender via winget ficou parado num pedido de UAC** (instalador MSI de máquina inteira precisa
  de administrador). Para não bloquear, usei a build portátil oficial do mesmo 5.2.3, por usuário,
  sem admin. O pedido de UAC é pendência do João (aprovar instala uma segunda cópia no sistema,
  que não é usada pelo MCP; recusar não muda nada).
- **BlenderMCP mudou de nome**: `blender-mcp` virou wrapper de compatibilidade que imprime um aviso
  no stdout (o canal do protocolo MCP). Registrei com o nome atual, `uvx mcp-for-blender`, como o
  próprio projeto recomenda.
- **Telemetria do BlenderMCP**: por padrão envia um registro anônimo mínimo de uso; conteúdo só com
  opt-in. Desligado por completo com `DISABLE_TELEMETRY=true` no `.mcp.json` (não é segredo).

## Smoke tests

**MCP `blender`** (cliente stdio descartável que sobe o servidor exatamente como o `.mcp.json`):
1. `get_scene_info` → cena padrão (Cube, Light, Camera).
2. `execute_blender_code` → UV sphere "SmokeSphere" + material "SmokeMat" (Base Color 0.8/0.1/0.1),
   export `smoke.glb` (70 456 bytes, cabeçalho `glTF` v2).
3. `get_scene_info` → SmokeSphere presente.
4. Leitura de volta: reimport do `.glb` → 1 malha, 1984 vértices, material com a mesma cor.

**MCP `godot`**: `get_godot_version` → `4.7.2.stable.official.ed1daf0bf`; `create_scene` com raiz
`Node3D` + `add_node` `MeshInstance3D` ("SmokeMesh") → cena salva e verificada; apagada depois.

## Soft Toon Shader (fcidade, CC0)
- Baixado de graça no itch.io ("name your own price", US$ 0, sem conta). Licença CC0 (Francisco
  Cidade); modelos do exemplo = Kenney Graveyard Kit (CC0). Scripts do exemplo auditados (só leem
  variáveis de ambiente).
- **Compila sem erros** em Forward+ e em Compatibility (Godot 4.7.2), tanto o exemplo do autor
  quanto num personagem Kenney.
- **Visual nos dois renderers:** bandas de luz/sombra (sombra azulada) e contorno de tinta
  (inverted hull) funcionam igual; o `add_screen_pass` escolhe sozinho o shader certo por renderer.
- **Diferença em Compatibility:** no exemplo, o chão sob as luzes dos postes (omni) sai mais claro e
  lavado que no Forward+. Não quebra, mas a iluminação de lâmpadas não é idêntica — vale testar no
  protótipo web se houver luzes pontuais. Os vincos por normais do motor existem só em Forward+ (em
  Compatibility usa a passagem só por profundidade, como documentado).
- Stylo não foi necessário (o Soft Toon funcionou nos dois renderers).

## Amostra Kenney (Animated Characters — Survivors, CC0)
- 1 modelo (`characterMedium.fbx`, malha + esqueleto de 58 ossos), 4 skins PNG (humanos e zumbis),
  3 animações FBX (Idle 1,07 s, Run 0,67 s, Jump 0,50 s). Baixado direto de kenney.nl (grátis, sem
  conta).
- Importa no Godot 4.7.2 (FBX nativo/ufbx) **sem erros nem avisos**.
- Animação aplicada no modelo a partir dos arquivos separados: **todas as trilhas resolvem** e os
  ossos se movem (Idle 15, Run 18, Jump 9 ossos animados); nenhum aviso de trilha.
- Escala do FBX vem em ~3,76 unidades de altura (normalizar ao importar). Renderiza com skin e
  Soft Toon nos dois renderers.
- **Não comprados:** Kenney All-in-1 (US$ 19,95) e packs Synty — decisão do João.
