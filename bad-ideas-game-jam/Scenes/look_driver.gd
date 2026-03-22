@tool
extends Node3D
class_name LookDriver

# -------------------------
# References
# -------------------------
@export_group("Refs")
@export var sun: DirectionalLight3D
@export var world_env: WorldEnvironment
@export var ocean_mesh: MeshInstance3D

# If you want the look to update in editor without running
@export_group("Behaviour")
@export var editor_live_update := true
@export var update_in_game := true

# Optional: override the computed sun elevation (for testing)
@export var use_manual_t := false
@export_range(0.0, 1.0, 0.001) var manual_t := 0.5

# Optional: invert if your sun seems “backwards”
@export var invert_sun := false

# -------------------------
# Ramps (artist assets)
# -------------------------
@export_group("Ramps: Colours (GradientTexture1D)")
@export var fog_colour_ramp: GradientTexture1D
@export var sky_zenith_ramp: GradientTexture1D
@export var sky_horizon_ramp: GradientTexture1D
@export var ocean_shallow_ramp: GradientTexture1D
@export var ocean_deep_ramp: GradientTexture1D
@export var ocean_horizon_ramp: GradientTexture1D
@export var sun_colour_ramp: GradientTexture1D

@export_group("Ramps: Values (Curve)")
@export var fog_density_curve: Curve
@export var exposure_curve: Curve
@export var cloud_amount_curve: Curve
@export var ocean_foam_curve: Curve

@export_group("Ramps: Values (Curve)")
@export var ocean_macro_amp_curve: Curve
@export var ocean_micro_amp_curve: Curve

@export_group("Ocean Shader Uniform Names")
@export var ocean_macro_amp_uniform := "macro_amp"
@export var ocean_micro_amp_uniform := "micro_amp"

# -------------------------
# Targets (what uniforms/properties to drive)
# -------------------------
@export_group("Sky Shader Uniform Names")
@export var sky_time_uniform := "time_of_day"
@export var sky_zenith_uniform := "day_zenith"   # or whatever you named it
@export var sky_horizon_uniform := "day_horizon" # or whatever you named it
@export var sky_cloud_amount_uniform := "cloud_amount"
@export var sky_stars_uniform := "stars"

@export_group("Ocean Shader Uniform Names")
@export var ocean_shallow_uniform := "shallow_color"
@export var ocean_deep_uniform := "deep_color"
@export var ocean_horizon_uniform := "horizon_color"
@export var ocean_foam_uniform := "foam_amount"

# -------------------------
# Environment properties to drive
# (These match Godot 4.x Environment property names)
# -------------------------
@export_group("Environment Toggles")
@export var drive_fog := true
@export var drive_adjustments := true

@export_group("Environment Property Names")
@export var env_fog_enabled_prop := "fog_enabled"
@export var env_fog_colour_prop := "fog_light_color"
@export var env_fog_density_prop := "fog_density"
@export var env_adjust_enabled_prop := "adjustment_enabled"
@export var env_exposure_prop := "adjustment_exposure"

# -------------------------
# Internal
# -------------------------
var _last_t := -1.0

func _process(_dt: float) -> void:
	if Engine.is_editor_hint():
		if not editor_live_update:
			return
	else:
		if not update_in_game:
			return

	var t := _compute_t()
	# avoid spamming sets if nothing changed (especially in editor)
	if absf(t - _last_t) < 0.0005:
		return
	_last_t = t

	_apply_look(t)

func _compute_t() -> float:
	if use_manual_t:
		return clampf(manual_t, 0.0, 1.0)

	if sun == null:
		return 0.5

	# In Godot, -basis.z is "forward" for Node3D.
	# For a directional light, the direction light points is often -basis.z.
	# We want "sun elevation", so use the Y component of the direction.
	var dir := -sun.global_transform.basis.z
	if invert_sun:
		dir = -dir

	# Map [-1..+1] -> [0..1]
	return clampf(dir.y * 0.5 + 0.5, 0.0, 1.0)

