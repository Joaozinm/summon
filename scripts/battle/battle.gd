class_name Battle
extends Node2D
## One arena fight. Owns the simulation loop (units, projectiles, hit-stop), FOCAR state,
## combat resolution and win/lose detection. Built entirely in code.

signal finished(victory: bool, stats: Dictionary)

const ARENA := Rect2(0, 0, 1200, 1800)
const ARENA_ART := "res://assets/final/arena-fundo.webp"
const HITSTOP_SCALE := 0.08
const END_DELAY := 1.4
const HERO_SPAWNS := {
	"brenna": Vector2(600, 1180), "kess": Vector2(730, 1220),
	"yara": Vector2(470, 1320), "orin": Vector2(620, 1370),
}
const GOBLIN_SPAWNS: Array[Vector2] = [
	Vector2(520, 640), Vector2(690, 640), Vector2(605, 560), Vector2(470, 480), Vector2(740, 480),
]

var hero_ids: Array[String] = []
var units: Array[Unit] = []
var projectiles: Array[Projectile] = []
var time := 0.0
var over := false
## Behavior counters (simulated seconds spent in each AI state, or event counts).
var telemetry := {}
var victory := false

var focus_target: Unit
var focus_left := 0.0
var focus_cd := 0.0
var focus_armed := false

var camera: BattleCamera
var hud: BattleHud

var _hitstop := 0.0
var _end_timer := -1.0
var _ground: Node2D
var _world: Node2D
var _fx: Node2D
var _arena_tex: Texture2D


func _ready() -> void:
	_arena_tex = load(ARENA_ART)
	_ground = Node2D.new()
	add_child(_ground)
	var ring := FocusMarker.new()  # on the ground, under the sprites
	ring.battle = self
	add_child(ring)
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)
	var chevron := FocusMarker.new()  # above the target's head, over everything
	chevron.battle = self
	chevron.overhead = true
	chevron.z_index = 10
	add_child(chevron)
	_fx = Node2D.new()
	_fx.z_index = 20
	add_child(_fx)

	for id in hero_ids:
		_spawn(id, Defs.HEROES[id], Unit.TEAM_HEROES, HERO_SPAWNS[id])
	for i in Defs.GOBLIN_ORDER.size():
		var gid: String = Defs.GOBLIN_ORDER[i]
		_spawn(gid, Defs.GOBLINS[gid], Unit.TEAM_GOBLINS, GOBLIN_SPAWNS[i])

	camera = BattleCamera.new()
	camera.battle = self
	add_child(camera)
	camera.make_current()
	camera.snap()
	hud = BattleHud.new()
	hud.battle = self
	add_child(hud)
	GameLog.event("battle_start heroes=%d goblins=%d" % [alive(0).size(), alive(1).size()])


func _spawn(id: String, def: Dictionary, team: int, pos: Vector2) -> void:
	var u := Unit.new()
	u.setup(id, def, team, self)
	u.position = pos
	u.brain = _make_brain(def.brain)
	u.brain.setup(u, self)
	units.append(u)
	_world.add_child(u)


static func _make_brain(kind: String) -> Brain:
	match kind:
		"muralha": return BrennaMuralha.new()
		"paciencia": return YaraPaciencia.new()
		"triagem": return OrinTriagem.new()
		"oportunista": return KessOportunista.new()
		"rastejante": return GoblinBrains.Rastejante.new()
		"fundeiro": return GoblinBrains.Fundeiro.new()
		"bruto": return GoblinBrains.Bruto.new()
	push_error("unknown brain: %s" % kind)
	return Brain.new()


# --- simulation ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if over:
		return
	var sim := delta
	if _hitstop > 0.0:
		_hitstop -= delta
		sim *= HITSTOP_SCALE
	_tick(sim)
	if _end_timer >= 0.0:
		_end_timer -= delta
		if _end_timer < 0.0:
			_finish()


func _tick(delta: float) -> void:
	time += delta
	focus_cd = maxf(0.0, focus_cd - delta)
	if focus_left > 0.0:
		track("focus_active_s", delta)
		focus_left -= delta
		if focus_left <= 0.0 or focus_target == null or focus_target.dead:
			_end_focus()
	for u in units:
		if not u.dead:
			u.tick(delta)
	_separate()
	for p in projectiles:
		p.tick(delta)
	projectiles = projectiles.filter(func(p: Projectile) -> bool: return not p.done)


