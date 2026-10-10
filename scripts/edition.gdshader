shader_type canvas_item;

// Mod (joker) editions, like the original game:
// 1 foil - moving silver shine, 2 holographic - rainbow tint, 3 polychrome - shifting hues, 4 negative - inverted colors.
uniform int mode = 0;

vec3 hue_shift(vec3 col, float a) {
	const vec3 k = vec3(0.57735);
	float ca = cos(a * 6.2831);
	return col * ca + cross(k, col) * sin(a * 6.2831) + k * dot(k, col) * (1.0 - ca);
}

void fragment() {
	vec4 c = COLOR;
	vec2 p = FRAGCOORD.xy;
	float t = TIME;
	if (mode == 1) {
		float lum = dot(c.rgb, vec3(0.3, 0.55, 0.15));
		c.rgb = mix(c.rgb, vec3(lum) * vec3(0.9, 0.95, 1.05), 0.45);
		float s = sin((p.x + p.y) * 0.045 - t * 2.2);
		c.rgb += vec3(0.55, 0.6, 0.7) * smoothstep(0.82, 1.0, s);
	} else if (mode == 2) {
		vec3 rb = 0.5 + 0.5 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + (p.x - p.y) * 0.008 + t * 0.25));
		c.rgb = mix(c.rgb, rb, 0.32);
	} else if (mode == 3) {
		c.rgb = clamp(hue_shift(c.rgb, (p.x + p.y) * 0.006 + t * 0.35), 0.0, 1.0);
	} else if (mode == 4) {
		c.rgb = vec3(1.0) - c.rgb;
	}
	COLOR = c;
}
