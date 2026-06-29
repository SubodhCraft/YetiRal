extends Node3D

## ─── YetiVisuals.gd ──────────────────────────────────────────────────────────
## Builds the Yeti character entirely from Godot built-in mesh primitives.
## Attach to the $Visuals Node3D that is a direct child of Player3D.tscn.
##
## Node layout created at runtime:
##   $Visuals (this node)
##   ├── Body        (MeshInstance3D)
##   ├── Head        (MeshInstance3D)
##   ├── EyeLeft     (MeshInstance3D)
##   ├── EyeRight    (MeshInstance3D)
##   ├── Nose        (MeshInstance3D)
##   ├── HornLeft    (MeshInstance3D)
##   ├── HornRight   (MeshInstance3D)
##   ├── ArmLeft     (MeshInstance3D)
##   ├── ArmRight    (MeshInstance3D)
##   ├── LegLeft     (MeshInstance3D)
##   ├── LegRight    (MeshInstance3D)
##   ├── FootLeft    (MeshInstance3D)
##   ├── FootRight   (MeshInstance3D)
##   └── AnimationPlayer

## ─── MATERIAL CONSTANTS ──────────────────────────────────────────────────────
const COLOR_FUR:      Color = Color(0.941, 0.941, 0.961)  # #F0F0F5 white fur
const COLOR_EYE:      Color = Color(0.05,  0.05,  0.05)   # near-black
const COLOR_NOSE:     Color = Color(0.30,  0.18,  0.10)   # dark brown
const COLOR_HORN:     Color = Color(0.92,  0.87,  0.72)   # cream
const COLOR_FOOT:     Color = Color(0.22,  0.22,  0.25)   # dark grey

## ─── PART REFERENCES ─────────────────────────────────────────────────────────
## Populated in _build_body(). Used by setup_animation_player() for keyframes.
var _body:      MeshInstance3D
var _head:      MeshInstance3D
var _eye_l:     MeshInstance3D
var _eye_r:     MeshInstance3D
var _nose:      MeshInstance3D
var _horn_l:    MeshInstance3D
var _horn_r:    MeshInstance3D
var _arm_l:     MeshInstance3D
var _arm_r:     MeshInstance3D
var _leg_l:     MeshInstance3D
var _leg_r:     MeshInstance3D
var _foot_l:    MeshInstance3D
var _foot_r:    MeshInstance3D
var _anim:      AnimationPlayer

## Tracks the currently playing animation name to avoid redundant play() calls.
var _current_anim: String = ""

## ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_body()
	setup_animation_player()
	# Start in idle immediately.
	update_animation("idle")

