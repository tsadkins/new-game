shader_type spatial;
// Grass field with rocky edges. UVs come from world XZ so the pattern stays planted
// in the arena. A faint grid remains so movement still has spatial reference.

uniform sampler2D grass_albedo : source_color, repeat_enable;
uniform sampler2D grass_normal : repeat_enable;
uniform sampler2D rock_albedo : source_color, repeat_enable;
uniform sampler2D rock_normal : repeat_enable;

uniform vec3 grass_tint : source_color = vec3(0.72, 0.82, 0.62);
uniform vec3 rock_tint : source_color = vec3(0.85, 0.82, 0.78);
uniform float grass_uv_scale = 0.18;
uniform float rock_uv_scale = 0.12;
uniform float rock_start = 16.0;
uniform float rock_end = 24.5;
uniform float cell_size = 2.0;
uniform float major_every = 5.0;
uniform float line_pixels = 1.2;
uniform float minor_strength = 0.12;
uniform float major_strength = 0.22;

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

float grid_line(vec2 coord) {
	vec2 dist = abs(fract(coord - 0.5) - 0.5) / fwidth(coord);
	return 1.0 - clamp(min(dist.x, dist.y) / line_pixels, 0.0, 1.0);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 grass_uv = p * grass_uv_scale;
	vec2 rock_uv = p * rock_uv_scale;

	vec3 grass = texture(grass_albedo, grass_uv).rgb * grass_tint;
	vec3 rock = texture(rock_albedo, rock_uv).rgb * rock_tint;
	float grass_rough = texture(grass_normal, grass_uv).a;
	float rock_rough = texture(rock_normal, rock_uv).a;

	float edge = max(abs(p.x), abs(p.y));
	float n = value_noise(p * 0.12);
	float rock_blend = smoothstep(rock_start, rock_end, edge + n * 2.5);

	vec3 col = mix(grass, rock, rock_blend);
	col *= 0.92 + 0.12 * value_noise(p * 0.55);

	float minor = grid_line(p / cell_size);
	float major = grid_line(p / (cell_size * major_every));
	col = mix(col, col * 0.65, minor * minor_strength);
	col = mix(col, col * 0.5, major * major_strength);

	ALBEDO = col;
	ROUGHNESS = mix(grass_rough, rock_rough, rock_blend);
}
