shader_type spatial;
render_mode cull_back, diffuse_toon, specular_toon;

varying vec3 v_world_pos;
varying float v_wave; // macro wave height (stable crest driver)

uniform float time_scale = 1.0;

// ------------------- WAVES (macro + micro) -------------------
uniform float macro_amp   = 0.55;
uniform float macro_freq  = 0.035;   // big swells
uniform float macro_speed = 0.9;

uniform float micro_amp   = 0.10;
uniform float micro_freq  = 0.22;    // small chop
uniform float micro_speed = 1.8;

uniform vec2 wave_dir1 = vec2(1.0, 0.2);
uniform vec2 wave_dir2 = vec2(0.2, 1.0);

// ------------------- NORMALS / COLOUR (yours) -------------------
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

// ------------------- FOAM (two noises + interaction) -------------------
uniform sampler2D foam_noise;   // patch islands (tileable grayscale)
uniform sampler2D crest_noise;  // large screening (tileable grayscale)

uniform vec3 foam_color : source_color = vec3(0.9, 0.95, 1.0);
uniform float foam_amount = 1.0;

// Patch foam
uniform float foam_scale = 0.03;
uniform vec2  foam_speed = vec2(0.02, 0.01);
uniform float patch_threshold = 0.65;
uniform float patch_softness  = 0.08;
uniform float patch_strength  = 0.55;   // how visible the patch layer is

// Crest screening (large subtle bands)
uniform float crest_scale = 0.008;      // larger features
uniform vec2  crest_speed = vec2(0.006, 0.003);
uniform float crest_screen_strength = 0.40; // how much screening affects crest

// Crest from waves (where foam should *tend* to appear)
uniform float crest_start = 0.12;  // lower than before (macro waves are bigger now)
uniform float crest_end   = 0.45;

// Wind-break overlay (small breakup on top of crests)
uniform float wind_scale = 0.07;
uniform vec2  wind_speed = vec2(0.05, 0.02);
uniform float wind_threshold = 0.55;
uniform float wind_softness  = 0.12;
uniform float wind_strength  = 0.65;

void vertex() {
	float t = TIME * time_scale;

	vec2 p = VERTEX.xz;

	// Macro swells (stable)
	float m1 = sin(dot(normalize(wave_dir1), p) * macro_freq + t * macro_speed);
	float m2 = cos(dot(normalize(wave_dir2), p) * (macro_freq * 1.35) + t * (macro_speed * 0.85));
	float macro = (m1 + m2) * 0.5 * macro_amp;

	// Micro chop (adds life, but shouldn't drive crests much)
	float c1 = sin(dot(normalize(wave_dir1), p) * micro_freq + t * micro_speed);
	float c2 = cos(dot(normalize(wave_dir2), p) * (micro_freq * 1.7) + t * (micro_speed * 1.15));
	float micro = (c1 + c2) * 0.5 * micro_amp;

	float wave = macro + micro;
	VERTEX.y += wave;

	v_wave = macro; // IMPORTANT: crests based on macro only (prevents noisy popping)

	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Distance for horizon fade
	float dist = length(CAMERA_POSITION_WORLD.xz - v_world_pos.xz);
	float horizon_t = smoothstep(horizon_start, horizon_end, dist);

	// Animated normal detail (your setup)
	vec2 uv = UV * (1.0 / max(normal_tiling, 0.0001));
	vec2 t1 = uv + TIME * normal_speed1;
	vec2 t2 = uv + TIME * normal_speed2;

	vec3 n1 = texture(normal_map1, t1).xyz * 2.0 - 1.0;
	vec3 n2 = texture(normal_map2, t2).xyz * 2.0 - 1.0;
	vec3 nrm_detail = normalize(mix(n1, n2, 0.5));
	NORMAL = normalize(mix(NORMAL, nrm_detail, normal_strength));

	// Fresnel
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - ndv, fresnel_power);

	// Base colour (yours)
	vec3 base_col = mix(shallow_color, deep_color, clamp(dist / 600.0, 0.0, 1.0));
	base_col = mix(base_col, horizon_color, horizon_t);

	// ------------------- FOAM LAYERS -------------------

	// 1) Patch islands (existing behaviour)
	vec2 foam_uv = v_world_pos.xz * foam_scale + TIME * foam_speed;
	float foam_tex = texture(foam_noise, foam_uv).r;
	float patches = smoothstep(patch_threshold, patch_threshold + patch_softness, foam_tex);
	float foam_patches = patches * patch_strength;

	// 2) Crest mask from macro wave height + steepness
	float crest_height = smoothstep(crest_start, crest_end, v_wave);
	float steep = 1.0 - clamp(NORMAL.y, 0.0, 1.0);
	float crest_base = crest_height * steep;

	// 3) Crest screening (large subtle “bands” that modulate where crests show)
	vec2 crest_uv = v_world_pos.xz * crest_scale + TIME * crest_speed;
	float crest_screen = texture(crest_noise, crest_uv).r;          // 0..1
	crest_screen = smoothstep(0.35, 0.85, crest_screen);            // make it bandier
	float crest_screened = crest_base * mix(1.0, crest_screen, crest_screen_strength);

	// 4) Wind-break overlay (small noisy breakup ONLY on screened crests)
	vec2 wind_uv = v_world_pos.xz * wind_scale + TIME * wind_speed;
	float wind_tex = texture(foam_noise, wind_uv).r;                // reuse foam noise for breakup
	float wind = smoothstep(wind_threshold, wind_threshold + wind_softness, wind_tex);

	// Wind should only appear where crest is already present + screened
	float wind_break = crest_screened * wind * wind_strength;

	// Combine: base patches everywhere + crest foam where waves peak + wind breakup on top
	float foam_mask = clamp((foam_patches + crest_screened * 0.75 + wind_break) * foam_amount, 0.0, 1.0);

	ALBEDO = mix(base_col, foam_color, foam_mask);
	METALLIC = metallic;
	ROUGHNESS = roughness;

	// Reflection-ish boost + a touch of foam lift (keep subtle)
	EMISSION = horizon_color * fres * 0.35 + foam_color * foam_mask * 0.08;

}