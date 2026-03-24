shader_type spatial;
render_mode cull_back, diffuse_toon, specular_toon;

varying vec3 v_world_pos;
varying float v_wave;

// NEW: store geometric world normal so foam doesn't depend on normal-map/view weirdness
varying vec3 v_geo_n_world;

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
// NEW OPTIONAL TUNING (won't break naming conventions)
// ============================================================

group_uniforms FoamTuning;
uniform float foam_brightness : hint_range(0.0, 1.5) = 0.65;      // foam is too bright -> lower this
uniform float foam_distance_fade_start = 220.0;                   // foam fades with distance
uniform float foam_distance_fade_end   = 900.0;
uniform float foam_wake_boost = 1.0;                               // extra boost only for wake

// ============================================================
// HELPERS
// ============================================================

vec2 flow_offset() {
	vec2 d = normalize(ocean_dir.xz + vec2(1e-6, 0.0));
	return d * (TIME * time_scale * ocean_speed);
}

// Cheaper wake mask: fewer samples + anchored cone + edge churn
float wake_mask(vec3 world_pos, vec2 flow) {
	vec2 rel = world_pos.xz - ship_pos.xz;

	vec2 f = normalize(ship_fwd.xz + vec2(1e-6, 0.0));
	vec2 b = -f;
	vec2 r = vec2(-f.y, f.x);

	float z = dot(rel, b);
	float x = dot(rel, r);

	// only behind ship
	if (z < 0.0 || z > wake_length) return 0.0;

	float t = z / wake_length;
	float half_w = mix(wake_width_start, wake_width_end, t) * 0.5;

	// cone edge + fade back
	float edge = 1.0 - smoothstep(half_w - wake_edge_soft, half_w + wake_edge_soft, abs(x));
	float fade_back = pow(1.0 - t, wake_falloff_pow);

	// centreline
	float center = 1.0 - smoothstep(0.0, half_w, abs(x));
	center = center * center * wake_centerline;

	// stream noise along wake direction (anchored cone, moving foam)
	float scroll = TIME * time_scale * ocean_speed;
	vec2 stream = b * scroll;

	// inside breakup (1 sample)
	vec2 nuv = (world_pos.xz + stream - flow) * wake_noise_scale + TIME * wake_noise_speed;
	float n = texture(foam_noise, nuv).r;
	float breakup = smoothstep(0.40, 0.85, n);

	// edge band factor
	float nx = abs(x) / max(half_w, 1e-4);
	float edge_band = smoothstep(1.0 - wake_edge_band, 1.0, nx);

	// edge churn noise (1 sample only)
	vec2 euv = (world_pos.xz + stream - flow) * wake_edge_noise_scale + TIME * wake_edge_noise_speed;
	float en = texture(wake_edge_noise, euv).r;
	float churn = smoothstep(0.45, 0.92, en);

	float m = edge * fade_back;
	m *= mix(0.70, 1.0, breakup);
	m += center * fade_back;

	// churn only on edges
	m *= mix(1.0, 1.0 + churn * wake_edge_churn, edge_band);

	return clamp(m, 0.0, 1.0);
}

// ============================================================
// SHADER
// ============================================================

void vertex() {
	float t = TIME * time_scale;

	// World pos
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Store geometric world normal BEFORE normal maps
	v_geo_n_world = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);

	vec2 p = VERTEX.xz;

	// Macro swells (stable)
	float m1 = sin(dot(normalize(wave_dir1), p) * macro_freq + t * macro_speed);
	float m2 = cos(dot(normalize(wave_dir2), p) * (macro_freq * 1.35) + t * (macro_speed * 0.85));
	float macro = (m1 + m2) * 0.5 * macro_amp;

	// Micro chop
	float c1 = sin(dot(normalize(wave_dir1), p) * micro_freq + t * micro_speed);
	float c2 = cos(dot(normalize(wave_dir2), p) * (micro_freq * 1.7) + t * (micro_speed * 1.15));
	float micro = (c1 + c2) * 0.5 * micro_amp;

	VERTEX.y += (macro + micro);

	// Foam crests driven by macro only (stable)
	v_wave = macro;
}