func _apply_look(t: float) -> void:
	# 1) Directional light
	if sun != null:
		var sun_col := _sample_col(sun_colour_ramp, t, sun.light_color)
		sun.light_color = sun_col
		# (Energy can be driven with another curve if you want.)

	# 2) Environment (fog + adjustments)
	var env := _get_live_environment()
	if env != null:
		if drive_fog:
			_set_env_bool(env, env_fog_enabled_prop, true)
			_set_env_color(env, env_fog_colour_prop, _sample_col(fog_colour_ramp, t, Color(0.7, 0.8, 0.9)))
			_set_env_float(env, env_fog_density_prop, _sample_curve(fog_density_curve, t, env.get(env_fog_density_prop)))
		if drive_adjustments:
			_set_env_bool(env, env_adjust_enabled_prop, true)
			_set_env_float(env, env_exposure_prop, _sample_curve(exposure_curve, t, env.get(env_exposure_prop)))

	# 3) Sky shader uniforms
	var sky_mat := _get_sky_shader()
	if sky_mat != null:
		# time_of_day: you can map t however you like; this default makes:
		# t=0 (below horizon) ~ night, t=0.5 ~ sunrise/sunset, t=1 ~ noon
		# If your sky expects 0=midnight, 0.25=sunrise, 0.5=noon, 0.75=sunset:
		var sky_time := _to_blender_like_time(t)
		_set_shader_float(sky_mat, sky_time_uniform, sky_time)

		_set_shader_color(sky_mat, sky_zenith_uniform, _sample_col(sky_zenith_ramp, t, Color(0.18, 0.45, 0.95)))
		_set_shader_color(sky_mat, sky_horizon_uniform, _sample_col(sky_horizon_ramp, t, Color(0.70, 0.85, 1.0)))

		_set_shader_float(sky_mat, sky_cloud_amount_uniform, _sample_curve(cloud_amount_curve, t, _get_shader_float(sky_mat, sky_cloud_amount_uniform, 0.55)))
	
	var night_factor := 1.0 - smoothstep(0.52, 0.62, t) # 1 at night (low t), 0 in day
	_set_shader_float(sky_mat, sky_stars_uniform, 0.0)  # stormy night: always no stars
	
	# 4) Ocean shader uniforms
	var ocean_mat := _get_ocean_shader()
	if ocean_mat != null:
		_set_shader_color(ocean_mat, ocean_shallow_uniform, _sample_col(ocean_shallow_ramp, t, Color(0.05, 0.35, 0.35)))
		_set_shader_color(ocean_mat, ocean_deep_uniform, _sample_col(ocean_deep_ramp, t, Color(0.01, 0.08, 0.18)))
		_set_shader_color(ocean_mat, ocean_horizon_uniform, _sample_col(ocean_horizon_ramp, t, Color(0.05, 0.10, 0.15)))
		# Wave amplitudes (macro + micro)
		var macro_amp := _sample_curve(ocean_macro_amp_curve, t, _get_shader_float(ocean_mat, ocean_macro_amp_uniform, 0.55))
		var micro_amp := _sample_curve(ocean_micro_amp_curve, t, _get_shader_float(ocean_mat, ocean_micro_amp_uniform, 0.10))

		_set_shader_float(ocean_mat, ocean_macro_amp_uniform, macro_amp)
		_set_shader_float(ocean_mat, ocean_micro_amp_uniform, micro_amp)
		_set_shader_float(ocean_mat, ocean_foam_uniform, _sample_curve(ocean_foam_curve, t, _get_shader_float(ocean_mat, ocean_foam_uniform, 1.0)))

# -------------------------
# Helpers
# -------------------------

func _get_live_environment() -> Environment:
	if world_env == null:
		return null
	return world_env.environment

func _get_sky_shader() -> ShaderMaterial:
	var env := _get_live_environment()
	if env == null or env.sky == null:
		return null
	var m: Material = env.sky.sky_material
	return m as ShaderMaterial if m is ShaderMaterial else null

func _get_ocean_shader() -> ShaderMaterial:
	if ocean_mesh == null:
		return null

	# Your screenshot shows you’re using Material Override (GeometryInstance3D)
	# This is the best first pick.
	if ocean_mesh.material_override is ShaderMaterial:
		return ocean_mesh.material_override as ShaderMaterial

	# Fallback: surface override material 0
	var m := ocean_mesh.get_surface_override_material(0)
	if m is ShaderMaterial:
		return m as ShaderMaterial

	# Fallback: active material
	var m2 := ocean_mesh.get_active_material(0)
	return m2 as ShaderMaterial if m2 is ShaderMaterial else null

func _sample_col(ramp: GradientTexture1D, t: float, fallback: Color) -> Color:
	if ramp == null or ramp.gradient == null:
		return fallback
	return ramp.gradient.sample(clampf(t, 0.0, 1.0))

func _sample_curve(curve: Curve, t: float, fallback: float) -> float:
	if curve == null:
		return fallback
	return curve.sample(clampf(t, 0.0, 1.0))

func _to_blender_like_time(t: float) -> float:
	# 0=midnight, 0.25=sunrise, 0.5=noon, 0.75=sunset, 1.0=midnight
	# Elevation t: 0 (below horizon) -> 1 (high noon-ish)
	# We want: low elevation = night/dusk, high elevation = day.
	#
	# Simple mapping:
	# - t=1 => noon (0.5)
	# - t=0.5 => sunrise/sunset-ish (~0.25 or 0.75). We'll pick sunset side for vibe.
	# - t=0 => midnight (1.0)
	#
	# This gives you real night behaviour when sun is low.
	if t >= 0.5:
		# from horizon to noon: 0.75 -> 0.5
		return lerp(0.75, 0.5, (t - 0.5) / 0.5)
	else:
		# from midnight to horizon: 1.0 -> 0.75
		return lerp(1.0, 0.75, t / 0.5)

func _set_env_bool(env: Environment, prop: String, v: bool) -> void:
	if env == null:
		return
	if env.has_method("set"):
		env.set(prop, v)

func _set_env_float(env: Environment, prop: String, v: float) -> void:
	if env == null:
		return
	env.set(prop, v)

func _set_env_color(env: Environment, prop: String, v: Color) -> void:
	if env == null:
		return
	env.set(prop, v)

func _set_shader_float(mat: ShaderMaterial, uniform_name: String, v: float) -> void:
	if mat == null or uniform_name == "":
		return
	mat.set_shader_parameter(uniform_name, v)

func _set_shader_color(mat: ShaderMaterial, uniform_name: String, v: Color) -> void:
	if mat == null or uniform_name == "":
		return
	mat.set_shader_parameter(uniform_name, v)

func _get_shader_float(mat: ShaderMaterial, uniform_name: String, fallback: float) -> float:
	if mat == null or uniform_name == "":
		return fallback
	var v = mat.get_shader_parameter(uniform_name)
	return float(v) if (v is float or v is int) else fallback
