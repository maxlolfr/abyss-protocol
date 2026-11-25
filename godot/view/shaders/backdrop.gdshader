shader_type spatial;
// Abysse sous la station (phase 3) : halo bleu profond sous la salle, noir sur les bords. Donne la profondeur.
render_mode unshaded;
uniform vec2 center = vec2(8.0, 7.0);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float d = length(wpos.xz - center);
	float g = exp(-d * d / 260.0);
	ALBEDO = mix(vec3(0.004, 0.008, 0.014), vec3(0.03, 0.09, 0.13), g);
}