func _separate() -> void:
	var live: Array[Unit] = units.filter(func(u: Unit) -> bool: return not u.dead)
	for i in live.size():
		for j in range(i + 1, live.size()):
			var a := live[i]
			var b := live[j]
			var d := b.position - a.position
			var min_d := a.radius + b.radius + 2.0
			var l := d.length()
			if l >= min_d:
				continue
			if l < 0.01:
				d = Vector2.RIGHT.rotated(randf() * TAU)
				l = 1.0
			var push := d / l * (min_d - l)
			var wa := b.radius / (a.radius + b.radius)  # bigger bodies get pushed less
			a.position -= push * wa
			b.position += push * (1.0 - wa)
	for u in live:
		u.position = u.position.clamp(ARENA.position + Vector2.ONE * u.radius,
				ARENA.end - Vector2.ONE * u.radius)


# --- queries ---------------------------------------------------------------------------------

func alive(team: int) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in units:
		if u.team == team and not u.dead:
			out.append(u)
	return out


func hero_centroid() -> Vector2:
	var heroes := alive(Unit.TEAM_HEROES)
	if heroes.is_empty():
		heroes = units.filter(func(u: Unit) -> bool: return u.is_hero())
	if heroes.is_empty():
		return ARENA.get_center()
	var sum := Vector2.ZERO
	for h in heroes:
		sum += h.position
	return sum / heroes.size()


# --- combat ----------------------------------------------------------------------------------

func melee_hit(src: Unit, tgt: Unit, amount: float) -> void:
	Sfx.play(&"golpe")
	deal_damage(src, tgt, amount)


func spawn_projectile(src: Unit, tgt: Unit, amount: float) -> void:
	var p := Projectile.new()
	p.setup(src, tgt, amount, self)
	projectiles.append(p)
	_fx.add_child(p)
	Sfx.play(&"disparo")


func projectile_hit(p: Projectile, tgt: Unit) -> void:
	if tgt != p.target and tgt.id == "brenna":
		track("brenna_shots_blocked")
	deal_damage(p.source, tgt, p.amount)


func deal_damage(src: Unit, tgt: Unit, amount: float) -> void:
	if tgt.dead:
		return
	tgt.take_hit(amount, src)
	var heavy := amount >= Defs.HEAVY_HIT
	var color := Color.WHITE if tgt.team == Unit.TEAM_GOBLINS else Color("ff9b6b")
	Fx.damage_number(_fx, tgt.chest(), str(roundi(amount)), color, heavy)
	Fx.burst(_fx, tgt.chest(), tgt.def.color.lightened(0.35), 14 if heavy else 8)
	if heavy:
		Sfx.play(&"impacto_pesado")
		camera.shake(9.0)
		hitstop(0.06)
	else:
		Sfx.play(&"impacto")
	if tgt.hp <= 0.0:
		_kill(tgt, src)


func heal(src: Unit, tgt: Unit, amount: float) -> void:
	var gained := tgt.restore(amount)
	track("orin_heals")
	Fx.damage_number(_fx, tgt.chest(), "+%d" % roundi(gained), Color("7dff9a"))
	if src != tgt:
		Fx.beam(_fx, src.chest(), tgt.chest(), Color(src.def.accent, 0.9))
	Fx.burst(_fx, tgt.chest(), Color("9dffb0"), 6, 80.0)
	Sfx.play(&"cura")


## Accumulate an AI-behavior counter (seconds when called with the tick delta).
func track(key: String, amount := 1.0) -> void:
	telemetry[key] = telemetry.get(key, 0.0) + amount


func hitstop(duration: float) -> void:
	_hitstop = maxf(_hitstop, duration)


func _kill(victim: Unit, killer: Unit) -> void:
	victim.die()
	Sfx.play(&"morte")
	camera.shake(6.0)
	hitstop(0.09)
	Fx.burst(_fx, victim.chest(), victim.def.color, 22, 200.0)
	Fx.tombstone(_ground, victim.position)
	GameLog.event("kill %s by %s" % [victim.def.name, killer.def.name if killer else "-"])
	if killer != null and not killer.dead:
		killer.brain.on_kill(victim)
	if victim == focus_target:
		_end_focus()
	_check_end()


func _check_end() -> void:
	if _end_timer >= 0.0:
		return
	if alive(Unit.TEAM_GOBLINS).is_empty():
		victory = true
	elif alive(Unit.TEAM_HEROES).is_empty():
		victory = false
	else:
		return
	_end_timer = END_DELAY
	focus_armed = false
	_end_focus()


