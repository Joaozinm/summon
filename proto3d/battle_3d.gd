class_name Battle3D
extends Node3D
## 3D prototype battle: arena (floor, walls, two pillars, baked navmesh), the v1 combat rules,
## FOCAR, win/lose. Simulation runs in _physics_process (CharacterBody3D needs it); hit-stop
## scales the simulated time like the v1. PLACEHOLDER visuals only.

signal finished(victory: bool, stats: Dictionary)

const PX := 1.0 / 40.0
const ARENA := Rect2(-15.0, -22.5, 30.0, 45.0)  # x / z, metres (v1 1200x1800 px)
const HITSTOP_SCALE := 0.08
const END_DELAY := 1.4
const HERO_SPAWNS := {
	"brenna": Vector3(0.0, 0, 7.0), "kess": Vector3(3.25, 0, 8.0),
	"yara": Vector3(-3.25, 0, 10.5), "orin": Vector3(0.5, 0, 11.75),
}
const GOBLIN_SPAWNS: Array[Vector3] = [
	Vector3(-2.0, 0, -6.5), Vector3(2.25, 0, -6.5), Vector3(0.125, 0, -8.5),
	Vector3(-3.25, 0, -10.5), Vector3(3.5, 0, -10.5),
]
const PILLARS: Array[Vector3] = [Vector3(-5.0, 0, 0.0), Vector3(5.5, 0, 1.5)]

var hero_ids: Array[String] = []
var units: Array[Unit3D] = []
var projectiles: Array[Projectile3D] = []
var time := 0.0
var over := false
var victory := false
var telemetry := {}

var focus_target: Unit3D
var focus_left := 0.0
var focus_cd := 0.0
var focus_armed := false

var camera: CameraBG3
var hud: Hud3D
var nav_region: NavigationRegion3D

var _hitstop := 0.0
var _end_timer := -1.0
var _units_root: Node3D
var _fx: Node3D
var _focus_ring: MeshInstance3D
var _focus_chevron: Label3D


func _ready() -> void:
	_build_arena()
	_units_root = Node3D.new()
	add_child(_units_root)
	_fx = Node3D.new()
	add_child(_fx)
	for id in hero_ids:
		_spawn(id, Defs.HEROES[id], Unit3D.TEAM_HEROES, HERO_SPAWNS[id])
	for i in Defs.GOBLIN_ORDER.size():
		var gid: String = Defs.GOBLIN_ORDER[i]
		_spawn(gid, Defs.GOBLINS[gid], Unit3D.TEAM_GOBLINS, GOBLIN_SPAWNS[i])
	_build_focus_marker()
	camera = CameraBG3.new()
	camera.battle = self
	add_child(camera)
	SoftToon.add_screen_pass(camera.cam)
	hud = Hud3D.new()
	hud.battle = self
	add_child(hud)
	GameLog.event("battle3d_start heroes=%d goblins=%d renderer=%s navmesh_polygons=%d" % [alive(0).size(),
			alive(1).size(), RenderingServer.get_current_rendering_method(),
			nav_region.navigation_mesh.get_polygon_count()])
	_log_nav_probe.call_deferred()


## One-off check that paths really go around the pillars (logged once the nav map has synced;
## region sync is asynchronous in 4.7 — until then nav_dir falls back to a straight line).
func _log_nav_probe() -> void:
	for i in 60:
		await get_tree().physics_frame
	var from := PILLARS[0] + Vector3(0, 0, 3.0)
	var to := PILLARS[0] + Vector3(0, 0, -3.0)
	var map := get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	GameLog.event("nav_probe around pillar: straight=%.1fm path=%.1fm points=%d" % [from.distance_to(to), length, path.size()])


# --- arena -------------------------------------------------------------------------------------

func _build_arena() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("1b1f2a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("6b7590")
	env.environment.ambient_light_energy = 0.6
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -32, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)

	nav_region = NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.cell_size = 0.25  # must match the navigation map (default 0.25)
	nm.cell_height = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_region.navigation_mesh = nm
	add_child(nav_region)
	var stone := SoftToon.make(null, Color("6f7466"), false)
	var wall_mat := SoftToon.make(null, Color("4d4a55"))
	_box(Vector3(ARENA.get_center().x, -0.1, ARENA.get_center().y), Vector3(ARENA.size.x, 0.2, ARENA.size.y), stone)
	var t := 1.0
	var h := 1.2
	var c := ARENA.get_center()
	_box(Vector3(c.x, h * 0.5, ARENA.position.y - t * 0.5), Vector3(ARENA.size.x + 2 * t, h, t), wall_mat)
	_box(Vector3(c.x, h * 0.5, ARENA.end.y + t * 0.5), Vector3(ARENA.size.x + 2 * t, h, t), wall_mat)
	_box(Vector3(ARENA.position.x - t * 0.5, h * 0.5, c.y), Vector3(t, h, ARENA.size.y), wall_mat)
	_box(Vector3(ARENA.end.x + t * 0.5, h * 0.5, c.y), Vector3(t, h, ARENA.size.y), wall_mat)
	for p in PILLARS:
		_pillar(p, wall_mat)
	nav_region.bake_navigation_mesh(false)