## ─── BODY CONSTRUCTION ───────────────────────────────────────────────────────
## All positions are in local space of $Visuals, with y=0 at the Yeti's feet.
func _build_body() -> void:

	# ── Materials ──────────────────────────────────────────────────────────────
	var mat_fur  := _make_mat(COLOR_FUR,  0.9, 0.0, false)
	var mat_eye  := _make_mat(COLOR_EYE,  0.3, 0.0, true)   # emission for readability
	var mat_nose := _make_mat(COLOR_NOSE, 0.8, 0.0, false)
	var mat_horn := _make_mat(COLOR_HORN, 0.7, 0.1, false)
	var mat_foot := _make_mat(COLOR_FOOT, 0.85,0.0, false)

	# ── Body (capsule, torso) ──────────────────────────────────────────────────
	var body_mesh       := CapsuleMesh.new()
	body_mesh.radius    = 0.45
	body_mesh.height    = 1.1
	_body               = _make_part("Body", body_mesh, mat_fur, Vector3(0.0, 0.65, 0.0))

	# ── Head ──────────────────────────────────────────────────────────────────
	var head_mesh       := SphereMesh.new()
	head_mesh.radius    = 0.32
	head_mesh.height    = 0.64   # height = 2 × radius keeps it a perfect sphere
	_head               = _make_part("Head", head_mesh, mat_fur, Vector3(0.0, 1.25, 0.0))

	# ── Eyes (slightly forward so they don't clip into the head) ──────────────
	var eye_mesh        := SphereMesh.new()
	eye_mesh.radius     = 0.07
	eye_mesh.height     = 0.14
	_eye_l              = _make_part("EyeLeft",  eye_mesh, mat_eye,
									 Vector3(-0.12, 1.32, -0.26))
	_eye_r              = _make_part("EyeRight", eye_mesh, mat_eye,
									 Vector3( 0.12, 1.32, -0.26))

	# ── Nose ──────────────────────────────────────────────────────────────────
	var nose_mesh       := SphereMesh.new()
	nose_mesh.radius    = 0.06
	nose_mesh.height    = 0.12
	_nose               = _make_part("Nose", nose_mesh, mat_nose,
									 Vector3(0.0, 1.22, -0.29))

	# ── Horns (cylinders, angled outward 15° so tips splay wide) ──────────────
	var horn_mesh       := CylinderMesh.new()
	horn_mesh.top_radius    = 0.015   # tapers to a point at the tip
	horn_mesh.bottom_radius = 0.04
	horn_mesh.height        = 0.30
	_horn_l = _make_part("HornLeft",  horn_mesh, mat_horn, Vector3(-0.15, 1.50, 0.0))
	_horn_r = _make_part("HornRight", horn_mesh, mat_horn, Vector3( 0.15, 1.50, 0.0))
	# Tilt horns outward so they splay away from the head.
	_horn_l.rotation_degrees = Vector3(0.0, 0.0,  15.0)
	_horn_r.rotation_degrees = Vector3(0.0, 0.0, -15.0)

	# ── Arms (capsules, positioned at shoulder height, angled outward) ─────────
	# rotation_degrees.z ±30° tilts each arm away from the body at the shoulder.
	var arm_mesh        := CapsuleMesh.new()
	arm_mesh.radius     = 0.12
	arm_mesh.height     = 0.50
	_arm_l = _make_part("ArmLeft",  arm_mesh, mat_fur, Vector3(-0.52, 0.80, 0.0))
	_arm_r = _make_part("ArmRight", arm_mesh, mat_fur, Vector3( 0.52, 0.80, 0.0))
	# Outward rest angle — animation will layer additional rotation on top.
	_arm_l.rotation_degrees = Vector3(0.0, 0.0,  30.0)
	_arm_r.rotation_degrees = Vector3(0.0, 0.0, -30.0)

	# ── Legs (capsules, side by side below the torso) ─────────────────────────
	var leg_mesh        := CapsuleMesh.new()
	leg_mesh.radius     = 0.14
	leg_mesh.height     = 0.45
	_leg_l = _make_part("LegLeft",  leg_mesh, mat_fur, Vector3(-0.17, 0.32, 0.0))
	_leg_r = _make_part("LegRight", leg_mesh, mat_fur, Vector3( 0.17, 0.32, 0.0))

	# ── Feet (flat boxes, slightly forward to look natural) ───────────────────
	var foot_mesh       := BoxMesh.new()
	foot_mesh.size      = Vector3(0.20, 0.10, 0.30)
	_foot_l = _make_part("FootLeft",  foot_mesh, mat_foot, Vector3(-0.17, 0.05, -0.05))
	_foot_r = _make_part("FootRight", foot_mesh, mat_foot, Vector3( 0.17, 0.05, -0.05))

## ─── ANIMATION SETUP ─────────────────────────────────────────────────────────
## Creates the AnimationPlayer and registers the four core animations
## programmatically. Call once after _build_body() completes.
func setup_animation_player() -> void:
	_anim = AnimationPlayer.new()
	_anim.name = "AnimationPlayer"
	add_child(_anim)

	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _make_anim_idle())
	lib.add_animation("run",  _make_anim_run())
	lib.add_animation("jump", _make_anim_jump())
	lib.add_animation("dive", _make_anim_dive())
	_anim.add_animation_library("", lib)

	# Default blend time so transitions feel smooth rather than snapping.
	_anim.set_blend_time("idle", "run",  0.15)
	_anim.set_blend_time("run",  "idle", 0.15)
	_anim.set_blend_time("idle", "jump", 0.10)
	_anim.set_blend_time("jump", "idle", 0.20)
	_anim.set_blend_time("run",  "jump", 0.10)
	_anim.set_blend_time("jump", "run",  0.20)
	_anim.set_blend_time("idle", "dive", 0.05)
	_anim.set_blend_time("run",  "dive", 0.05)
	_anim.set_blend_time("dive", "idle", 0.20)
	_anim.set_blend_time("dive", "run",  0.20)

## ─── ANIMATION STATE DRIVER ──────────────────────────────────────────────────
## Called by Player3D._physics_process() every frame to pick the correct clip.
## state must be one of: "idle", "run", "jump", "dive"
func update_animation(state: String) -> void:
	if _anim == null or _current_anim == state:
		return
	if not _anim.has_animation(state):
		return
	_current_anim = state
	_anim.play(state)

## ─── ANIMATION BUILDERS ──────────────────────────────────────────────────────