func _finish() -> void:
	over = true
	hud.visible = false
	Sfx.play(&"vitoria" if victory else &"derrota")
	var stats := {
		"time": time,
		"heroes_alive": alive(Unit.TEAM_HEROES).size(),
		"heroes_total": hero_ids.size(),
		"goblins_killed": Defs.GOBLIN_ORDER.size() - alive(Unit.TEAM_GOBLINS).size(),
	}
	GameLog.event("battle_end victory=%s stats=%s" % [victory, stats])
	var rounded := {}
	for k: String in telemetry:
		rounded[k] = snappedf(telemetry[k], 0.1)
	GameLog.event("telemetry %s" % rounded)
	finished.emit(victory, stats)


# --- FOCAR -----------------------------------------------------------------------------------

func focus_ready() -> bool:
	return focus_cd <= 0.0 and not over and _end_timer < 0.0


func focus_active() -> bool:
	return focus_left > 0.0 and focus_target != null and not focus_target.dead


func arm_focus() -> void:
	if focus_ready():
		focus_armed = not focus_armed


func request_focus(target: Unit) -> bool:
	if not focus_ready() or target == null or target.dead or target.team != Unit.TEAM_GOBLINS:
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
	var world := get_viewport().get_canvas_transform().affine_inverse() * mb.position
	var g := goblin_at(world)
	if g != null and request_focus(g):
		get_viewport().set_input_as_handled()


## Goblin under a tap: anywhere on its visible sprite body (or near its feet), nearest first.
func goblin_at(world: Vector2) -> Unit:
	var best: Unit = null
	var best_d := INF
	for g in alive(Unit.TEAM_GOBLINS):
		var local := world - g.position
		var on_body := g.body_rect().grow(10.0).has_point(local)
		if not on_body and local.length() > g.radius + 28.0:
			continue
		var d := world.distance_to(g.chest())
		if d < best_d:
			best_d = d
			best = g
	return best


## Test hook: kills every hero through the normal damage pipeline (forces the defeat path).
func debug_defeat() -> void:
	for h in alive(Unit.TEAM_HEROES):
		deal_damage(null, h, 9999.0)


## Arena floor: the Muse's arena art, scaled uniformly to the arena height (the rune circle's top and
## bottom map to the arena bounds); the sides are cropped and softened into the dark surround.
func _draw() -> void:
	draw_rect(ARENA.grow(600), Color("0b0c0f"))
	var ts := _arena_tex.get_size()
	var k := ARENA.size.y / ts.y
	var src_w := minf(ts.x, ARENA.size.x / k)
	# Dimmed so the characters read first.
	draw_texture_rect_region(_arena_tex, ARENA, Rect2((ts.x - src_w) * 0.5, 0.0, src_w, ts.y),
			Color(0.55, 0.57, 0.62))
	var edge := Color(0.043, 0.047, 0.059, 0.85)
	var clear := Color(edge, 0.0)
	var band := 140.0
	draw_polygon(PackedVector2Array([ARENA.position, ARENA.position + Vector2(band, 0),
			Vector2(band, ARENA.end.y), Vector2(0, ARENA.end.y)]),
			PackedColorArray([edge, clear, clear, edge]))
	draw_polygon(PackedVector2Array([Vector2(ARENA.end.x - band, 0), Vector2(ARENA.end.x, 0),
			ARENA.end, Vector2(ARENA.end.x - band, ARENA.end.y)]),
			PackedColorArray([clear, edge, edge, clear]))
	draw_rect(ARENA, Color(0, 0, 0, 0.6), false, 6.0)


## FOCAR target marker: a pulsing ground ring under the target, or (overhead) a chevron above it.
class FocusMarker extends Node2D:
	var battle: Battle
	var overhead := false
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if not battle.focus_active():
			return
		var g := battle.focus_target
		var c := Color("ff3b3b")
		if overhead:
			var tip := g.position + Vector2(0, g.body_rect().position.y - 38.0 + sin(_t * 6.0) * 4.0)
			draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-11, -14), tip + Vector2(11, -14)]), c)
			return
		var r := g.radius + 14.0 + sin(_t * 8.0) * 3.0
		draw_set_transform(g.position + Vector2(0, g.radius * 0.9), 0.0, Vector2(1.0, 0.45))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, c, 4.0)
		for k in 4:
			var dir := Vector2.RIGHT.rotated(k * PI / 2.0 + _t * 1.5)
			draw_line(dir * (r + 2.0), dir * (r + 12.0), c, 4.0)
