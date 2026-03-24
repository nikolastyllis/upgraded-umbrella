shader_type sky;

/*
Sky (Godot 4.6.x) — texture driven stylised clouds
- Stable day/dusk/night weights (no dusk->night leakage)
- Cumulus + Cirrus texture layers
- Thickness-based shading (stable around dusk)
- Optional stars
*/

uniform float sun_elev : hint_range(-1.0, 1.0) = -1.0;
uniform float exposure : hint_range(0.2, 2.0) = 1.0;

// Toon banding
uniform float band_steps : hint_range(2.0, 16.0) = 6.0;
uniform float band_softness : hint_range(0.0, 0.25) = 0.06;

// Horizon shaping
uniform float horizon_height : hint_range(-0.2, 0.4) = 0.05;
uniform float horizon_softness : hint_range(0.001, 0.35) = 0.14;

// Sun disc / halo
uniform float sun_size : hint_range(0.001, 0.09) = 0.02;
uniform float sun_halo : hint_range(0.0, 0.7) = 0.18;
uniform float sun_disc_boost : hint_range(0.0, 6.0) = 1.4;

// Clouds (procedural controls kept for naming compatibility)
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.55; // acts as coverage
uniform float cloud_scale : hint_range(0.2, 8.0) = 1.8;
uniform float cloud_speed : hint_range(0.0, 2.0) = 0.22;
uniform vec2  cloud_wind_dir = vec2(1.0, 0.3);
uniform float cloud_contrast : hint_range(0.5, 3.0) = 1.35;
uniform float cloud_softness : hint_range(0.0, 0.35) = 0.10;

// Night cloud controls (kept)
uniform float night_clouds : hint_range(0.0, 1.0) = 1.0;
uniform vec3 cloud_day_color   : source_color = vec3(0.95, 0.96, 1.0);
uniform vec3 cloud_dusk_color  : source_color = vec3(1.0, 0.70, 0.45);
uniform vec3 cloud_night_color : source_color = vec3(0.07, 0.09, 0.12);
uniform vec3 cloud_shadow_color: source_color = vec3(0.02, 0.03, 0.01);
uniform float night_cloud_darkness : hint_range(0.0, 2.0) = 1.25;

// Cloud lighting
uniform float cloud_light_strength : hint_range(0.0, 2.0) = 0.9;
uniform float cloud_shadow_strength : hint_range(0.0, 2.0) = 1.15;
uniform float cloud_anisotropy : hint_range(0.0, 1.0) = 0.65;
uniform float cloud_banding : hint_range(1.0, 10.0) = 4.0;

// NEW: Texture-driven clouds
uniform sampler2D cumulus_tex;
uniform sampler2D cumulus_detail_tex;
uniform sampler2D cirrus_tex;

uniform float cirrus_amount : hint_range(0.0, 1.0) = 0.35;
uniform float cirrus_scale  : hint_range(0.2, 10.0) = 3.2;
uniform float cirrus_speed  : hint_range(0.0, 2.0) = 0.28;

// Stars
uniform float stars : hint_range(0.0, 1.0) = 0.7;
uniform float star_density : hint_range(0.2, 3.0) = 1.2;

// Palette (kept)
uniform vec3 day_zenith   : source_color = vec3(0.18, 0.45, 0.95);
uniform vec3 day_horizon  : source_color = vec3(0.70, 0.85, 1.00);
uniform vec3 dusk_zenith  : source_color = vec3(0.10, 0.05, 0.25);
uniform vec3 dusk_horizon : source_color = vec3(0.95, 0.42, 0.22);
uniform vec3 night_zenith : source_color = vec3(0.02, 0.02, 0.06);
uniform vec3 night_horizon: source_color = vec3(0.04, 0.05, 0.10);
uniform vec3 ground_tint  : source_color = vec3(0.02, 0.02, 0.03);

// ------------------------------------------------------------
// Helpers
// ------------------------------------------------------------
float sat(float x) { return clamp(x, 0.0, 1.0); }

float soft_steps(float x, float steps, float softness) {
	float s = max(steps, 1.0);
	float fx = x * s;
	float q0 = floor(fx) / s;
	float q1 = (floor(fx) + 1.0) / s;
	float f = fract(fx);
	float w = smoothstep(0.5 - softness, 0.5 + softness, f);
	return mix(q0, q1, w);
}

