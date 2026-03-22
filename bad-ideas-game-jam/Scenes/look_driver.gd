@tool
extends Node3D
class_name LookDriver

# -------------------------
# References (drag these in)
# -------------------------
@export_group("Refs")
@export var sun: DirectionalLight3D
@export var world_env: WorldEnvironment
@export var ocean_mesh: MeshInstance3D

# -------------------------
# Behaviour
# -------------------------
@export_group("Behaviour")
@export var editor_live_update := true
@export var update_in_game := true
@export var use_manual_t := false
@export_range(0.0, 1.0, 0.001) var manual_t := 0.5
@export var invert_sun := false

# -------------------------
# Debug
# -------------------------
@export_group("Debug")
@export var DEBUG_force_ocean_red := false
@export var DEBUG_print_material_status := false

# -------------------------
# Ramps (artist assets)
# -------------------------
@export_group("Ramps: Colours (GradientTexture1D)")
@export var fog_colour_ramp: GradientTexture1D
@export var sky_zenith_ramp: GradientTexture1D
@export var ocean_shallow_ramp: GradientTexture1D
@export var ocean_deep_ramp: GradientTexture1D
@export var horizon_ramp: GradientTexture1D # shared sky+ocean horizon
@export var sun_colour_ramp: GradientTexture1D

@export_group("Ramps: Values (Curve)")
@export var fog_density_curve: Curve
@export var exposure_curve: Curve
@export var cloud_amount_curve: Curve
@export var ocean_foam_curve: Curve
@export var ocean_macro_amp_curve: Curve
@export var ocean_micro_amp_curve: Curve

# -------------------------
# Uniform/property names (match your shaders)
# -------------------------
@export_group("Sky Shader Uniform Names")
@export var sky_sun_elev_uniform := "sun_elev" # your revised sky shader has this
@export var sky_time_uniform := "time_of_day"  # kept for compatibility
@export var sky_zenith_uniform := "day_zenith"
@export var sky_horizon_uniform := "day_horizon"
@export var sky_cloud_amount_uniform := "cloud_amount"
@export var sky_stars_uniform := "stars"

@export_group("Ocean Shader Uniform Names")
@export var ocean_shallow_uniform := "shallow_color"
@export var ocean_deep_uniform := "deep_color"
@export var ocean_horizon_uniform := "horizon_color"
@export var ocean_foam_uniform := "foam_amount"
@export var ocean_macro_amp_uniform := "macro_amp"
@export var ocean_micro_amp_uniform := "micro_amp"

@export_group("Environment Toggles")
@export var drive_fog := true
@export var drive_adjustments := true

@export_group("Environment Property Names")
@export var env_fog_enabled_prop := "fog_enabled"
@export var env_fog_colour_prop := "fog_light_color"
@export var env_fog_density_prop := "fog_density"
@export var env_adjust_enabled_prop := "adjustment_enabled"
@export var env_exposure_prop := "adjustment_exposure"

var _last_t := -1.0


func _process(_dt: float) -> void:
	# Editor: ALWAYS apply (ramps/curves can change without t changing)
	if Engine.is_editor_hint():
		if not editor_live_update:
			return
		_apply_look(_compute_t())
		return

	# Game: apply only if time changes (optional optimisation)
	if not update_in_game:
		return
	var t := _compute_t()
	if absf(t - _last_t) < 0.0005:
		return
	_last_t = t
	_apply_look(t)


func _compute_t() -> float:
	if use_manual_t:
		return clampf(manual_t, 0.0, 1.0)

	if sun == null:
		return 0.5

	var dir := -sun.global_transform.basis.z
	if invert_sun:
		dir = -dir

	return clampf(dir.y * 0.5 + 0.5, 0.0, 1.0)


