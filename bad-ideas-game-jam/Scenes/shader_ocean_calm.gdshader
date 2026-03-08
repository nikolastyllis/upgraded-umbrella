shader_type spatial;
render_mode cull_back, diffuse_toon, specular_toon;

varying vec3 v_world_pos;

varying float v_wave; // NEW: wave height at this vertex

uniform sampler2D foam_noise; // NEW: grayscale tiling noise
uniform float foam_scale = 0.03;
uniform vec2 foam_speed = vec2(0.02, 0.01);

uniform vec3 foam_color : source_color = vec3(0.9, 0.95, 1.0);
uniform float foam_amount = 1.0;

// Crest foam controls
uniform sampler2D crest_noise;
uniform float crest_scale = 0.03;
uniform float crest_start = 0.25;  // where foam begins (wave height)
uniform float crest_end   = 0.55;  // where foam is strong

// Random foam controls
uniform float patch_threshold = 0.65; // higher = fewer patches
uniform float patch_softness  = 0.08; // edge softness
uniform float time_scale = 1.0;

uniform float wave_amp = 0.35;
uniform float wave_freq = 0.08;
uniform float wave_speed = 1.2;

uniform vec2 wave_dir1 = vec2(1.0, 0.2);
uniform vec2 wave_dir2 = vec2(0.2, 1.0);

uniform sampler2D normal_map1 : hint_normal;
uniform sampler2D normal_map2 : hint_normal;
uniform float normal_strength = 0.8;
uniform vec2 normal_speed1 = vec2(0.03, 0.02);
uniform vec2 normal_speed2 = vec2(-0.02, 0.04);
uniform float normal_tiling = 0.04;

uniform vec3 shallow_color : source_color = vec3(0.05, 0.35, 0.35);
uniform vec3 deep_color    : source_color = vec3(0.01, 0.08, 0.18);
uniform vec3 horizon_color : source_color = vec3(0.05, 0.10, 0.15);

uniform float metallic = 0.0;
uniform float roughness = 0.04;
uniform float fresnel_power = 5.0;

uniform float horizon_start = 200.0;
uniform float horizon_end   = 800.0;

// --- Better procedural noise (gradient noise + fbm + mild domain warp) ---
mat2 rot2(float a) {
	float s = sin(a);
	float c = cos(a);
	// mat2 takes columns as vec2 in Godot shaders
	return mat2(vec2(c, s), vec2(-s, c));
}

vec2 hash22(vec2 p) {
	// returns repeatable pseudo-random vec2 in [0,1)
	p = vec2(dot(p, vec2(127.1, 311.7)),
			 dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453123);
}

float grad_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	// gradient vectors (mapped to [-1,1])
	vec2 g00 = hash22(i + vec2(0.0, 0.0)) * 2.0 - 1.0;
	vec2 g10 = hash22(i + vec2(1.0, 0.0)) * 2.0 - 1.0;
	vec2 g01 = hash22(i + vec2(0.0, 1.0)) * 2.0 - 1.0;
	vec2 g11 = hash22(i + vec2(1.0, 1.0)) * 2.0 - 1.0;

	// dot with distance vectors
	float d00 = dot(g00, f - vec2(0.0, 0.0));
	float d10 = dot(g10, f - vec2(1.0, 0.0));
	float d01 = dot(g01, f - vec2(0.0, 1.0));
	float d11 = dot(g11, f - vec2(1.0, 1.0));

	// smootherstep fade
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

	float x1 = mix(d00, d10, u.x);
	float x2 = mix(d01, d11, u.x);
	return mix(x1, x2, u.y) * 0.5 + 0.5; // map to ~[0,1]
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	mat2 r = rot2(0.55); // rotate each octave to kill axis artifacts

	for (int i = 0; i < 6; i++) {
		v += a * grad_noise(p);
		p = r * p * 2.02;
		a *= 0.5;
	}
	return v;
}

float foam_noise2(vec2 p) {
	// Mild domain warp = removes remaining “cell” hints
	float w = fbm(p * 0.6);
	vec2 warped = p + vec2(w, fbm(p + 11.7)) * 0.35;
	return fbm(warped);
}

void vertex() {
	float t = TIME * time_scale;

	vec2 p = VERTEX.xz;
	float w1 = sin(dot(normalize(wave_dir1), p) * wave_freq + t * wave_speed);
	float w2 = cos(dot(normalize(wave_dir2), p) * (wave_freq * 1.6) + t * (wave_speed * 0.75));
	float w3 = sin(dot(normalize(wave_dir1), p) * (wave_freq * 0.1) + t * wave_speed);
	float wave = (w1 + (w2 - w3)) * wave_amp;
	VERTEX.y += wave;

	v_wave = wave; // NEW

	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Camera distance for horizon fade (use v_world_pos instead of WORLD_POSITION)
	float dist = length(CAMERA_POSITION_WORLD.xz - v_world_pos.xz);
	float horizon_t = smoothstep(horizon_start, horizon_end, dist);

	// Animated normal detail
	vec2 uv = UV * (1.0 / max(normal_tiling, 0.0001));
	vec2 t1 = uv + TIME * normal_speed1;
	vec2 t2 = uv + TIME * normal_speed2;

	vec3 n1 = texture(normal_map1, t1).xyz * 2.0 - 1.0;
	vec3 n2 = texture(normal_map2, t2).xyz * 2.0 - 1.0;
	vec3 nrm_detail  = normalize(mix(n1, n2, 0.5));
	NORMAL = normalize(mix(NORMAL, nrm_detail, normal_strength));

	// Fresnel
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - ndv, fresnel_power);

	// Base water colour (simple deepening with distance)
	vec3 base_col = mix(shallow_color, deep_color, clamp(dist / 600.0, 0.0, 1.0));

	// Horizon blend (kills tiling + sells infinity)
	base_col = mix(base_col, horizon_color, horizon_t);
	
	// --- FOAM ---
	vec2 crest_uv = v_world_pos.xz * crest_scale;
	float crest_n = texture(crest_noise, crest_uv).r;
	float crest = smoothstep(crest_start, crest_end, v_wave);
	float steep = 1.0 - clamp(NORMAL.y, 0.0, 1.0);
	float crest_foam = crest * crest_n * steep;

	// Procedural foam patches (world-space FBM)
	vec2 foam_uv = v_world_pos.xz * foam_scale + TIME * foam_speed;
	float foam_n = texture(foam_noise, foam_uv).r;

	// Turn noise into patch islands
	float patches = smoothstep(patch_threshold, patch_threshold + patch_softness, foam_n);

	// Combine masks
	float foam_mask = clamp((crest_foam * 0.9 + patches * 0.1) * foam_amount, 0.0, 1.0);
	

	ALBEDO = mix(base_col, foam_color, foam_mask);
	METALLIC = metallic;
	ROUGHNESS = roughness;

	// Fake reflection boost via fresnel
	EMISSION = horizon_color * fres * 0.35 + (foam_mask * 0.2);
}