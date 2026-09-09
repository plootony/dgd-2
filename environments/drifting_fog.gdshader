shader_type fog;

uniform float density : hint_range(0.0, 0.3) = 0.20;
uniform vec3 tint : source_color = vec3(0.72, 0.80, 0.86);
uniform vec2 wind = vec2(0.22, 0.10);

float hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x),
		mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
		mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void fog() {
	vec3 p = (WORLD_POSITION - vec3(wind.x, 0.0, wind.y) * TIME) * vec3(0.32, 0.65, 0.32);
	float wisps = noise3(p) * 0.75 + noise3(p * 2.1) * 0.25;
	vec3 local_pos = WORLD_POSITION - OBJECT_POSITION;
	vec2 edge = 1.0 - smoothstep(SIZE.xz * 0.40, SIZE.xz * 0.50, abs(local_pos.xz));
	float height_fade = 1.0 - smoothstep(1.0, 5.0, WORLD_POSITION.y);
	DENSITY = density * (0.35 + 0.65 * smoothstep(0.25, 0.75, wisps)) * height_fade * edge.x * edge.y;
	ALBEDO = tint;
	// Small ambient contribution keeps the mist readable in shadow and night moods.
	EMISSION = tint * 0.12;
}
