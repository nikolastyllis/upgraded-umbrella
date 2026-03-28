shader_type spatial;

#define USE_ALPHA 1
#define USE_ALPHA_CUTOFF 1
#define USE_EMISSION 1
#define USE_REFLECTIONS 0
#define USE_NORMAL_MAP 1
#define USE_OCCLUSION 1
#define USE_HEIGHT_MAP 0
#define USE_ANISOTROPY 0
#define USE_BACKLIGHT 0
#define USE_REFRACTION 0

#if USE_ALPHA
render_mode blend_mix, depth_prepass_alpha, cull_back;
#endif

#include "includes/base-cel-shader.gdshaderinc"

#if USE_EMISSION
#include "includes/emission.gdshaderinc"
#endif

#if USE_NORMAL_MAP
#include "includes/normal-map.gdshaderinc"
#endif

#if USE_HEIGHT_MAP
#include "includes/height-map.gdshaderinc"
#endif

#if USE_ANISOTROPY
#include "includes/anisotropy.gdshaderinc"
#endif

#if USE_BACKLIGHT
#include "includes/backlight.gdshaderinc"
#endif

#if USE_REFRACTION
#include "includes/refraction.gdshaderinc"
#elif !USE_REFRACTION && USE_ALPHA
#include "includes/transparency.gdshaderinc"
#endif

group_uniforms BaseProperties;

#if USE_ALPHA_CUTOFF
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;
#endif

uniform vec4 color : source_color = vec4(0.7, 0.12, 0.86, 1.0);

//
// Shared base panel
//
uniform sampler2D base_texture : source_color;

//
// Paint recolour mask
//
uniform sampler2D mask_texture : hint_default_white;
uniform bool use_mask = false;
uniform float mask_strength : hint_range(0.0, 1.0) = 1.0;
uniform float color_replace_detail : hint_range(0.0, 1.0) = 0.5;

//
// Rust overlays
// RGB = rust colour
// A   = rust shape mask
//
uniform sampler2D rust_light_texture : source_color;
uniform sampler2D rust_heavy_texture : source_color;

uniform float rust_light_strength : hint_range(0.0, 2.0) = 1.0;
uniform float rust_heavy_strength : hint_range(0.0, 2.0) = 1.0;
uniform float rust_blend_sharpness : hint_range(0.1, 8.0) = 1.0;

//
// Shared ORM + normal
//
uniform sampler2D orm_texture : hint_default_white;

uniform float ao_strength : hint_range(0.0, 1.0) = 1.0;
uniform float roughness_strength : hint_range(0.0, 1.0) = 1.0;
uniform float metallic_strength : hint_range(0.0, 1.0) = 1.0;
uniform bool invert_roughness = false;

#if USE_NORMAL_MAP

#endif

//
// Surface response
//
uniform vec3 specular_color : source_color = vec3(0.3, 0.3, 0.3);
uniform float specular_strength : hint_range(0.0, 1.0) = 0.5;

uniform vec4 fresnel : source_color = vec4(0.2, 0.2, 0.2, 0.3);
uniform sampler2D fresnel_texture : hint_default_white;

group_uniforms;

varying vec3 SPECULAR_COLOR;
varying float SPECULAR_STRENGTH;
varying vec3 FRESNEL_COLOR;
varying float FRESNEL_STRENGTH;
varying vec2 base_uv;

group_uniforms Tiling;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);
group_uniforms;

void vertex() {
	UV = UV * uv_scale + uv_offset;

	#if !USE_HEIGHT_MAP
	base_uv = UV;
	#endif
}

