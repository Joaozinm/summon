class_name Unit3D
extends CharacterBody3D
## 3D prototype unit (hero or goblin). Same combat rules as the v1 Unit, on the XZ plane, in metres
## (v1 pixels / 40). Movement: NavigationAgent3D path + move_and_slide. Driven by Battle3D.
## PLACEHOLDER visuals only (Kenney Survivors CC0 for heroes, primitives for goblins).

const PX := 1.0 / 40.0
const TEAM_HEROES := 0
const TEAM_GOBLINS := 1
const KENNEY := "res://proto3d/vendor/kenney_survivors/"

## Placeholder look per unit: skin/tint for heroes (Kenney), colour/height for goblins (capsules).
const LOOK := {
	"brenna": {"skin": "survivorFemaleA", "height": 1.95},
	"yara": {"skin": "survivorFemaleA", "height": 1.8},
	"orin": {"skin": "survivorMaleB", "height": 1.85},
	"kess": {"skin": "survivorFemaleA", "height": 1.75},
	"rastejante": {"color": Color("8fa83a"), "height": 1.15},
	"fundeiro": {"color": Color("c99a3a"), "height": 1.3},
	"bruto": {"color": Color("5d7a26"), "height": 2.1},
}

static var _anim_cache := {}

var id: String
var def: Dictionary
var team: int
var battle: Battle3D
var brain: Brains3D.AI

var max_hp: float
var hp: float
var damage: float
var cooldown: float
var speed: float
var radius: float
var attack_range: float  # 0 = melee
var heal_amount: float
var heal_cooldown: float
var height := 1.8

var move_dir := Vector3.ZERO
var attack_cd := 0.0
var heal_cd := 0.0
var last_hit_time := -100.0
var last_attacker: Unit3D
var dead := false

var nav: NavigationAgent3D
var _visual: Node3D
var _anim: AnimationPlayer
var _materials: Array[ShaderMaterial] = []
var _flash := 0.0
var _lunge := 0.0
var _lunge_dir := Vector3.ZERO


func setup(unit_id: String, unit_def: Dictionary, unit_team: int, owner_battle: Battle3D) -> void:
	id = unit_id
	def = unit_def
	team = unit_team
	battle = owner_battle
	max_hp = def.hp
	hp = max_hp
	damage = def.damage
	cooldown = def.cooldown
	speed = float(def.speed) * PX
	radius = float(def.radius) * PX
	attack_range = float(def.range) * PX
	heal_amount = def.get("heal", 0.0)
	heal_cooldown = def.get("heal_cooldown", 0.0)
	height = LOOK[id].height
	attack_cd = randf_range(0.1, 0.4)


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 2 if is_hero() else 4
	collision_mask = 1 | 2 | 4
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = maxf(height, radius * 2.0)
	shape.shape = cap
	shape.position.y = cap.height * 0.5
	add_child(shape)
	nav = NavigationAgent3D.new()
	nav.radius = radius
	nav.path_desired_distance = 0.3
	nav.target_desired_distance = 0.3
	add_child(nav)
	_visual = Node3D.new()
	add_child(_visual)
	if is_hero():
		_build_hero()
	else:
		_build_goblin()


func is_hero() -> bool:
	return team == TEAM_HEROES


func is_ranged() -> bool:
	return attack_range > 0.0


func hp_ratio() -> float:
	return hp / max_hp


func is_wounded() -> bool:
	return hp < max_hp - 0.01


func flat_pos() -> Vector3:
	return Vector3(global_position.x, 0.0, global_position.z)


func chest() -> Vector3:
	return global_position + Vector3(0, height * 0.55, 0)


func head() -> Vector3:
	return global_position + Vector3(0, height + 0.25, 0)


func dist_to(u: Unit3D) -> float:
	return flat_pos().distance_to(u.flat_pos())


func under_attack(window := 1.0) -> bool:
	return battle.time - last_hit_time <= window and is_instance_valid(last_attacker) \
			and not last_attacker.dead


func reach_to(target: Unit3D) -> float:
	return attack_range if is_ranged() else radius + target.radius + 10.0 * PX


func in_reach(target: Unit3D) -> bool:
	return dist_to(target) <= reach_to(target)


## Direction toward `p` along the navmesh path (straight line until the map is ready).
func nav_dir(p: Vector3) -> Vector3:
	nav.target_position = p
	var d := nav.get_next_path_position() - global_position
	d.y = 0.0
	if d.length() < 0.05:
		d = p - global_position
		d.y = 0.0
	return d.normalized()


func tick(delta: float, time_factor: float) -> void:
	attack_cd = maxf(0.0, attack_cd - delta)
	heal_cd = maxf(0.0, heal_cd - delta)
	move_dir = Vector3.ZERO
	brain.think(delta)
	var dir := Vector3(move_dir.x, 0.0, move_dir.z).limit_length(1.0)
	velocity = dir * speed * time_factor
	move_and_slide()
	global_position.y = 0.0
	_update_visual(delta, dir, time_factor)