void fragment() {
	vec2 flow = flow_offset();

	// Distance for horizon fade
	float dist = length(CAMERA_POSITION_WORLD.xz - v_world_pos.xz);
	float horizon_t = smoothstep(horizon_start, horizon_end, dist);

	// Base colour
	vec3 base_col = mix(shallow_color, deep_color, clamp(dist / 600.0, 0.0, 1.0));
	base_col = mix(base_col, horizon_color, horizon_t);

	// ------------------------------------------------------------
	// Normal mapping (visual detail), but keep foam logic on geo normal
	// ------------------------------------------------------------
	vec2 uv = UV * (1.0 / max(normal_tiling, 0.0001));
	uv -= flow * normal_tiling;

	vec2 t1 = uv + TIME * normal_speed1;
	vec2 t2 = uv + TIME * normal_speed2;

	vec3 n1 = texture(normal_map1, t1).xyz * 2.0 - 1.0;
	vec3 n2 = texture(normal_map2, t2).xyz * 2.0 - 1.0;
	vec3 nrm_detail = normalize(mix(n1, n2, 0.5));

	NORMAL = normalize(mix(NORMAL, nrm_detail, normal_strength));

	// Fresnel (used only subtly; should not drive foam)
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - ndv, fresnel_power);

	// ------------------------------------------------------------
	// FOAM MASKS (world flow-consistent, view-stable)
	// ------------------------------------------------------------
	vec2 wp = (v_world_pos.xz - flow);

	// Patch islands (1 sample)
	vec2 foam_uv = wp * foam_scale + TIME * foam_speed;
	float foam_tex = texture(foam_noise, foam_uv).r;
	float patches = smoothstep(patch_threshold, patch_threshold + patch_softness, foam_tex);
	float foam_patches = patches * patch_strength;

	// Crest base: use v_geo_n_world.y, not perturbed NORMAL.y
	float crest_height = smoothstep(crest_start, crest_end, v_wave);
	float steep = 1.0 - clamp(v_geo_n_world.y, 0.0, 1.0);
	float crest_base = crest_height * steep;

	// Crest screening (1 sample)
	vec2 crest_uv = wp * crest_scale + TIME * crest_speed;
	float crest_screen = texture(crest_noise, crest_uv).r;
	crest_screen = smoothstep(0.35, 0.85, crest_screen);
	float crest_screened = crest_base * mix(1.0, crest_screen, crest_screen_strength);

	// Wind breakup on top (reuse foam_noise, 1 sample)
	vec2 wind_uv = wp * wind_scale + TIME * wind_speed;
	float wind_tex = texture(foam_noise, wind_uv).r;
	float wind = smoothstep(wind_threshold, wind_threshold + wind_softness, wind_tex);
	float wind_break = crest_screened * wind * wind_strength;

	// Combine foam (clamped)
	float foam_mask = clamp((foam_patches + crest_screened * 0.75 + wind_break) * foam_amount, 0.0, 1.0);

	// Wake (cheaper + stable) - uses 2 samples total (foam_noise + wake_edge_noise)
	float w = wake_mask(v_world_pos, flow);
	float foam_with_wake = clamp(foam_mask + w * wake_strength * foam_wake_boost, 0.0, 1.0);

	// Distance fade foam (prevents bright speckling on horizon)
	float foam_fade = 1.0 - smoothstep(foam_distance_fade_start, foam_distance_fade_end, dist);
	foam_with_wake *= foam_fade;

	// ------------------------------------------------------------
	// FOAM SHADING (fix "always too bright")
	// ------------------------------------------------------------
	// Foam should not be emissive; it should be slightly darker and sit in water.
	// Also slightly reduce foam in the far horizon blend.
	vec3 foam_col = foam_color * foam_brightness;
	foam_col = mix(foam_col, horizon_color, horizon_t * 0.25);

	// Wake tint: only a subtle lift (not glowing)
	vec3 col_with_wake = mix(base_col, foam_col, w * 0.18);

	ALBEDO = mix(col_with_wake, foam_col, foam_with_wake);

	// Minimal emission: keep a gentle fresnel only (no foam glow)
	EMISSION = horizon_color * fres * 0.12;

	METALLIC = metallic;
	ROUGHNESS = roughness;
}