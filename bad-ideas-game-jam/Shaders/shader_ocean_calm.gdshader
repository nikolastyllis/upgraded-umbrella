shader_type spatial;
render_mode cull_back, diffuse_toon, specular_toon;

varying vec3 v_world_pos;
varying float v_wave;

// ============================================================
// GROUPS (Inspector)
// ============================================================

group_uniforms OceanFlow;
uniform float time_scale = 1.0;
uniform float ocean_speed = 6.0;                 // metres/sec illusion
uniform vec3  ocean_dir   = vec3(0.0, 0.0, -1.0);// direction water flows (world)

group_uniforms Waves;
uniform float macro_amp   = 0.55;
uniform float macro_freq  = 0.035;
uniform float macro_speed = 0.9;
uniform float micro_amp   = 0.10;
uniform float micro_freq  = 0.22;
uniform float micro_speed = 1.8;
uniform vec2 wave_dir1 = vec2(1.0, 0.2);
uniform vec2 wave_dir2 = vec2(0.2, 1.0);

group_uniforms SurfaceNormals;
uniform sampler2D normal_map1 : hint_normal;
uniform sampler2D normal_map2 : hint_normal;
uniform float normal_strength = 0.8;
uniform vec2 normal_speed1 = vec2(0.03, 0.02);
uniform vec2 normal_speed2 = vec2(-0.02, 0.04);
uniform float normal_tiling = 0.04;

group_uniforms Colour;
uniform vec3 shallow_color : source_color = vec3(0.05, 0.35, 0.35);
uniform vec3 deep_color    : source_color = vec3(0.01, 0.08, 0.18);
uniform vec3 horizon_color : source_color = vec3(0.05, 0.10, 0.15);
uniform float metallic = 0.0;
uniform float roughness = 0.04;
uniform float fresnel_power = 5.0;
uniform float horizon_start = 200.0;
uniform float horizon_end   = 800.0;

group_uniforms FoamPatches;
uniform sampler2D foam_noise;   // tileable grayscale
uniform vec3 foam_color : source_color = vec3(0.9, 0.95, 1.0);
uniform float foam_amount = 1.0;
uniform float foam_scale = 0.03;
uniform vec2  foam_speed = vec2(0.02, 0.01);
uniform float patch_threshold = 0.65;
uniform float patch_softness  = 0.08;
uniform float patch_strength  = 0.55;

group_uniforms FoamCrests;
uniform sampler2D crest_noise;  // large screening grayscale
uniform float crest_scale = 0.008;
uniform vec2  crest_speed = vec2(0.006, 0.003);
uniform float crest_screen_strength = 0.40;
uniform float crest_start = 0.12;
uniform float crest_end   = 0.45;

group_uniforms FoamWindBreak;
uniform float wind_scale = 0.07;
uniform vec2  wind_speed = vec2(0.05, 0.02);
uniform float wind_threshold = 0.55;
uniform float wind_softness  = 0.12;
uniform float wind_strength  = 0.65;

group_uniforms ShipWake;
uniform vec3 ship_pos = vec3(0.0, 0.0, 0.0);
uniform vec3 ship_fwd = vec3(0.0, 0.0, -1.0);
uniform float wake_length = 100.0;
uniform float wake_width_start = 8.0;
uniform float wake_width_end = 30.0;
uniform float wake_edge_soft = 2.5;
uniform float wake_strength = 1.0;
uniform sampler2D wake_edge_noise;          // separate grayscale noise
uniform float wake_edge_noise_scale = 0.18; // smaller features
uniform vec2  wake_edge_noise_speed = vec2(0.12, 0.05);
uniform float wake_edge_band = 0.35;        // how much of the half-width counts as "edge"
uniform float wake_edge_churn = 0.9;        // strength of edge randomness
uniform float wake_noise_scale = 0.08;
uniform vec2  wake_noise_speed = vec2(0.08, 0.03);
uniform float wake_centerline = 0.55;
uniform float wake_falloff_pow = 1.2;

// ============================================================
// HELPERS
// ============================================================

vec2 flow_offset() {
	// world-space flow direction in XZ
	vec2 d = normalize(ocean_dir.xz + vec2(1e-6, 0.0));
	return d * (TIME * time_scale * ocean_speed);
}

// Wake mask in ship-local space, but sampling the moving ocean field
float wake_mask(vec3 world_pos) {
	vec2 rel = world_pos.xz - ship_pos.xz;

	vec2 f = normalize(ship_fwd.xz + vec2(1e-6, 0.0));
	vec2 b = -f;                 // behind direction
	vec2 r = vec2(-f.y, f.x);    // right direction

	float z = dot(rel, b);       // 0 at ship, positive behind
	float x = dot(rel, r);

	if (z < 0.0 || z > wake_length) return 0.0;

	float t = z / wake_length;
	float half_w = mix(wake_width_start, wake_width_end, t) * 0.5;

	// Base cone
	float edge = 1.0 - smoothstep(half_w - wake_edge_soft, half_w + wake_edge_soft, abs(x));
	float fade_back = pow(1.0 - t, wake_falloff_pow);

	// Centreline streak
	float center = 1.0 - smoothstep(0.0, half_w, abs(x));
	center = pow(center, 2.0) * wake_centerline;

	// Stream direction for moving foam (anchored cone)
	float scroll = TIME * time_scale * ocean_speed;
	vec2 stream = b * scroll;

	// Main breakup inside wake (bigger shapes)
	vec2 nuv = (world_pos.xz + stream) * wake_noise_scale + TIME * wake_noise_speed;
	float n = texture(foam_noise, nuv).r;
	float breakup = smoothstep(0.35, 0.85, n);

	// --- Edge-only churn band ---
	// edge_band = 0 in centre, 1 near edges
	float nx = abs(x) / max(half_w, 1e-4); // 0..1 across half-width
	float edge_band = smoothstep(1.0 - wake_edge_band, 1.0, nx);

	// Separate noise for churning edges (smaller, more chaotic)
	vec2 euv = (world_pos.xz + stream * 1.35) * wake_edge_noise_scale + TIME * wake_edge_noise_speed;
	float en = texture(wake_edge_noise, euv).r;
	// sharpen into turbulent clumps
	float edge_turb = smoothstep(0.40, 0.92, en);

	// Add “streaking” by mixing in a second shifted sample
	float en2 = texture(wake_edge_noise, euv + r * 0.35 + b * 0.25).r;
	edge_turb = max(edge_turb, smoothstep(0.45, 0.95, en2));

	// Make turbulence strongest near ship, still present along wake
	float near_boost = mix(0.65, 1.25, smoothstep(1.0, 0.0, t));

	// Compose wake:
	float m = edge * fade_back;

	// Internal breakup modulates base wake
	m *= mix(0.65, 1.0, breakup);

	// Add centreline
	m += center * fade_back;

	// Multiply extra churn into edges (this is the “random churning”)
	// edge_band gates it to edges; edge_turb provides randomness
	m *= mix(1.0, 1.0 + edge_turb * wake_edge_churn * near_boost, edge_band);

	return clamp(m, 0.0, 1.0);
}