func try_attack(target: Unit3D) -> bool:
	if target == null or target.dead or attack_cd > 0.0 or not in_reach(target):
		return false
	attack_cd = cooldown
	_face(target.flat_pos() - flat_pos())
	if is_ranged():
		battle.spawn_projectile(self, target, damage)
	else:
		_lunge = 0.15
		_lunge_dir = (target.flat_pos() - flat_pos()).normalized()
		battle.melee_hit(self, target, damage)
	return true


func try_heal(ally: Unit3D) -> bool:
	if heal_amount <= 0.0 or ally == null or ally.dead or heal_cd > 0.0:
		return false
	if dist_to(ally) > attack_range:
		return false
	heal_cd = heal_cooldown
	battle.heal(self, ally, heal_amount)
	return true


func take_hit(amount: float, from: Unit3D) -> void:
	hp = maxf(0.0, hp - amount)
	last_hit_time = battle.time
	last_attacker = from
	_flash = 1.0


func restore(amount: float) -> float:
	var before := hp
	hp = minf(max_hp, hp + amount)
	return hp - before


func die() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 0
	var tw := create_tween()
	tw.tween_property(_visual, "position:y", -height, 0.6).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void: visible = false)


# --- PLACEHOLDER visuals -----------------------------------------------------------------------

func _build_hero() -> void:
	var model := (load(KENNEY + "Model/characterMedium.fbx") as PackedScene).instantiate() as Node3D
	_visual.add_child(model)
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var raw := (mesh.global_transform * mesh.get_aabb()).size.y / maxf(model.scale.y, 0.0001)
	model.scale = Vector3.ONE * (height / raw)
	var skin := load(KENNEY + "Skins/%s.png" % LOOK[id].skin) as Texture2D
	var identity: Color = def.color
	var mat := SoftToon.make(skin, identity.lerp(Color.WHITE, 0.4))
	(mat.next_pass as ShaderMaterial).set_shader_parameter(&"outline_color", identity.darkened(0.35))
	(mat.next_pass as ShaderMaterial).set_shader_parameter(&"outline_width", 4.0)
	mesh.material_override = mat
	_materials.append(mat)
	_anim = AnimationPlayer.new()
	model.add_child(_anim)
	_anim.add_animation_library("", _kenney_anims())
	_anim.play("idle")
	# Identity ring on the ground (same idea as the v1 rings).
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius + 0.28
	torus.outer_radius = radius + 0.4
	ring.mesh = torus
	ring.scale = Vector3(1.0, 0.05, 1.0)
	ring.position.y = 0.03
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = identity.lightened(0.3)
	ring.material_override = rm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)


func _build_goblin() -> void:
	var look: Dictionary = LOOK[id]
	var color: Color = look.color
	var body_r := radius * 1.15
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = body_r
	cap.height = height
	body.mesh = cap
	body.position.y = height * 0.5
	var mat := SoftToon.make(null, color)
	(mat.next_pass as ShaderMaterial).set_shader_parameter(&"outline_color", Color("2a1c08"))
	body.material_override = mat
	_materials.append(mat)
	_visual.add_child(body)
	for side in [-1.0, 1.0]:  # pointy ears: the goblin read at a glance
		var ear := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = body_r * 0.35
		cone.height = body_r * 1.4
		ear.mesh = cone
		ear.position = Vector3(side * body_r * 0.85, height * 0.86, 0.0)
		ear.rotation.z = -side * 1.1
		ear.material_override = mat
		_visual.add_child(ear)


static func _kenney_anims() -> AnimationLibrary:
	if _anim_cache.has("lib"):
		return _anim_cache.lib
	var lib := AnimationLibrary.new()
	for pair: Array in [["idle", "Root|Idle"], ["run", "Root|Run"]]:
		var src_root := (load(KENNEY + "Animations/%s.fbx" % pair[0]) as PackedScene).instantiate()
		var ap := src_root.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var a := ap.get_animation(pair[1]).duplicate() as Animation
		a.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(pair[0], a)
		src_root.free()
	_anim_cache.lib = lib
	return lib


func _face(dir: Vector3) -> void:
	if dir.length() > 0.01:
		_visual.rotation.y = atan2(dir.x, dir.z)


func _update_visual(delta: float, dir: Vector3, time_factor: float) -> void:
	if dir.length() > 0.05:
		_face(dir)
	if _anim != null:
		var want := "run" if dir.length() > 0.05 else "idle"
		if _anim.current_animation != want:
			_anim.play(want, 0.15)
		_anim.speed_scale = time_factor
	_flash = maxf(0.0, _flash - delta * 5.0)
	for m in _materials:
		m.set_shader_parameter(&"emission", Color(_flash, _flash, _flash, 1.0))
	_lunge = maxf(0.0, _lunge - delta)
	var push := sin(_lunge / 0.15 * PI) * 0.25 if _lunge > 0.0 else 0.0
	_visual.position = Vector3(_lunge_dir.x * push, _visual.position.y, _lunge_dir.z * push)
