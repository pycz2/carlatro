shader_type canvas_item;

// Balatro-style swirling paint background, tinted like asphalt and tail lights.
uniform vec4 col_a : source_color = vec4(0.06, 0.20, 0.22, 1.0);
uniform vec4 col_b : source_color = vec4(0.62, 0.10, 0.10, 1.0);
uniform vec4 col_c : source_color = vec4(0.04, 0.05, 0.07, 1.0);

void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= 1.7778;
	uv = floor(uv * 260.0) / 260.0; // subtle pixelation
	float t = TIME * 0.12;
	float r = length(uv);
	float a = atan(uv.y, uv.x + 1e-4) + sin(r * 5.0 - t * 3.0) * 0.7 + t;
	vec2 p = vec2(cos(a), sin(a)) * r * 4.0;
	for (int i = 0; i < 4; i++) {
		p += vec2(sin(p.y * 1.3 + t * 2.0), cos(p.x * 1.1 - t * 1.7)) * 0.55;
	}
	float v = sin(p.x + p.y) * 0.5 + 0.5;
	float w = sin(length(p) * 1.6 - t * 2.0) * 0.5 + 0.5;
	vec3 col = mix(col_c.rgb, col_a.rgb, v);
	col = mix(col, col_b.rgb, smoothstep(0.6, 0.95, w) * 0.75);
	col *= 0.75 + 0.35 * (1.0 - smoothstep(0.2, 0.9, r));
	col = floor(col * 28.0) / 28.0;
	COLOR = vec4(col, 1.0);
}