## IDLE — body gentle vertical bob, ±0.02 Y, 1.5 s loop.
func _make_anim_idle() -> Animation:
	var anim := Animation.new()
	anim.length   = 1.5
	anim.loop_mode = Animation.LOOP_LINEAR

	# Body position Y: 0.65 → 0.67 → 0.65 → 0.63 → 0.65
	var t_body := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(t_body, "../Body")
	anim.track_insert_key(t_body, 0.00,  Vector3(0.0, 0.65,  0.0))
	anim.track_insert_key(t_body, 0.375, Vector3(0.0, 0.67,  0.0))
	anim.track_insert_key(t_body, 0.75,  Vector3(0.0, 0.65,  0.0))
	anim.track_insert_key(t_body, 1.125, Vector3(0.0, 0.63,  0.0))
	anim.track_insert_key(t_body, 1.50,  Vector3(0.0, 0.65,  0.0))
	_set_track_interpolation(anim, t_body, Animation.INTERPOLATION_CUBIC)

	# Head follows the body bob with a slight delay offset (0.1 s phase shift).
	var t_head := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(t_head, "../Head")
	anim.track_insert_key(t_head, 0.00,  Vector3(0.0, 1.25,  0.0))
	anim.track_insert_key(t_head, 0.475, Vector3(0.0, 1.27,  0.0))
	anim.track_insert_key(t_head, 0.85,  Vector3(0.0, 1.25,  0.0))
	anim.track_insert_key(t_head, 1.225, Vector3(0.0, 1.23,  0.0))
	anim.track_insert_key(t_head, 1.50,  Vector3(0.0, 1.25,  0.0))
	_set_track_interpolation(anim, t_head, Animation.INTERPOLATION_CUBIC)

	return anim

## RUN — arms and legs swing alternately, 0.5 s loop.
## Arm swing: ±25° around X (forward/back). Leg swing: ±20° around X.
func _make_anim_run() -> Animation:
	var anim := Animation.new()
	anim.length    = 0.5
	anim.loop_mode = Animation.LOOP_LINEAR

	# ── Left Arm: starts forward, ends backward ──────────────────────────────
	var t_arm_l := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(t_arm_l, "../ArmLeft")
	anim.track_insert_key(t_arm_l, 0.00, _euler_to_quat( 25.0, 0.0,  30.0))
	anim.track_insert_key(t_arm_l, 0.25, _euler_to_quat(-25.0, 0.0,  30.0))
	anim.track_insert_key(t_arm_l, 0.50, _euler_to_quat( 25.0, 0.0,  30.0))
	_set_track_interpolation(anim, t_arm_l, Animation.INTERPOLATION_CUBIC)

	# ── Right Arm: opposite phase ─────────────────────────────────────────────
	var t_arm_r := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(t_arm_r, "../ArmRight")
	anim.track_insert_key(t_arm_r, 0.00, _euler_to_quat(-25.0, 0.0, -30.0))
	anim.track_insert_key(t_arm_r, 0.25, _euler_to_quat( 25.0, 0.0, -30.0))
	anim.track_insert_key(t_arm_r, 0.50, _euler_to_quat(-25.0, 0.0, -30.0))
	_set_track_interpolation(anim, t_arm_r, Animation.INTERPOLATION_CUBIC)

	# ── Left Leg: forward then back ───────────────────────────────────────────
	var t_leg_l := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(t_leg_l, "../LegLeft")
	anim.track_insert_key(t_leg_l, 0.00, _euler_to_quat( 20.0, 0.0, 0.0))
	anim.track_insert_key(t_leg_l, 0.25, _euler_to_quat(-20.0, 0.0, 0.0))
	anim.track_insert_key(t_leg_l, 0.50, _euler_to_quat( 20.0, 0.0, 0.0))
	_set_track_interpolation(anim, t_leg_l, Animation.INTERPOLATION_CUBIC)

	# ── Right Leg: opposite phase ─────────────────────────────────────────────
	var t_leg_r := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(t_leg_r, "../LegRight")
	anim.track_insert_key(t_leg_r, 0.00, _euler_to_quat(-20.0, 0.0, 0.0))
	anim.track_insert_key(t_leg_r, 0.25, _euler_to_quat( 20.0, 0.0, 0.0))
	anim.track_insert_key(t_leg_r, 0.50, _euler_to_quat(-20.0, 0.0, 0.0))
	_set_track_interpolation(anim, t_leg_r, Animation.INTERPOLATION_CUBIC)

	# ── Body squash: slight vertical compression during mid-stride ────────────
	var t_body_s := anim.add_track(Animation.TYPE_SCALE_3D)
	anim.track_set_path(t_body_s, "../Body")
	anim.track_insert_key(t_body_s, 0.00, Vector3(1.0, 1.00, 1.0))
	anim.track_insert_key(t_body_s, 0.125,Vector3(1.0, 0.97, 1.0))
	anim.track_insert_key(t_body_s, 0.25, Vector3(1.0, 1.00, 1.0))
	anim.track_insert_key(t_body_s, 0.375,Vector3(1.0, 0.97, 1.0))
	anim.track_insert_key(t_body_s, 0.50, Vector3(1.0, 1.00, 1.0))
	_set_track_interpolation(anim, t_body_s, Animation.INTERPOLATION_CUBIC)

	return anim

