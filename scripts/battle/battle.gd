class_name Battle
extends Node2D
## One arena fight. Owns the simulation loop (units, projectiles, hit-stop), FOCAR state,
## combat resolution and win/lose detection. Built entirely in code.

signal finished(victory: bool, stats: Dictionary)

const ARENA := Rect2(0, 0, 1200, 1800)
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


func _ready() -> void:
	_ground = Node2D.new()
	add_child(_ground)
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)
	var marker := FocusMarker.new()
	marker.battle = self
	marker.z_index = 10
	add_child(marker)
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
	Fx.damage_number(_fx, tgt.position, str(roundi(amount)), color, heavy)
	Fx.burst(_fx, tgt.position, tgt.def.color.lightened(0.35), 14 if heavy else 8)
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
	Fx.damage_number(_fx, tgt.position, "+%d" % roundi(gained), Color("7dff9a"))
	if src != tgt:
		Fx.beam(_fx, src.position, tgt.position, Color(src.def.accent, 0.9))
	Fx.burst(_fx, tgt.position, Color("9dffb0"), 6, 80.0)
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
	Fx.burst(_fx, victim.position, victim.def.color, 22, 200.0)
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


func goblin_at(world: Vector2) -> Unit:
	var best: Unit = null
	var best_d := INF
	for g in alive(Unit.TEAM_GOBLINS):
		var d := g.position.distance_to(world)
		if d <= g.radius + 28.0 and d < best_d:
			best_d = d
			best = g
	return best


## Test hook: kills every hero through the normal damage pipeline (forces the defeat path).
func debug_defeat() -> void:
	for h in alive(Unit.TEAM_HEROES):
		deal_damage(null, h, 9999.0)


# PLACEHOLDER TEMPORÁRIO — substituído pela arte final da Muse (arena floor from primitives).
func _draw() -> void:
	draw_rect(ARENA.grow(600), Color("0e1014"))
	draw_rect(ARENA, Color("22252c"))
	var grid := Color(1, 1, 1, 0.035)
	for x in range(100, int(ARENA.size.x), 100):
		draw_line(Vector2(x, 0), Vector2(x, ARENA.size.y), grid, 2.0)
	for y in range(100, int(ARENA.size.y), 100):
		draw_line(Vector2(0, y), Vector2(ARENA.size.x, y), grid, 2.0)
	draw_rect(ARENA, Color("4a4f59"), false, 8.0)


## Pulsing ring over the FOCAR target.
class FocusMarker extends Node2D:
	var battle: Battle
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if not battle.focus_active():
			return
		var g := battle.focus_target
		var r := g.radius + 12.0 + sin(_t * 8.0) * 3.0
		var c := Color("ff3b3b")
		draw_arc(g.position, r, 0.0, TAU, 40, c, 3.0)
		for k in 4:
			var dir := Vector2.RIGHT.rotated(k * PI / 2.0 + _t * 1.5)
			draw_line(g.position + dir * (r + 2.0), g.position + dir * (r + 12.0), c, 3.0)