float grad_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 a = fract(sin(vec2(dot(i, vec2(127.1, 311.7)), dot(i, vec2(269.5, 183.3)))) * 43758.5453123);
	vec2 b = fract(sin(vec2(dot(i + vec2(1,0), vec2(127.1, 311.7)), dot(i + vec2(1,0), vec2(269.5, 183.3)))) * 43758.5453123);
	vec2 c = fract(sin(vec2(dot(i + vec2(0,1), vec2(127.1, 311.7)), dot(i + vec2(0,1), vec2(269.5, 183.3)))) * 43758.5453123);
	vec2 d = fract(sin(vec2(dot(i + vec2(1,1), vec2(127.1, 311.7)), dot(i + vec2(1,1), vec2(269.5, 183.3)))) * 43758.5453123);

	float va = dot(a * 2.0 - 1.0, f - vec2(0,0));
	float vb = dot(b * 2.0 - 1.0, f - vec2(1,0));
	float vc = dot(c * 2.0 - 1.0, f - vec2(0,1));
	float vd = dot(d * 2.0 - 1.0, f - vec2(1,1));

	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(va, vb, u.x), mix(vc, vd, u.x), u.y) * 0.5 + 0.5;
}

float stars_mask(vec3 dir) {
	float u = atan(dir.z, dir.x) / 6.2831853 + 0.5;
	float v = asin(clamp(dir.y, -1.0, 1.0)) / 3.1415926 + 0.5;
	vec2 p = vec2(u, v) * (400.0 * star_density);

	float n = grad_noise(p);
	float s1 = smoothstep(0.985, 1.0, n);
	float tw = grad_noise(p * 0.25 + TIME * 0.15);
	s1 *= mix(0.7, 1.2, tw);
	return s1;
}

// Cloud-plane mapping: stable, but clamped to avoid horizon explosion
vec2 cloud_uv(vec3 dir, float scale, vec2 drift) {
	float y = max(0.18, abs(dir.y) + 0.18);
	vec2 vp = dir.xz / y;
	return vp * scale + drift;
}

