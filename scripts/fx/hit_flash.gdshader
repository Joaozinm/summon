shader_type canvas_item;
// Battle sprite shader: identity-colour rim (readability over the busy arena floor), hit flash,
// and a debug silhouette mode (everything black) for the silhouette readability test.
// Modulate (e.g. the death fade) is applied at the end, rim included.

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 outline_color : source_color = vec4(0.0);
uniform float outline_texels = 3.0;
uniform bool silhouette = false;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec2 d = TEXTURE_PIXEL_SIZE * outline_texels;
	float n = 0.0;
	n = max(n, texture(TEXTURE, UV + vec2(d.x, 0.0)).a);
	n = max(n, texture(TEXTURE, UV - vec2(d.x, 0.0)).a);
	n = max(n, texture(TEXTURE, UV + vec2(0.0, d.y)).a);
	n = max(n, texture(TEXTURE, UV - vec2(0.0, d.y)).a);
	n = max(n, texture(TEXTURE, UV + d * 0.7071).a);
	n = max(n, texture(TEXTURE, UV - d * 0.7071).a);
	n = max(n, texture(TEXTURE, UV + vec2(d.x, -d.y) * 0.7071).a);
	n = max(n, texture(TEXTURE, UV + vec2(-d.x, d.y) * 0.7071).a);
	float rim = clamp(n - t.a, 0.0, 1.0) * outline_color.a;
	vec3 body = silhouette ? vec3(0.0) : mix(t.rgb * tint.rgb, vec3(1.0), flash);
	vec3 ring = silhouette ? vec3(0.0) : outline_color.rgb;
	float a = t.a + rim * (1.0 - t.a);
	vec3 rgb = (body * t.a + ring * rim * (1.0 - t.a)) / max(a, 0.0001);
	COLOR = vec4(rgb, a * tint.a);
}
