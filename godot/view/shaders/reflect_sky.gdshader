shader_type sky;
// Ciel de réflexion (phase 3) : jamais visible, il sert seulement aux reflets des métaux.
// Plafond sombre traversé de rampes lumineuses, horizon acier, sol noir : les surfaces métalliques
// cessent d'être noires et prennent l'aspect d'acier brossé d'une salle industrielle.
void sky() {
	vec3 d = EYEDIR;
	float up = clamp(d.y, -1.0, 1.0);
	vec3 col = mix(vec3(0.05, 0.06, 0.07), vec3(0.2, 0.24, 0.27), smoothstep(-0.3, 0.25, up));
	float ang = atan(d.x, d.z);
	float strips = smoothstep(0.82, 0.97, sin(ang * 6.0)) * smoothstep(0.35, 0.75, up);
	col += strips * vec3(1.3, 1.25, 1.15);
	col += smoothstep(0.1, -0.05, abs(up - 0.08)) * vec3(0.05, 0.16, 0.2); // reflet bleuté des baies
	COLOR = col;
}
