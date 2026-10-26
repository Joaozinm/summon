# Summon — regras do projeto

Jogo 2D em Godot 4 (renderer Mobile; export web usa Compatibility/WebGL2), inspirado em Pick Me Up.
O brief de jogo chega por fases; este arquivo guarda só as regras permanentes.

## Assets visuais

- **A Muse é dona de todos os assets visuais.** O Claude nunca gera, desenha, improvisa, baixa nem
  busca asset algum (sprites, ícones, fontes, fundos, UI, efeitos), nem como placeholder "provisório".
- **Nada de arte sem estilo e referência decididos.** Enquanto a Muse não tiver definido o estilo e
  entregue a referência, a tela usa só primitivas neutras do Godot (cor sólida, texto do tema padrão).
- Um asset entra no repositório somente quando vier da Muse, no caminho que ela indicar.

## Git

- **Nunca commitar na `main`.** A única exceção foi o commit inicial de criação do repositório.
- Todo o resto vai por branch + PR. Quem mergeia é o João.

## Idioma

- **Toda a UI do jogo em pt-BR** (textos, menus, botões, mensagens). Código, nomes de arquivo e
  commits podem ficar em inglês.

## Toolchain

- Godot 4.7.2-stable (`Godot_v4.7.2-stable_win64_console.exe`, instalado via winget) com os export
  templates oficiais 4.7.2 em `%APPDATA%\Godot\export_templates\4.7.2.stable\`.
- Abrir/importar sem editor: `godot --headless --path . --import`
- Export web: `godot --headless --path . --export-release "Web" build/web/index.html`
  (preset em `export_presets.cfg`; `build/` não é versionado; sem threads, para não exigir COOP/COEP).
- Executável console (fora do PATH; usado pelo MCP):
  `C:\Users\User\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`
- **Web export: `variant/thread_support=false` + renderer Compatibility (`gl_compatibility`).**
  Não mudar sem motivo — threads exigem COOP/COEP no host, e o Mobile renderer não roda na web.

## Ferramentas (MCP)

- **MCP `godot`** = [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp) (MIT, grátis),
  via `npx @coding-solo/godot-mcp`, com `GODOT_PATH` apontando para o executável console acima.
  Registrado em `.mcp.json` (escopo de projeto; sem segredos). No Windows o comando é
  `cmd /c npx -y @coding-solo/godot-mcp` (no Git Bash, use `MSYS_NO_PATHCONV=1` ao rodar
  `claude mcp add`, senão `/c` vira `C:/`).
- Excluídos por decisão: Godot MCP Pro (pago) e Summer Engine (fork + conta/créditos).
- **Como verificar:** `/mcp` (ou `claude mcp list`) deve mostrar `godot … ✔ Connected`. Smoke test:
  `get_godot_version` → `4.7.2.stable.official.ed1daf0bf`; `list_projects`/`get_project_info` em
  `C:/projects/summon` → projeto `summon`, 1 cena; `create_scene` + `add_node` numa cena temporária
  em `build/` (não versionado) e apagá-la em seguida. `git status` deve continuar limpo.

## Ferramentas 3D (Fase 0 3D — detalhes e resultados em `docs/fase0-3d.md`)

- **Blender 5.2.3 LTS**, build portátil oficial (sha256 conferido), instalada por usuário em
  `%LOCALAPPDATA%\Programs\Blender\blender-5.2.3-windows-x64\blender.exe`.
- **uv 0.13.5** (instalador oficial Astral) em `%USERPROFILE%\.local\bin`.
- **MCP `blender`** = [ahujasid/mcp-for-blender](https://github.com/ahujasid/mcp-for-blender) (MIT; antigo
  `blender-mcp`): `cmd /c uvx mcp-for-blender` com `DISABLE_TELEMETRY=true` (desliga até o registro
  anônimo de uso). Integrações externas (Poly Haven, Sketchfab, Hyper3D, Hunyuan, Meshy) ficam
  desligadas — várias pedem chave/conta; não ativar sem decisão do João.
  O addon "MCP for Blender" (v1.8) está ativo nas preferências do Blender e sobe o socket na porta
  9876 **só com o Blender aberto com janela** (em `--background` ele não inicia).
- **Como verificar:** `claude mcp list` → `godot` e `blender` ✔ Connected. Smoke do blender (com o
  Blender aberto): `get_scene_info`; `execute_blender_code` criando primitiva + material e exportando
  `.glb`; ler a cena de volta. Smoke 3D do godot: `create_scene` raiz `Node3D` + `add_node`
  `MeshInstance3D` em `build/`, depois apagar.
- **Testes de shader/asset** (Soft Toon, Kenney etc.) acontecem num projeto de laboratório em
  `build/3d/lab` (não versionado). Nada baixado entra no repositório sem decisão do João.
