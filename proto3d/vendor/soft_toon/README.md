# Soft Toon - Godot Shader

Gentle cel shading for painted, storybook 3D in Godot. Light falls in soft bands over a tinted shade, the band edges can wander as if painted by hand, light wraps round the form, thin leaves glow when the sun is behind them, and an ink line runs round every shape. A screen pass adds an ink line on the finished image, a colour grade and a tilt-shift blur that turns the world into a toy diorama.

- Godot 4.x. The material and the outline work in GL Compatibility, Mobile and Forward+. No plugin, no autoload and no global setup.
- Try it in your browser, with sliders and ready-made scenes, before you download: see the itch.io page.

## What is in the folder

| File | What it is |
|---|---|
| `shaders/soft_toon.gdshader` | The material. The main file: copy it into your project |
| `shaders/soft_toon_outline.gdshader` | The ink line: the mesh pushed outwards a fixed number of screen pixels. Goes in `next_pass` of the material |
| `shaders/soft_toon_screen.gdshader` | The screen pass for GL Compatibility: ink line from depth, colour grade, tilt-shift |
| `shaders/soft_toon_screen_vulkan.gdshader` | The same pass for Forward+ and Mobile (their depth runs 0 to 1). Generated, do not edit |
| `shaders/soft_toon_screen_forward.gdshader` | Forward+ only: the creases come from the normals the engine already rendered. Generated, do not edit |
| `soft_toon.gd` | `SoftToon`: make materials, turn a whole scene toon, set a parameter on all of it, add the screen pass |
| `ramps/` | Five ready light ramps (soft, warm, cool, sunset, three-step), one pixel high |
| `demo.gd`, `main.tscn` | The example: a graveyard that cycles through three looks (Meadow, Golden hour, Misty morning) |
| `kenney/` | A few models of Kenney's Graveyard Kit (CC0, see `kenney/LICENSE.txt`) used by the example |

## Use it in your project

**The fast way.** Copy `shaders/` and `soft_toon.gd` into your project, then:

```gdscript
SoftToon.convert(level)                          # every lit material under `level` becomes toon, outlined
SoftToon.set_param(level, &"bands", 4)           # a parameter on every toon material and outline
SoftToon.add_screen_pass($Camera3D)              # the ink line on the finished image
```

`convert` keeps colour, texture, UV scale and offset, vertex colours and emission of the materials it replaces. Unshaded and additive materials (lamps, glows) are left alone. Calling it twice does nothing the second time.

**By hand.** Make a `ShaderMaterial` with `soft_toon.gdshader` on a `MeshInstance3D`, and a second one with `soft_toon_outline.gdshader` in its `Next Pass`. Or `SoftToon.make(texture, color)`.

**The screen pass** is a quad in front of the camera. `SoftToon.add_screen_pass(camera)` adds it and picks the shader for the running renderer. Pass `true` as the second argument to draw the creases from the engine's own normals: cleaner on curved surfaces, but only Forward+ has them. In another renderer it prints a warning and uses the depth-only pass. The result looks the same in every renderer; the normals only change how the creases are found.

Light in the scene comes from the lights of the scene (sun, omni and spot): the shader reads them, nothing is baked. Ambient light is ignored on purpose, so the shade is the shade colour you choose.

## The material

**Surface**: `albedo` and `albedo_texture` are the colour and the picture; `uv_scale` and `uv_offset` move the picture; `use_vertex_color` multiplies the mesh's vertex colours; `emission` is light the surface always keeps.

**Shading**: `shadow_color` is what the surface colour is multiplied by where no light reaches; a cool tint (blue, violet) reads as painted shade. `bands` is the number of lit steps above the shade (1 is two-tone, 3 or 4 a soft gradient) and `band_softness` goes from hard edges to a smooth gradient. `light_threshold` moves where light gives way to shade and `light_wrap` lets light reach round the edge of a form. `use_ramp` and `ramp` read the light along a picture instead of the bands: the left edge is the shade, the right edge the full light, and the colours between tint the light. `crisp_shadows` cuts the sun's shadows and the lamps' pools to a crisp edge; `lamp_cutoff` is where a lamp's light is cut.

**Painted edge**: `edge_wobble` makes the band edges wander as if painted by hand, `wobble_scale` is the size of the wander. The wobble is anchored in the world, so it does not swim when things move.

**Rim**: `rim` is the strength of a rim of light round the silhouette, `rim_color` its colour, `rim_width` how far in it reaches, and `rim_follows_light` goes from a rim all round to one only where a light falls (a backlight).

**Leaves**: `translucency` is light that shines through thin surfaces (leaves, cloth, ears) when it stands behind them; `translucency_color` and `translucency_focus` shape the glow.

## The outline

`outline_color` and `outline_width` (in pixels of a 1080-line screen, the same share of any other size, near or far). `outline_smooth` pushes the line out from the mesh's origin instead of along the normals, which closes the gaps that hard-edged meshes (a box) leave at their corners. `outline_fade_start` and `outline_fade_end` fade the line out with distance.

## The screen pass

**Ink**: `line_color`, `line_width` (in pixels of the rendered image), `depth_threshold` (how far apart two neighbouring depths must be to draw a silhouette), `crease_threshold` and `creases` (0 draws only silhouettes, 1 silhouettes and creases), `fade_start` and `fade_end`.

**Grade**: `saturation`, `contrast`, `tint` and `tint_amount`.

**Miniature**: `tilt_blur` blurs above and below a band of focus, as a tilt-shift lens does. `tilt_focus` is where the sharp band sits (0 top, 1 bottom), `tilt_width` half its height, `tilt_radius` the widest blur.

## Example project

Open this folder in Godot 4.x and run it: `main.tscn` shows a graveyard with a long road and cycles through three looks. A look is only a set of shader parameters (see `LOOKS` in `demo.gd`), so the whole style is in the inspector and in a few lines of code.

## Prior art and credits

The code of this pack is mine. The ideas are shared knowledge of toon shading, and these projects showed them before; I read their code to compare and wrote my own version of each idea:

- **Toon Look Free** by heyheythere (itch.io, CC BY 4.0): bands with a shade colour kept in the emission and the light added on top, ramp textures, hard sun shadows by the width of the shadow's edge, and an outline pushed in screen space. Soft Toon's `convert` and `set_param` follow the same idea of a one-call API.
- **Godot StarRail Shader Demo** by evident0 (MIT): the outline as a screen pass that reads depth and normals.
- **Godot ComicShader** by frankschoeman: the inverted-hull outline (the mesh drawn again with its back faces, pushed outwards).
- The look itself comes from games: The Legend of Zelda: Breath of the Wild, The Wind Waker and Link's Awakening.

What is here that I did not find in them: band edges that wander as if painted by hand, a screen pass that finds creases without Forward+ (it rebuilds the normals from depth), tilt-shift, and a rim that follows the light.

Models: Kenney's Graveyard Kit (CC0).

## License

CC0 (public domain): see `LICENSE.txt`. Credit is appreciated, not required.