## JUMP — arms raise to +45° in 0.15 s then hold for rest of clip (1.0 s total).
## The clip does NOT loop — Player3D keeps calling update_animation("jump")
## every frame while airborne, so it simply holds on the last keyframe.
func _make_anim_jump() -> Animation:
	var anim := Animation.new()
	anim.length    = 1.0
	anim.loop_mode = Animation.LOOP_NONE

	# ── Arms raise up quickly ─────────────────────────────────────────────────
	var t_arm_l := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(t_arm_l, "../ArmLeft")
	anim.track_insert_key(t_arm_l, 0.00, _euler_to_quat(  0.0, 0.0,  30.0))
	anim.track_insert_key(t_arm_l, 0.15, _euler_to_quat(-45.0, 0.0,  30.0))
	anim.track_insert_key(t_arm_l, 1.00, _euler_to_quat(-45.0, 0.0,  30.0))
	_set_track_interpolation(anim, t_arm_l, Animation.INTERPOLATION_CUBIC)

	var t_arm_r := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(t_arm_r, "../ArmRight")
	anim.track_insert_key(t_arm_r, 0.00, _euler_to_quat(  0.0, 0.0, -30.0))
	anim.track_insert_key(t_arm_r, 0.15, _euler_to_quat(-45.0, 0.0, -30.0))
	anim.track_insert_key(t_arm_r, 1.00, _euler_to_quat(-45.0, 0.0, -30.0))
	_set_track_interpolation(anim, t_arm_r, Animation.INTERPOLATION_CUBIC)

	# ── Legs tuck slightly upward ─────────────────────────────────────────────
	var t_leg_l := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(t_leg_l, "../LegLeft")
	anim.track_insert_key(t_leg_l, 0.00, _euler_to_quat( 0.0, 0.0, 0.0))
	anim.track_insert_key(t_leg_l, 0.15, _euler_to_quat(15.0, 0.0, 0.0))
	anim.track_insert_key(t_leg_l, 1.00, _euler_to_quat(15.0, 0.0, 0.0))

	var t_leg_r := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(t_leg_r, "../LegRight")
	anim.track_insert_key(t_leg_r, 0.00, _euler_to_quat( 0.0, 0.0, 0.0))
	anim.track_insert_key(t_leg_r, 0.15, _euler_to_quat(15.0, 0.0, 0.0))
	anim.track_insert_key(t_leg_r, 1.00, _euler_to_quat(15.0, 0.0, 0.0))

	# ── Body stretch (opposite of squash) ─────────────────────────────────────
	var t_body_s := anim.add_track(Animation.TYPE_SCALE_3D)
	anim.track_set_path(t_body_s, "../Body")
	anim.track_insert_key(t_body_s, 0.00, Vector3(1.0, 1.00, 1.0))
	anim.track_insert_key(t_body_s, 0.15, Vector3(0.9, 1.08, 0.9))
	anim.track_insert_key(t_body_s, 1.00, Vector3(0.9, 1.08, 0.9))
	_set_track_interpolation(anim, t_body_s, Animation.INTERPOLATION_CUBIC)

	return anim