// ------------------------------------------------------------
// Sky
// ------------------------------------------------------------
void sky() {
	vec3 dir = normalize(EYEDIR);

	// Sun elevation driver
	float elev = (sun_elev < 0.0)
	? clamp(LIGHT0_DIRECTION.y * 0.5 + 0.5, 0.0, 1.0)
	: clamp(sun_elev, 0.0, 1.0);

	// --- Stable weights (dusk doesn't inherit night) ---
	float day_w   = smoothstep(0.56, 0.90, elev);
	float night_w = smoothstep(0.46, 0.34, elev);
	float dusk_band = 1.0 - smoothstep(0.00, 0.18, abs(elev - 0.5));
	float dusk_w = sat(dusk_band * (1.0 - night_w * 0.90) * (1.0 - day_w * 0.25));

	// --- FAILSAFE: if the sun is off, force night ---
	// When LIGHT0_ENERGY is ~0, treat as night regardless of sun direction.
	float energy_night = smoothstep(0.10, 0.0, LIGHT0_ENERGY); // 0 when bright, 1 when near 0
	night_w = max(night_w, energy_night);
	day_w *= (1.0 - energy_night);
	dusk_w *= (1.0 - energy_night);

	// Re-normalise to keep weights clean
	float sum2 = max(day_w + dusk_w + night_w, 1e-5);
	day_w /= sum2; dusk_w /= sum2; night_w /= sum2;
	// --- Gradient base ---
	// IMPORTANT for seam: keep horizon mainly from day_horizon (LookDriver matches this to ocean horizon)
	vec3 zen = day_zenith * day_w + dusk_zenith * dusk_w + night_zenith * night_w;
	vec3 hor = day_horizon; // seam-safe base
	// small tint only (doesn't wreck seam)
	hor = mix(hor, dusk_horizon, dusk_w * 0.08);
	hor = mix(hor, night_horizon, night_w * 0.10);

	float h = smoothstep(horizon_height - horizon_softness, horizon_height + horizon_softness, dir.y);
	float tt = soft_steps(h, band_steps, band_softness);
	vec3 col = mix(hor, zen, tt);

	// Ground tint below horizon
	if (dir.y < horizon_height) {
		float g = smoothstep(horizon_height, horizon_height - 0.25, dir.y);
		col = mix(col, ground_tint, g);
	}

	// --- Sun disc ---
	vec3 sdir = normalize(LIGHT0_DIRECTION);
	vec3 sun_col = LIGHT0_COLOR.rgb;
	float sun_pow = LIGHT0_ENERGY * sun_disc_boost;

	float sun_dot = dot(dir, sdir);
	float sun_core = smoothstep(1.0 - sun_size, 1.0, sun_dot);
	float sun_glow = smoothstep(1.0 - (sun_size + sun_halo), 1.0 - sun_size, sun_dot) * 0.6;

	vec3 warm = vec3(1.0, 0.55, 0.25);
	sun_col = mix(sun_col, warm, dusk_w * 0.65);
	float sun_vis = sat(day_w + dusk_w * 0.95) * (1.0 - night_w);
	col += sun_col * (sun_core * 2.0 + sun_glow) * sun_pow * sun_vis;

	// ------------------------------------------------------------
	// CLOUDS (Texture-based)
	// ------------------------------------------------------------
	vec2 wdir = normalize(cloud_wind_dir);
	vec2 drift = wdir * (TIME * cloud_speed);

	// Cumulus UVs
	vec2 uv0 = cloud_uv(dir, cloud_scale, drift);
	vec2 uv1 = cloud_uv(dir, cloud_scale * 2.2, drift * 1.35);

	// Tile nicely (assumes repeat textures)
	vec2 tuv0 = fract(uv0);
	vec2 tuv1 = fract(uv1);

	float base = texture(cumulus_tex, tuv0).r;
	float detail = texture(cumulus_detail_tex, tuv1).r;

	// Shape + contrast (more stylised control)
	base = pow(sat(base), cloud_contrast);

	// Coverage threshold from amount (0 clear -> 1 overcast)
	float th = 1.0 - cloud_amount;
	float coverage = smoothstep(th - cloud_softness, th + cloud_softness, base);

	// Thickness: dense where covered, eroded by detail
	float thick = coverage * sat(base * 1.15 - detail * 0.55);
	thick = sat(thick);

	// Toon shape
	float cloud_shape = soft_steps(coverage, max(2.0, cloud_banding), band_softness);

	// Horizon fade (keeps horizon cleaner)
	float cloud_h_fade = smoothstep(horizon_height - 0.05, horizon_height + 0.20, dir.y);

	// Night visibility control
	float cloud_vis = mix(day_w + dusk_w, 1.0, night_clouds * night_w);

	// Lighting terms (stable)
	float mu = sat(dot(dir, sdir));               // facing sun
	float forward = pow(mu, mix(10.0, 2.5, cloud_anisotropy));
	float rim = (1.0 - mu);
	rim = pow(rim, 3.0);

	// Shadow: based on thickness (stable at dusk)
	float shadow = sat(1.0 - thick * (0.65 + 0.85 * cloud_shadow_strength));

	// Light amount (reduced at night)
	float sun_light_amt = sat(day_w + dusk_w * 0.85);

	// “Silver lining” at dusk
	float dusk_rim = dusk_w * (0.25 + 0.75 * forward);

	float light_val = sat(0.20
		+ forward * cloud_light_strength * 0.9 * sun_light_amt
		+ dusk_rim * 0.85
		+ rim * 0.08);

	float lit = sat(light_val * shadow);
	lit = soft_steps(lit, max(2.0, cloud_banding), 0.08);

	// Cloud colour (no dusk->night leak)
	vec3 base_col = cloud_day_color * day_w + cloud_dusk_color * dusk_w + cloud_night_color * night_w;

	// Night darkness (clamped — never negative)
	float night_mul = max(0.12, 1.0 - night_w * 0.65 * night_cloud_darkness);
	base_col *= night_mul;

	// Underside darkening (strong at dusk/night like your refs)
	float underside = sat(1.0 - dir.y * 0.7);
	float underside_amt = sat(0.20 * day_w + 0.65 * dusk_w + 0.90 * night_w);
	vec3 under_col = mix(base_col, cloud_shadow_color, underside * underside_amt);

	// Final lit cloud colour
	float highlight_push = sat(1.05 * day_w + 1.20 * dusk_w + 1.00 * night_w);
	vec3 cloud_col = mix(under_col, base_col * highlight_push, lit);

	// Apply cumulus
	col = mix(col, cloud_col, cloud_shape * cloud_h_fade * cloud_vis);

	// --- Cirrus layer (wispy streaks) ---
	vec2 drift_c = wdir * (TIME * cirrus_speed);
	vec2 uv_c = cloud_uv(dir, cirrus_scale, drift_c);
	float cir = texture(cirrus_tex, fract(uv_c)).r;
	cir = pow(sat(cir), 1.2);
	float cir_th = smoothstep(0.55 - cirrus_amount * 0.35, 0.95, cir) * cirrus_amount;
	cir_th *= smoothstep(horizon_height - 0.02, horizon_height + 0.22, dir.y);

	vec3 cir_col = mix(cloud_day_color, cloud_dusk_color, dusk_w * 0.5);
	cir_col = mix(cir_col, cloud_night_color, night_w);
	cir_col *= max(0.15, 1.0 - night_w * 0.55 * night_cloud_darkness);

	col = mix(col, cir_col, cir_th * (0.35 + 0.65 * sun_light_amt));

	// Stars (storm nights: set stars=0 from LookDriver)
	if (night_w > 0.001 && dir.y > horizon_height) {
		float sm = stars_mask(dir);
		col += vec3(1.0) * sm * stars * night_w;
	}

	COLOR = col * exposure;
}