func _box(center: Vector3, size: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	body.add_child(mesh)
	nav_region.add_child(body)


func _pillar(at: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.position = at + Vector3(0, 1.5, 0)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.9
	shape.height = 3.0
	col.shape = shape
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.8
	cyl.bottom_radius = 0.9
	cyl.height = 3.0
	mesh.mesh = cyl
	mesh.material_override = mat
	body.add_child(mesh)
	nav_region.add_child(body)


func _spawn(id: String, def: Dictionary, team: int, pos: Vector3) -> void:
	var u := Unit3D.new()
	u.setup(id, def, team, self)
	u.position = pos
	u.brain = Brains3D.make(def.brain)
	u.brain.setup(u, self)
	units.append(u)
	_units_root.add_child(u)


# --- simulation --------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if over:
		return
	var factor := 1.0
	if _hitstop > 0.0:
		_hitstop -= delta
		factor = HITSTOP_SCALE
	var sim := delta * factor
	time += sim
	focus_cd = maxf(0.0, focus_cd - sim)
	if focus_left > 0.0:
		track("focus_active_s", sim)
		focus_left -= sim
		if focus_left <= 0.0 or focus_target == null or focus_target.dead:
			_end_focus()
	for u in units:
		if not u.dead:
			u.tick(sim, factor)
	for p in projectiles:
		p.tick(sim)
	projectiles = projectiles.filter(func(p: Projectile3D) -> bool: return not p.done)
	_update_focus_marker()
	if _end_timer >= 0.0:
		_end_timer -= delta
		if _end_timer < 0.0:
			_finish()


func alive(team: int) -> Array[Unit3D]:
	var out: Array[Unit3D] = []
	for u in units:
		if u.team == team and not u.dead:
			out.append(u)
	return out


func hero_centroid() -> Vector3:
	var heroes := alive(Unit3D.TEAM_HEROES)
	if heroes.is_empty():
		heroes = units.filter(func(u: Unit3D) -> bool: return u.is_hero())
	var sum := Vector3.ZERO
	for h in heroes:
		sum += h.flat_pos()
	return sum / maxf(heroes.size(), 1)


func track(key: String, amount := 1.0) -> void:
	telemetry[key] = telemetry.get(key, 0.0) + amount


# --- combat ------------------------------------------------------------------------------------

func melee_hit(src: Unit3D, tgt: Unit3D, amount: float) -> void:
	Sfx.play(&"golpe")
	deal_damage(src, tgt, amount)


func spawn_projectile(src: Unit3D, tgt: Unit3D, amount: float) -> void:
	var p := Projectile3D.new()
	p.setup(src, tgt, amount, self)
	projectiles.append(p)
	_fx.add_child(p)
	Sfx.play(&"disparo")


func projectile_hit(p: Projectile3D, tgt: Unit3D) -> void:
	deal_damage(p.source, tgt, p.amount)


func deal_damage(src: Unit3D, tgt: Unit3D, amount: float) -> void:
	if tgt.dead:
		return
	tgt.take_hit(amount, src)
	var heavy := amount >= Defs.HEAVY_HIT
	var color := Color.WHITE if tgt.team == Unit3D.TEAM_GOBLINS else Color("ff9b6b")
	Fx3D.number(_fx, tgt.head(), str(roundi(amount)), color, heavy)
	Fx3D.burst(_fx, tgt.chest(), Color(tgt.def.color).lightened(0.35), 14 if heavy else 8)
	if heavy:
		Sfx.play(&"impacto_pesado")
		camera.shake(0.25)
		_hitstop = maxf(_hitstop, 0.06)
	else:
		Sfx.play(&"impacto")
	if tgt.hp <= 0.0:
		_kill(tgt, src)


func heal(src: Unit3D, tgt: Unit3D, amount: float) -> void:
	var gained := tgt.restore(amount)
	track("orin_heals")
	Fx3D.number(_fx, tgt.head(), "+%d" % roundi(gained), Color("7dff9a"))
	if src != tgt:
		Fx3D.beam(_fx, src.chest(), tgt.chest(), Color(src.def.accent))
	Fx3D.burst(_fx, tgt.chest(), Color("9dffb0"), 6)
	Sfx.play(&"cura")


func _kill(victim: Unit3D, killer: Unit3D) -> void:
	victim.die()
	Sfx.play(&"morte")
	camera.shake(0.18)
	_hitstop = maxf(_hitstop, 0.09)
	Fx3D.burst(_fx, victim.chest(), Color(victim.def.color), 22)
	Fx3D.tombstone(_fx, victim.flat_pos())
	GameLog.event("kill %s by %s" % [victim.def.name, killer.def.name if killer else "-"])
	if killer != null and not killer.dead:
		killer.brain.on_kill(victim)
	if victim == focus_target:
		_end_focus()
	_check_end()


func _check_end() -> void:
	if _end_timer >= 0.0:
		return
	if alive(Unit3D.TEAM_GOBLINS).is_empty():
		victory = true
	elif alive(Unit3D.TEAM_HEROES).is_empty():
		victory = false
	else:
		return
	_end_timer = END_DELAY
	focus_armed = false
	_end_focus()


func decided() -> bool:
	return _end_timer >= 0.0 or over


func stats() -> Dictionary:
	return {
		"time": time,
		"heroes_alive": alive(Unit3D.TEAM_HEROES).size(),
		"heroes_total": hero_ids.size(),
		"goblins_killed": Defs.GOBLIN_ORDER.size() - alive(Unit3D.TEAM_GOBLINS).size(),
		"dead": ",".join(units.filter(func(u: Unit3D) -> bool: return u.is_hero() and u.dead)
				.map(func(u: Unit3D) -> String: return u.id)),
	}


func _finish() -> void:
	over = true
	hud.visible = false
	Sfx.play(&"vitoria" if victory else &"derrota")
	var s := stats()
	GameLog.event("battle3d_end victory=%s stats=%s telemetry=%s" % [victory, s, telemetry])
	finished.emit(victory, s)


# --- FOCAR -------------------------------------------------------------------------------------

func focus_ready() -> bool:
	return focus_cd <= 0.0 and not decided()


func focus_active() -> bool:
	return focus_left > 0.0 and focus_target != null and not focus_target.dead


func arm_focus() -> void:
	if focus_ready():
		focus_armed = not focus_armed


func request_focus(target: Unit3D) -> bool:
	if not focus_ready() or target == null or target.dead or target.team != Unit3D.TEAM_GOBLINS:
		return false
	focus_target = target
	focus_left = Defs.FOCUS_DURATION
	focus_cd = Defs.FOCUS_COOLDOWN
	focus_armed = false
	Sfx.play(&"foco")
	GameLog.event("focus %s" % target.def.name)
	return true


func _end_focus() -> void:
	focus_left = 0.0
	focus_target = null


func _unhandled_input(event: InputEvent) -> void:
	if over:
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var g := goblin_at_screen(mb.position)
	if g != null and request_focus(g):
		get_viewport().set_input_as_handled()


## Goblin under a screen point: distance to its projected feet→head segment, nearest first.
func goblin_at_screen(point: Vector2) -> Unit3D:
	var best: Unit3D = null
	var best_d := 36.0
	for g in alive(Unit3D.TEAM_GOBLINS):
		if camera.cam.is_position_behind(g.chest()):
			continue
		var a := camera.cam.unproject_position(g.global_position)
		var b := camera.cam.unproject_position(g.head())
		var d := point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b))
		if d < best_d:
			best_d = d
			best = g
	return best