void fragment() {
	#if USE_HEIGHT_MAP
	base_uv = height_map_fragment(UV, VERTEX, TANGENT, BINORMAL, NORMAL);
	#endif

	//
	// Vertex colour controls rust amount
	// G = light rust
	// B = heavy rust
	//
	float rust_light_amount = pow(clamp(COLOR.g, 0.0, 1.0), rust_blend_sharpness) * rust_light_strength;
	float rust_heavy_amount = pow(clamp(COLOR.b, 0.0, 1.0), rust_blend_sharpness) * rust_heavy_strength;

	rust_light_amount = clamp(rust_light_amount, 0.0, 1.0);
	rust_heavy_amount = clamp(rust_heavy_amount, 0.0, 1.0);

	//
	// Sample textures
	//
	vec4 base_tex = texture(base_texture, base_uv);
	vec4 rust_light_tex = texture(rust_light_texture, base_uv);
	vec4 rust_heavy_tex = texture(rust_heavy_texture, base_uv);

	vec3 orm = texture(orm_texture, base_uv).rgb;

	//
	// Shared ORM
	//
	float ao = orm.r;
	float rough = orm.g;
	float metal = orm.b;

	if (invert_roughness) {
		rough = 1.0 - rough;
	}

	ao = mix(1.0, ao, ao_strength);
	rough *= roughness_strength;
	metal *= metallic_strength;

	rough = clamp(rough, 0.0, 1.0);
	metal = clamp(metal, 0.0, 1.0);
	ao = clamp(ao, 0.0, 1.0);

	//
	// Base paint recolour
	//
	float paint_mask = 1.0;
	if (use_mask) {
		paint_mask = texture(mask_texture, base_uv).r;
		paint_mask *= mask_strength;
		paint_mask = clamp(paint_mask, 0.0, 1.0);
	}

	float base_value = dot(base_tex.rgb, vec3(0.299, 0.587, 0.114));
	base_value = mix(1.0, base_value, color_replace_detail);

	vec3 replaced_base = color.rgb * base_value;

	vec3 painted_base;
	if (use_mask) {
		painted_base = mix(base_tex.rgb, replaced_base, paint_mask);
	} else {
		painted_base = base_tex.rgb * color.rgb;
	}

	//
	// Rust overlay masks come from rust texture alpha
	//
	float rust_light_mask = rust_light_tex.a * rust_light_amount;
	float rust_heavy_mask = rust_heavy_tex.a * rust_heavy_amount;

	rust_light_mask = clamp(rust_light_mask, 0.0, 1.0);
	rust_heavy_mask = clamp(rust_heavy_mask, 0.0, 1.0);

	//
	// Layer rust on top of painted base
	//
	vec3 final_albedo = painted_base;
	final_albedo = mix(final_albedo, rust_light_tex.rgb, rust_light_mask);
	final_albedo = mix(final_albedo, rust_heavy_tex.rgb, rust_heavy_mask);

	ALBEDO = final_albedo;

	//
	// Alpha from base texture alpha and material alpha
	//
	float alpha = color.a * base_tex.a;

	#if USE_ALPHA
		ALPHA = alpha;
	#endif

	#if USE_ALPHA_CUTOFF
		ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	#endif

	#if USE_REFRACTION && USE_ALPHA
		EMISSION += refraction_fragment(alpha, NORMAL, SCREEN_UV, FRAGCOORD.z);
	#elif !USE_REFRACTION && USE_ALPHA
		EMISSION += transparency_fragment(alpha, SCREEN_UV);
	#endif

	AO = ao;
	ROUGHNESS = rough;
	METALLIC = metal;

	SPECULAR_COLOR = specular_color;
	SPECULAR_STRENGTH = clamp(specular_strength * (1.0 - rough), 0.0, 1.0);

	FRESNEL_COLOR = fresnel.rgb * texture(fresnel_texture, base_uv).rgb;
	FRESNEL_STRENGTH = fresnel.a * texture(fresnel_texture, base_uv).a;

	#if USE_EMISSION
		EMISSION += emission_fragment(base_uv);
	#endif

	#if USE_NORMAL_MAP
		NormalData normal = normal_map_fragment(base_uv, NORMAL, TANGENT, BINORMAL);
		NORMAL = normal.vector;
		NORMAL_MAP = normal.map;
		NORMAL_MAP_DEPTH = normal.depth;
	#endif

	#if USE_ANISOTROPY
		AnisotropyData aniso = anisotropy_fragment(UV);
		ANISOTROPY_DIR = aniso.direction;
		ANISOTROPY_RATIO = aniso.ratio;
	#endif

	#if USE_BACKLIGHT
		BACKLIGHT = backlight_fragment(base_uv);
	#endif
}

void light() {
	#if USE_BACKLIGHT
		DIFFUSE_LIGHT += backlight_diffuse(
			ALBEDO, LIGHT_COLOR, LIGHT, NORMAL, ATTENUATION, BACKLIGHT
		);
	#else
		DIFFUSE_LIGHT += diffuse_light(
			ALBEDO, LIGHT_COLOR, LIGHT, NORMAL, ATTENUATION
		);
	#endif

	#if USE_ANISOTROPY
		SPECULAR_LIGHT += anisotropy_specular(
			LIGHT_COLOR, SPECULAR_COLOR, SPECULAR_STRENGTH,
			NORMAL, VIEW, LIGHT, ATTENUATION, UV,
			ANISOTROPY_DIR, ANISOTROPY_RATIO
		);
	#else
		SPECULAR_LIGHT += specular_light(
			LIGHT_COLOR, SPECULAR_COLOR, SPECULAR_STRENGTH,
			NORMAL, VIEW, LIGHT, ATTENUATION
		);
	#endif

	SPECULAR_LIGHT += fresnel_light(
		LIGHT_COLOR, FRESNEL_COLOR, FRESNEL_STRENGTH,
		NORMAL, VIEW, LIGHT, ATTENUATION
	);
}