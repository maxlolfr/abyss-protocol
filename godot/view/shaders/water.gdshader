shader_type spatial;
// Eau des bassins (phase 3) : deux couches de normales qui défilent, reflets spéculaires des lampes,
// effet de Fresnel, profondeur sombre et caustiques qui scintillent. Compatible WebGL (moteur de compatibilité).
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;
uniform sampler2D nmap : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D caus : hint_default_black, repeat_enable, filter_linear_mipmap;
uniform vec3 deep : source_color = vec3(0.008, 0.04, 0.055);
uniform vec3 shallow : source_color = vec3(0.06, 0.24, 0.29);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = wpos.xz * 0.4;
	vec3 n1 = texture(nmap, uv + TIME * vec2(0.035, 0.02)).rgb;
	vec3 n2 = texture(nmap, uv * 1.9 - TIME * vec2(0.02, 0.045)).rgb;
	NORMAL_MAP = normalize(n1 + n2 - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.7;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float c = texture(caus, uv * 0.7 + TIME * 0.015).r * texture(caus, uv * 1.1 - TIME * 0.02).r;
	ALBEDO = mix(deep, shallow * 1.4, 0.2 + fres * 0.8);
	EMISSION = shallow * 0.12 + vec3(0.12, 0.38, 0.45) * c * 0.9;
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	ALPHA = mix(0.72, 0.95, fres);
}
