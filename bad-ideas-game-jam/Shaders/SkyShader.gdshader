shader_type sky;

/*
Godot 4.6.x Toon Sky (DirectionalLight-driven sun)
- Uses EYEDIR for view direction (Godot 4.x)
- Uses LIGHT0_DIRECTION / LIGHT0_COLOR / LIGHT0_ENERGY for sun disc + cloud lighting
- Toon gradient + horizon banding
- Procedural clouds with sun-lit highlights + self-shadowing feel
- Optional stars at night

Tip: In WorldEnvironment -> Background = Sky, assign a Sky resource using this ShaderMaterial.
*/

uniform float time_of_day : hint_range(0.0, 1.0) = 0.35; // 0=midnight, 0.25=sunrise, 0.5=noon, 0.75=sunset
uniform float exposure : hint_range(0.2, 2.0) = 1.0;

// Toon banding
uniform float band_steps : hint_range(2.0, 16.0) = 6.0;
uniform float band_softness : hint_range(0.0, 0.25) = 0.06;

// Horizon shaping
uniform float horizon_height : hint_range(-0.2, 0.4) = 0.05;
uniform float horizon_softness : hint_range(0.001, 0.35) = 0.14;

// Sun disc / halo (driven by DirectionalLight0 direction & colour)
uniform float sun_size : hint_range(0.001, 0.09) = 0.02;
uniform float sun_halo : hint_range(0.0, 0.7) = 0.18;
uniform float sun_disc_boost : hint_range(0.0, 6.0) = 1.4; // extra stylised punch on disc/halo

// Clouds (procedural)
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.55;    // coverage
uniform float cloud_scale : hint_range(0.2, 8.0) = 1.8;      // feature size
uniform float cloud_speed : hint_range(0.0, 2.0) = 0.22;     // drift
uniform vec2  cloud_wind_dir = vec2(1.0, 0.3);               // drift direction
uniform float cloud_contrast : hint_range(0.5, 3.0) = 1.35;  // puffiness
uniform float cloud_softness : hint_range(0.0, 0.35) = 0.10; // edge softness

// Cloud lighting
uniform float cloud_light_strength : hint_range(0.0, 2.0) = 1.0;
uniform float cloud_shadow_strength : hint_range(0.0, 2.0) = 0.9;
uniform float cloud_anisotropy : hint_range(0.0, 1.0) = 0.6; // forward scattering feel
uniform float cloud_banding : hint_range(1.0, 10.0) = 4.0;   // toon steps just for clouds

// Stars
uniform float stars : hint_range(0.0, 1.0) = 0.7;
uniform float star_density : hint_range(0.2, 3.0) = 1.2;

// Palette
uniform vec3 day_zenith   : source_color = vec3(0.18, 0.45, 0.95);
uniform vec3 day_horizon  : source_color = vec3(0.70, 0.85, 1.00);
uniform vec3 dusk_zenith  : source_color = vec3(0.10, 0.05, 0.25);
uniform vec3 dusk_horizon : source_color = vec3(0.95, 0.42, 0.22);
uniform vec3 night_zenith : source_color = vec3(0.02, 0.02, 0.06);
uniform vec3 night_horizon: source_color = vec3(0.04, 0.05, 0.10);
uniform vec3 ground_tint  : source_color = vec3(0.02, 0.02, 0.03);

// -------------------- Helpers --------------------
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

vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)),
			 dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453123);
}

float grad_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	vec2 g00 = hash22(i + vec2(0.0, 0.0)) * 2.0 - 1.0;
	vec2 g10 = hash22(i + vec2(1.0, 0.0)) * 2.0 - 1.0;
	vec2 g01 = hash22(i + vec2(0.0, 1.0)) * 2.0 - 1.0;
	vec2 g11 = hash22(i + vec2(1.0, 1.0)) * 2.0 - 1.0;

	float d00 = dot(g00, f - vec2(0.0, 0.0));
	float d10 = dot(g10, f - vec2(1.0, 0.0));
	float d01 = dot(g01, f - vec2(0.0, 1.0));
	float d11 = dot(g11, f - vec2(1.0, 1.0));

	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(d00, d10, u.x), mix(d01, d11, u.x), u.y) * 0.5 + 0.5;
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;

	// rotate domain each octave to avoid grid artifacts
	float s = sin(0.55);
	float c = cos(0.55);
	mat2 r = mat2(vec2(c, s), vec2(-s, c));

	for (int i = 0; i < 5; i++) {
		v += a * grad_noise(p);
		p = r * p * 2.02;
		a *= 0.5;
	}
	return v;
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

// Cheap “two-tap” self-shadow feel: sample density towards sun direction
float cloud_shadow_tap(vec2 uv, vec2 sun_uv_dir) {
	// A couple taps “towards sun” darken the underside / leeward areas
	float d1 = fbm(uv + sun_uv_dir * 0.35);
	float d2 = fbm(uv + sun_uv_dir * 0.75);
	// darker where density increases towards sun
	float sh = sat((d1 + d2) * 0.5);
	return sh;
}