func _build_focus_marker() -> void:
	_focus_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.75
	torus.outer_radius = 0.92
	_focus_ring.mesh = torus
	_focus_ring.scale = Vector3(1.0, 0.05, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("ff3b3b")
	_focus_ring.material_override = m
	_focus_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_focus_ring.visible = false
	add_child(_focus_ring)
	_focus_chevron = Label3D.new()
	_focus_chevron.text = "▼"
	_focus_chevron.font_size = 64
	_focus_chevron.pixel_size = 0.006
	_focus_chevron.modulate = Color("ff3b3b")
	_focus_chevron.outline_size = 10
	_focus_chevron.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_focus_chevron.no_depth_test = true
	_focus_chevron.visible = false
	add_child(_focus_chevron)


func _update_focus_marker() -> void:
	var on := focus_active()
	_focus_ring.visible = on
	_focus_chevron.visible = on
	if on:
		var pulse := 1.0 + sin(time * 8.0) * 0.08
		_focus_ring.global_position = focus_target.flat_pos() + Vector3(0, 0.04, 0)
		_focus_ring.scale = Vector3(pulse, 0.05, pulse) * (1.0 + focus_target.radius)
		_focus_chevron.global_position = focus_target.head() + Vector3(0, 0.55 + sin(time * 6.0) * 0.08, 0)


## Test hook: kills every hero through the normal damage pipeline (forces the defeat path).
func debug_defeat() -> void:
	for h in alive(Unit3D.TEAM_HEROES):
		deal_damage(null, h, 9999.0)
