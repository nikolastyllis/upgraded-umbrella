shader_type spatial;

#define USE_ALPHA 0
#define USE_ALPHA_CUTOFF 1
#define USE_EMISSION 0
#define USE_REFLECTIONS 1
#define USE_NORMAL_MAP 1
#define USE_OCCLUSION 0
#define USE_HEIGHT_MAP 0
#define USE_ANISOTROPY 0
#define USE_BACKLIGHT 0
#define USE_REFRACTION 0

#if USE_ALPHA
render_mode depth_draw_always;
#endif

#include "includes/base-cel-shader.gdshaderinc"

#if USE_EMISSION
#include "includes/emission.gdshaderinc"
#endif

// ORM now handles metallic/roughness/AO directly,
// so reflections/occlusion includes are not needed for this version.
// #if USE_REFLECTIONS
// #include "includes/reflections.gdshaderinc"
// #endif

#if USE_NORMAL_MAP
#include "includes/normal-map.gdshaderinc"
#endif

// #if USE_OCCLUSION
// #include "includes/occlusion.gdshaderinc"
// #endif

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
uniform float alpha_cutoff: hint_range(0.0, 1.0) = 0.5;
#endif

uniform vec4 color: source_color = vec4(0.7, 0.12, 0.86, 1.0);
uniform sampler2D base_texture: source_color;

// replaced old specular texture workflow
uniform vec3 specular_color: source_color = vec3(0.3, 0.3, 0.3);
uniform float specular_strength: hint_range(0.0, 1.0) = 0.5;

// packed ORM map:
// R = AO
// G = Roughness
// B = Metallic
uniform sampler2D orm_texture: hint_default_white;
uniform float ao_strength: hint_range(0.0, 1.0) = 1.0;
uniform float roughness_strength: hint_range(0.0, 1.0) = 1.0;
uniform float metallic_strength: hint_range(0.0, 1.0) = 1.0;

// optional inversion if your source export differs
uniform bool invert_roughness = false;

uniform vec4 fresnel: source_color = vec4(0.2, 0.2, 0.2, 0.3);
uniform sampler2D fresnel_texture: hint_default_white;

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

	vec4 base_tex = texture(base_texture, base_uv);
	vec3 orm = texture(orm_texture, base_uv).rgb;

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

	#if USE_ALPHA
	float alpha = color.a * base_tex.a;
	ALBEDO *= alpha;
	#elif USE_ALPHA_CUTOFF
	ALPHA = color.a * base_tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	#endif

	#if USE_REFRACTION && USE_ALPHA
	EMISSION += refraction_fragment(alpha, NORMAL, SCREEN_UV, FRAGCOORD.z);
	#elif !USE_REFRACTION && USE_ALPHA
	EMISSION += transparency_fragment(alpha, SCREEN_UV);
	#endif

	ALBEDO = color.rgb * base_tex.rgb;

	AO = ao;
	ROUGHNESS = rough;
	METALLIC = metal;

	// keep toon specular neutral, not tinted by ORM channels
	SPECULAR_COLOR = specular_color;

	// map roughness -> broader/weaker stylised highlight
	// smoother surface = stronger/tighter highlight
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