// ============================================================
// SHADER
// ============================================================

void vertex() {
	float t = TIME * time_scale;

	vec2 p = VERTEX.xz;

	// Macro swells
	float m1 = sin(dot(normalize(wave_dir1), p) * macro_freq + t * macro_speed);
	float m2 = cos(dot(normalize(wave_dir2), p) * (macro_freq * 1.35) + t * (macro_speed * 0.85));
	float macro = (m1 + m2) * 0.5 * macro_amp;

	// Micro chop
	float c1 = sin(dot(normalize(wave_dir1), p) * micro_freq + t * micro_speed);
	float c2 = cos(dot(normalize(wave_dir2), p) * (micro_freq * 1.7) + t * (micro_speed * 1.15));
	float micro = (c1 + c2) * 0.5 * micro_amp;

	VERTEX.y += (macro + micro);

	// Crests driven by macro only (stable)
	v_wave = macro;

	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 flow = flow_offset();

	// Distance for horizon fade
	float dist = length(CAMERA_POSITION_WORLD.xz - v_world_pos.xz);
	float horizon_t = smoothstep(horizon_start, horizon_end, dist);

	// Animated normal detail
	vec2 uv = UV * (1.0 / max(normal_tiling, 0.0001));
	// Make normal scrolling consistent with ocean flow
	uv -= flow * normal_tiling;

	vec2 t1 = uv + TIME * normal_speed1;
	vec2 t2 = uv + TIME * normal_speed2;

	vec3 n1 = texture(normal_map1, t1).xyz * 2.0 - 1.0;
	vec3 n2 = texture(normal_map2, t2).xyz * 2.0 - 1.0;
	vec3 nrm_detail = normalize(mix(n1, n2, 0.5));
	NORMAL = normalize(mix(NORMAL, nrm_detail, normal_strength));

	// Fresnel
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - ndv, fresnel_power);

	// Base colour
	vec3 base_col = mix(shallow_color, deep_color, clamp(dist / 600.0, 0.0, 1.0));
	base_col = mix(base_col, horizon_color, horizon_t);

	// ------------------- FOAM LAYERS (all consistent flow) -------------------
	// Use world pos minus flow so foam appears to stream past ship
	vec2 wp = (v_world_pos.xz - flow);

	// 1) Patch islands
	vec2 foam_uv = wp * foam_scale + TIME * foam_speed;
	float foam_tex = texture(foam_noise, foam_uv).r;
	float patches = smoothstep(patch_threshold, patch_threshold + patch_softness, foam_tex);
	float foam_patches = patches * patch_strength;

	// 2) Crest base from wave + steepness
	float crest_height = smoothstep(crest_start, crest_end, v_wave);
	float steep = 1.0 - clamp(NORMAL.y, 0.0, 1.0);
	float crest_base = crest_height * steep;

	// 3) Crest screening (large bands)
	vec2 crest_uv = wp * crest_scale + TIME * crest_speed;
	float crest_screen = texture(crest_noise, crest_uv).r;
	crest_screen = smoothstep(0.35, 0.85, crest_screen);
	float crest_screened = crest_base * mix(1.0, crest_screen, crest_screen_strength);

	// 4) Wind breakup on top
	vec2 wind_uv = wp * wind_scale + TIME * wind_speed;
	float wind_tex = texture(foam_noise, wind_uv).r;
	float wind = smoothstep(wind_threshold, wind_threshold + wind_softness, wind_tex);
	float wind_break = crest_screened * wind * wind_strength;

	float foam_mask = clamp((foam_patches + crest_screened * 0.75 + wind_break) * foam_amount, 0.0, 1.0);

	// ------------------- WAKE -------------------
	float w = wake_mask(v_world_pos);
	float foam_with_wake = clamp(foam_mask + w * wake_strength, 0.0, 1.0);

	// Slight wake brightening
	vec3 wake_tint = mix(vec3(1.0), foam_color, 0.35);
	vec3 col_with_wake = mix(base_col, wake_tint, w * 0.25);

	// Final
	ALBEDO = mix(col_with_wake, foam_color, foam_with_wake);
	EMISSION = horizon_color * fres * 0.35 + foam_color * foam_with_wake * 0.10;
	METALLIC = metallic;
	ROUGHNESS = roughness;
}