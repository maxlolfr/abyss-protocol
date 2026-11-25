shader_type spatial;
// Vue sur l'océan derrière les baies (phase 3) : dégradé de profondeur, rayons de lumière venus de la surface,
// caustiques et particules en suspension. Non éclairé : c'est la lumière de l'océan elle-même.
render_mode unshaded, cull_disabled;
uniform sampler2D caus : hint_default_black, repeat_enable, filter_linear_mipmap;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float h = clamp((wpos.y - 0.6) / 2.4, 0.0, 1.0);
	float along = wpos.x + wpos.z;
	vec3 c = mix(vec3(0.004, 0.03, 0.05), vec3(0.05, 0.22, 0.3), h * h);
	float rays = pow(max(0.0, sin(along * 1.1 + sin(TIME * 0.17) * 0.9) * 0.5 + 0.5), 8.0);
	rays += pow(max(0.0, sin(along * 2.3 - 1.0 + TIME * 0.05) * 0.5 + 0.5), 14.0) * 0.6;
	float ca = texture(caus, vec2(along * 0.3, wpos.y * 0.3) + TIME * 0.012).r;
	float silhouette = smoothstep(0.42, 0.40, h + sin(along * 0.7) * 0.06 + sin(along * 2.9) * 0.025); // relief lointain
	c = mix(c, vec3(0.004, 0.02, 0.03), silhouette * 0.85);
	c += rays * h * vec3(0.06, 0.2, 0.24) + ca * h * 0.05;
	ALBEDO = c;
}