func _apply_look(t: float) -> void:
	# 1) Light colour (optional)
	if sun != null:
		sun.light_color = _sample_col(sun_colour_ramp, t, sun.light_color)
	var horizon_col := _sample_col(horizon_ramp, t, Color(0.70, 0.85, 1.0))
	# 2) Environment (fog + adjustments)
	var env := _get_live_environment()
	if env != null:
		if drive_fog:
			_set_env_bool(env, env_fog_enabled_prop, true)
			_set_env_color(env, env_fog_colour_prop, horizon_col.lerp(Color(0.5,0.5,0.5), 0.15))
			var cur_den := _to_f(env.get(env_fog_density_prop), 0.0)
			_set_env_float(env, env_fog_density_prop, _sample_curve(fog_density_curve, t, cur_den))

		if drive_adjustments:
			_set_env_bool(env, env_adjust_enabled_prop, true)
			var cur_exp := _to_f(env.get(env_exposure_prop), 1.0)
			_set_env_float(env, env_exposure_prop, _sample_curve(exposure_curve, t, cur_exp))

	# 3) Sky shader uniforms
	var sky_mat := _get_sky_shader()
	if sky_mat != null:
		_set_shader_float(sky_mat, sky_sun_elev_uniform, t)
		_set_shader_float(sky_mat, sky_time_uniform, _to_blender_like_time(t))

		_set_shader_color(sky_mat, sky_zenith_uniform, _sample_col(sky_zenith_ramp, t, Color(0.18, 0.45, 0.95)))
		
		_set_shader_color(sky_mat, sky_horizon_uniform, horizon_col)

		var cur_cloud := _get_shader_float(sky_mat, sky_cloud_amount_uniform, 0.55)
		_set_shader_float(sky_mat, sky_cloud_amount_uniform, _sample_curve(cloud_amount_curve, t, cur_cloud))

	# 4) Ocean shader uniforms
	var ocean_mat := _get_ocean_shader()

	if DEBUG_print_material_status:
		_print_ocean_status(ocean_mat)

	if ocean_mat == null:
		return

	if DEBUG_force_ocean_red:
		ocean_mat.set_shader_parameter("shallow_color", Color(1, 0, 0))
		ocean_mat.set_shader_parameter("deep_color", Color(1, 0, 0))
		ocean_mat.set_shader_parameter("horizon_color", Color(1, 0, 0))
		return

	_set_shader_color(ocean_mat, ocean_shallow_uniform, _sample_col(ocean_shallow_ramp, t, Color(0.05, 0.35, 0.35)))
	_set_shader_color(ocean_mat, ocean_deep_uniform, _sample_col(ocean_deep_ramp, t, Color(0.01, 0.08, 0.18)))
	_set_shader_color(ocean_mat, ocean_horizon_uniform, horizon_col)

	var cur_foam := _get_shader_float(ocean_mat, ocean_foam_uniform, 1.0)
	_set_shader_float(ocean_mat, ocean_foam_uniform, _sample_curve(ocean_foam_curve, t, cur_foam))

	var cur_macro := _get_shader_float(ocean_mat, ocean_macro_amp_uniform, 0.55)
	var cur_micro := _get_shader_float(ocean_mat, ocean_micro_amp_uniform, 0.10)
	_set_shader_float(ocean_mat, ocean_macro_amp_uniform, _sample_curve(ocean_macro_amp_curve, t, cur_macro))
	_set_shader_float(ocean_mat, ocean_micro_amp_uniform, _sample_curve(ocean_micro_amp_curve, t, cur_micro))


# -------------------------
# Helpers
# -------------------------

func _to_f(v, fallback: float) -> float:
	# Godot 4: no float() constructor. Convert safely.
	if v is float:
		return v
	if v is int:
		return v * 1.0
	return fallback

func _get_live_environment() -> Environment:
	return world_env.environment if world_env != null else null

func _get_sky_shader() -> ShaderMaterial:
	var env := _get_live_environment()
	if env == null or env.sky == null:
		return null
	var m: Material = env.sky.sky_material
	return m as ShaderMaterial if m is ShaderMaterial else null

func _get_ocean_shader() -> ShaderMaterial:
	if ocean_mesh == null:
		return null

	# Your setup: Material Override on the MeshInstance
	if ocean_mesh.material_override is ShaderMaterial:
		return ocean_mesh.material_override as ShaderMaterial

	# Fallback: surface override material 0
	var m := ocean_mesh.get_surface_override_material(0)
	if m is ShaderMaterial:
		return m as ShaderMaterial

	# Fallback: active material
	var m2 := ocean_mesh.get_active_material(0)
	return m2 as ShaderMaterial if m2 is ShaderMaterial else null

func _print_ocean_status(ocean_mat: ShaderMaterial) -> void:
	if ocean_mesh == null:
		print("LookDriver: ocean_mesh ref is NULL")
		return
	if ocean_mat == null:
		print("LookDriver: ocean ShaderMaterial NOT FOUND on ocean_mesh")
		print("  material_override=", ocean_mesh.material_override)
		print("  surface_override_0=", ocean_mesh.get_surface_override_material(0))
		print("  active_material_0=", ocean_mesh.get_active_material(0))
	else:
		var path := ocean_mat.shader.resource_path if ocean_mat.shader else "<no shader>"
		print("LookDriver: ocean ShaderMaterial FOUND -> ", path)

func _sample_col(ramp: GradientTexture1D, t: float, fallback: Color) -> Color:
	if ramp == null or ramp.gradient == null:
		return fallback
	return ramp.gradient.sample(clampf(t, 0.0, 1.0))

func _sample_curve(curve: Curve, t: float, fallback: float) -> float:
	if curve == null:
		return fallback
	return curve.sample(clampf(t, 0.0, 1.0))

func _to_blender_like_time(t: float) -> float:
	if t >= 0.5:
		return lerp(0.75, 0.5, (t - 0.5) / 0.5)
	else:
		return lerp(1.0, 0.75, t / 0.5)

func _set_env_bool(env: Environment, prop: String, v: bool) -> void:
	if env != null and prop != "":
		env.set(prop, v)

func _set_env_float(env: Environment, prop: String, v: float) -> void:
	if env != null and prop != "":
		env.set(prop, v)

func _set_env_color(env: Environment, prop: String, v: Color) -> void:
	if env != null and prop != "":
		env.set(prop, v)

func _set_shader_float(mat: ShaderMaterial, uniform_name: String, v: float) -> void:
	if mat != null and uniform_name != "":
		mat.set_shader_parameter(uniform_name, v)

func _set_shader_color(mat: ShaderMaterial, uniform_name: String, v: Color) -> void:
	if mat != null and uniform_name != "":
		mat.set_shader_parameter(uniform_name, v)

func _get_shader_float(mat: ShaderMaterial, uniform_name: String, fallback: float) -> float:
	if mat == null or uniform_name == "":
		return fallback
	var v = mat.get_shader_parameter(uniform_name)
	if v is float:
		return v
	if v is int:
		return v * 1.0
	return fallback
