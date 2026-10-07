shader_type spatial;
// Earthy ground with mottled dirt and a faint grid. Everything is computed from
// world position, so the pattern stays fixed in the world and gives a sense of
// where things are (and of motion) when the camera follows the player.

uniform vec3 base_color : source_color = vec3(0.42, 0.31, 0.2);
uniform vec3 line_color : source_color = vec3(0.26, 0.18, 0.11);
// Size of one grid cell in world units.
uniform float cell_size = 2.0;
// Every Nth line is drawn stronger.
uniform float major_every = 5.0;
// Approximate line thickness in screen pixels.
uniform float line_pixels = 1.5;
uniform float minor_strength = 0.3;
uniform float major_strength = 0.6;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// 1.0 on a grid line, fading to 0.0 away from it, with a width that stays constant on screen.
float grid_line(vec2 coord) {
	vec2 dist = abs(fract(coord - 0.5) - 0.5) / fwidth(coord);
	return 1.0 - clamp(min(dist.x, dist.y) / line_pixels, 0.0, 1.0);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;

	// Patchy dirt: large blotches, medium variation, and fine grain.
	float n = value_noise(p * 0.35) * 0.5 + value_noise(p * 1.7) * 0.3 + value_noise(p * 9.0) * 0.2;
	vec3 col = base_color * (0.78 + 0.44 * n);

	float minor = grid_line(p / cell_size);
	float major = grid_line(p / (cell_size * major_every));
	col = mix(col, line_color, minor * minor_strength);
	col = mix(col, line_color, major * major_strength);

	ALBEDO = col;
	ROUGHNESS = 1.0;
}
