shader_type canvas_item;
// Vignettage et étalonnage léger (phase 3) : bords assombris, regard guidé vers le centre.
uniform float strength = 0.6;
void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.25, 1.0);
	float v = smoothstep(0.32, 0.85, length(d));
	COLOR = vec4(0.0, 0.01, 0.02, v * strength);
}
