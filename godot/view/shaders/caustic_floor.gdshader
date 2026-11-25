shader_type spatial;
// Fond de bassin éclairé par des caustiques mouvantes (phase 3).
uniform sampler2D albedo_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D caus : hint_default_black, repeat_enable, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(0.25, 0.55, 0.6);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = wpos.xz * 0.5;
	float c = texture(caus, uv + TIME * 0.03).r * 0.6 + texture(caus, uv * 1.4 - TIME * 0.025).r * 0.6;
	ALBEDO = texture(albedo_tex, uv * 2.0).rgb * 0.35;
	EMISSION = tint * c * c * 0.8;
	ROUGHNESS = 0.3;
	METALLIC = 0.4;
}