void sky() {
	// View direction in sky shader (Godot 4.x)
	vec3 dir = normalize(EYEDIR);

	// ---- Day/Night model from time_of_day ----
	float dayness = 1.0 - smoothstep(0.0, 0.25, abs(time_of_day - 0.5) * 2.0);
	float nightness = 1.0 - dayness;

	float duskness = smoothstep(0.0, 0.18, 0.18 - abs(time_of_day - 0.25))
	               + smoothstep(0.0, 0.18, 0.18 - abs(time_of_day - 0.75));
	duskness = sat(duskness);

	// Base gradient palette blend
	vec3 zen = mix(night_zenith, day_zenith, dayness);
	vec3 hor = mix(night_horizon, day_horizon, dayness);
	hor = mix(hor, dusk_horizon, duskness);
	zen = mix(zen, dusk_zenith, duskness * 0.6);

	// Horizon toon blend
	float h = smoothstep(horizon_height - horizon_softness, horizon_height + horizon_softness, dir.y);
	float t = soft_steps(h, band_steps, band_softness);
	vec3 col = mix(hor, zen, t);

	// Ground tint below horizon
	if (dir.y < horizon_height) {
		float g = smoothstep(horizon_height, horizon_height - 0.25, dir.y);
		col = mix(col, ground_tint, g);
	}

	// ---- Directional light driven Sun ----
	// Depending on your setup, the “direction” may point *from* the light.
	// If sun appears opposite, flip to -LIGHT0_DIRECTION.
	vec3 sdir = normalize(LIGHT0_DIRECTION);
	vec3 sun_col = LIGHT0_COLOR.rgb;
	float sun_pow = LIGHT0_ENERGY * sun_disc_boost;

	float sun_dot = dot(dir, sdir);
	float sun_core = smoothstep(1.0 - sun_size, 1.0, sun_dot);
	float sun_glow = smoothstep(1.0 - (sun_size + sun_halo), 1.0 - sun_size, sun_dot) * 0.6;

	// A little dusk warmth (stylised)
	vec3 warm = vec3(1.0, 0.55, 0.25);
	sun_col = mix(sun_col, warm, duskness * 0.35);

	col += sun_col * (sun_core * 2.0 + sun_glow) * sun_pow * dayness;

	// ---- Clouds: procedural density + lighting/shadow ----
	// Stable mapping: project to plane based on view direction (avoids pole pinching)
	vec2 view_plane = dir.xz / max(0.18, abs(dir.y) + 0.18);

	// Wind direction normalised
	vec2 wdir = normalize(cloud_wind_dir);
	vec2 drift = wdir * (TIME * cloud_speed);

	// Main cloud UV
	vec2 uv = view_plane * cloud_scale + drift;

	// Density field
	float d = fbm(uv * 0.85);
	d = pow(d, cloud_contrast);

	// Coverage threshold → 0..1 “where clouds exist”
	float coverage = smoothstep(1.0 - cloud_amount - cloud_softness,
	                           1.0 - cloud_amount + cloud_softness, d);

	// Toon the cloud shape slightly
	float cloud_shape = soft_steps(coverage, max(2.0, cloud_banding), band_softness);

	// --- Lighting ---
	// Sun side factor for this sky ray (view dir vs sun dir)
	float sun_side = sat(dot(dir, sdir) * 0.5 + 0.5);

	// Fake anisotropic forward scattering (brighter around sun direction)
	float forward = pow(sat(dot(dir, sdir)), mix(8.0, 2.0, cloud_anisotropy));
	float highlight = mix(sun_side, 1.0, cloud_anisotropy) * (0.35 + 0.65 * forward);

	// Self-shadow feel: sample density “towards sun” in UV space
	// Convert sun dir into the same projected plane direction (approx)
	vec2 sun_plane = normalize(sdir.xz + 1e-5);
	float sh = cloud_shadow_tap(uv, sun_plane);

	// Combine into toon light bands
	float light_val = sat(0.35 + highlight * cloud_light_strength);
	float shadow_val = sat(1.0 - sh * cloud_shadow_strength);

	float lit = sat(light_val * shadow_val);
	lit = soft_steps(lit, max(2.0, cloud_banding), 0.08); // separate toon banding for lighting

	// Cloud colours: base + lit rim
	vec3 cloud_base = mix(vec3(0.75, 0.80, 0.95), vec3(0.95, 0.96, 1.0), dayness);
	cloud_base = mix(cloud_base, vec3(1.0, 0.70, 0.45), duskness * 0.35);

	vec3 cloud_lit = mix(cloud_base * 0.75, cloud_base * 1.15, lit);

	// Apply clouds only above horizon-ish; fade near horizon to avoid harsh seam
	float cloud_h_fade = smoothstep(horizon_height - 0.05, horizon_height + 0.15, dir.y);

	col = mix(col, cloud_lit, cloud_shape * cloud_h_fade * dayness);

	// ---- Stars (night, above horizon) ----
	if (nightness > 0.001 && dir.y > horizon_height) {
		float sm = stars_mask(dir);
		col += vec3(1.0) * sm * stars * nightness;
	}

	COLOR = col * exposure;
}