## DIVE — body pitches forward -90°X in 0.10 s then holds.
## Arms spread wide to either side for aerodynamic look.
func _make_anim_dive() -> Animation:
	var anim := Animation.new()
	anim.length    = 1.0
	anim.loop_mode = Animation.LOOP_NONE

	# ── Body pitches forward ──────────────────────────────────────────────────
	var t_body := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(t_body, "../Body")
	anim.track_insert_key(t_body, 0.00, _euler_to_quat(  0.0, 0.0, 0.0))
	anim.track_insert_key(t_body, 0.10, _euler_to_quat(-90.0, 0.0, 0.0))
	anim.track_insert_key(t_body, 1.00, _euler_to_quat(-90.0, 0.0, 0.0))
	_set_track_interpolation(anim, t_body, Animation.INTERPOLATION_LINEAR)

	# ── Head stays roughly level so eyes face forward ─────────────────────────
	var t_head := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(t_head, "../Head")
	anim.track_insert_key(t_head, 0.00, _euler_to_quat( 0.0, 0.0, 0.0))
	anim.track_insert_key(t_head, 0.10, _euler_to_quat(70.0, 0.0, 0.0))
	anim.track_insert_key(t_head, 1.00, _euler_to_quat(70.0, 0.0, 0.0))
	_set_track_interpolation(anim, t_head, Animation.INTERPOLATION_LINEAR)

	# ── Arms spread flat — Superman pose ─────────────────────────────────────
	var t_arm_l := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(t_arm_l, "../ArmLeft")
	anim.track_insert_key(t_arm_l, 0.00, _euler_to_quat(0.0, 0.0,  30.0))
	anim.track_insert_key(t_arm_l, 0.10, _euler_to_quat(0.0, 0.0,  85.0))
	anim.track_insert_key(t_arm_l, 1.00, _euler_to_quat(0.0, 0.0,  85.0))
	_set_track_interpolation(anim, t_arm_l, Animation.INTERPOLATION_LINEAR)

	var t_arm_r := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(t_arm_r, "../ArmRight")
	anim.track_insert_key(t_arm_r, 0.00, _euler_to_quat(0.0, 0.0, -30.0))
	anim.track_insert_key(t_arm_r, 0.10, _euler_to_quat(0.0, 0.0, -85.0))
	anim.track_insert_key(t_arm_r, 1.00, _euler_to_quat(0.0, 0.0, -85.0))
	_set_track_interpolation(anim, t_arm_r, Animation.INTERPOLATION_LINEAR)

	# ── Legs trail straight behind ────────────────────────────────────────────
	var t_leg_l := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(t_leg_l, "../LegLeft")
	anim.track_insert_key(t_leg_l, 0.00, _euler_to_quat(  0.0, 0.0, 0.0))
	anim.track_insert_key(t_leg_l, 0.10, _euler_to_quat(-10.0, 0.0, 0.0))
	anim.track_insert_key(t_leg_l, 1.00, _euler_to_quat(-10.0, 0.0, 0.0))

	var t_leg_r := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(t_leg_r, "../LegRight")
	anim.track_insert_key(t_leg_r, 0.00, _euler_to_quat(  0.0, 0.0, 0.0))
	anim.track_insert_key(t_leg_r, 0.10, _euler_to_quat(-10.0, 0.0, 0.0))
	anim.track_insert_key(t_leg_r, 1.00, _euler_to_quat(-10.0, 0.0, 0.0))

	return anim

## ─── HELPERS ─────────────────────────────────────────────────────────────────

## Creates, positions, and adds a MeshInstance3D to this Node3D.
## Returns the new instance so the caller can store a reference.
func _make_part(part_name: String,
				mesh:      Mesh,
				material:  StandardMaterial3D,
				position:  Vector3) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name            = part_name
	inst.mesh            = mesh
	inst.material_override = material
	inst.position        = position
	add_child(inst)
	return inst

## Builds a StandardMaterial3D with the given base parameters.
## emission_enabled=true adds a subtle self-glow (used for eyes).
func _make_mat(albedo:            Color,
			   roughness:         float,
			   metallic:          float,
			   emission_enabled:  bool) -> StandardMaterial3D:
	var mat             := StandardMaterial3D.new()
	mat.albedo_color    = albedo
	mat.roughness       = roughness
	mat.metallic        = metallic
	if emission_enabled:
		mat.emission_enabled          = true
		mat.emission                  = albedo
		mat.emission_energy_multiplier = 0.25
	return mat

## Converts Euler angles (degrees, XYZ order) to a Quaternion for rotation tracks.
## Godot's Basis.from_euler() expects radians, so we convert here.
func _euler_to_quat(x_deg: float, y_deg: float, z_deg: float) -> Quaternion:
	var b := Basis.from_euler(Vector3(
		deg_to_rad(x_deg),
		deg_to_rad(y_deg),
		deg_to_rad(z_deg)
	))
	return b.get_rotation_quaternion()

## Sets the interpolation mode on every key in a track in one call.
## Saves repetitive per-key setup, especially for multi-key position tracks.
func _set_track_interpolation(anim:          Animation,
							  track_idx:     int,
							  interp:        Animation.InterpolationType) -> void:
	anim.track_set_interpolation_type(track_idx, interp)
