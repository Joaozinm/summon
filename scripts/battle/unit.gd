class_name Unit
extends Node2D
## A hero or goblin. Simulation is driven by Battle.tick() (not _process), so hit-stop and
## headless speed-ups apply uniformly. Decisions live in `brain`; this class owns stats,
## combat primitives and the placeholder drawing.

const TEAM_HEROES := 0
const TEAM_GOBLINS := 1

var id: String
var def: Dictionary
var team: int
var battle: Battle
var brain: Brain

var max_hp: float
var hp: float
var damage: float
var cooldown: float
var speed: float
var radius: float
var attack_range: float  # 0 = melee
var heal_amount: float
var heal_cooldown: float

var move_dir := Vector2.ZERO
var attack_cd := 0.0
var heal_cd := 0.0
var last_hit_time := -100.0
var last_attacker: Unit
var dead := false

var _flash := 0.0
var _swing := 0.0
var _swing_dir := Vector2.RIGHT
var _name_label: Label


func setup(unit_id: String, unit_def: Dictionary, unit_team: int, owner_battle: Battle) -> void:
	id = unit_id
	def = unit_def
	team = unit_team
	battle = owner_battle
	max_hp = def.hp
	hp = max_hp
	damage = def.damage
	cooldown = def.cooldown
	speed = def.speed
	radius = def.radius
	attack_range = def.range
	heal_amount = def.get("heal", 0.0)
	heal_cooldown = def.get("heal_cooldown", 0.0)
	attack_cd = randf_range(0.1, 0.4)  # desync first swings


func _ready() -> void:
	_name_label = Label.new()
	_name_label.text = def.name
	var ls := LabelSettings.new()
	ls.font_size = 13
	ls.outline_size = 4
	ls.outline_color = Color(0, 0, 0, 0.85)
	_name_label.label_settings = ls
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.size = Vector2(120, 18)
	_name_label.position = Vector2(-60, -_top() - 34)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)


func is_hero() -> bool:
	return team == TEAM_HEROES


func is_ranged() -> bool:
	return attack_range > 0.0


func hp_ratio() -> float:
	return hp / max_hp


func is_wounded() -> bool:
	return hp < max_hp - 0.01


func under_attack(window := 1.0) -> bool:
	return battle.time - last_hit_time <= window and is_instance_valid(last_attacker) \
			and not last_attacker.dead


func reach_to(target: Unit) -> float:
	return attack_range if is_ranged() else radius + target.radius + 10.0


func in_reach(target: Unit) -> bool:
	return position.distance_to(target.position) <= reach_to(target)


func tick(delta: float) -> void:
	attack_cd = maxf(0.0, attack_cd - delta)
	heal_cd = maxf(0.0, heal_cd - delta)
	_flash = maxf(0.0, _flash - delta * 5.0)
	_swing = maxf(0.0, _swing - delta)
	move_dir = Vector2.ZERO
	brain.think(delta)
	position += move_dir.limit_length(1.0) * speed * delta
	queue_redraw()


func try_attack(target: Unit) -> bool:
	if target == null or target.dead or attack_cd > 0.0 or not in_reach(target):
		return false
	attack_cd = cooldown
	if is_ranged():
		battle.spawn_projectile(self, target, damage)
	else:
		_swing = 0.14
		_swing_dir = (target.position - position).normalized()
		battle.melee_hit(self, target, damage)
	return true


func try_heal(ally: Unit) -> bool:
	if heal_amount <= 0.0 or ally == null or ally.dead or heal_cd > 0.0:
		return false
	if position.distance_to(ally.position) > attack_range:
		return false
	heal_cd = heal_cooldown
	battle.heal(self, ally, heal_amount)
	return true


func take_hit(amount: float, from: Unit) -> void:
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
	_name_label.visible = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: visible = false)


# --- PLACEHOLDER TEMPORÁRIO — substituído pela arte final da Muse. -----------------------------
# Heroes: capsule in identity color with accent outline/belt. Goblins: circles.

func _top() -> float:
	return radius * 1.35 if is_hero() else radius


func _draw() -> void:
	var body: Color = def.color
	var accent: Color = def.accent
	if _flash > 0.0:
		body = body.lerp(Color.WHITE, _flash)
		accent = accent.lerp(Color.WHITE, _flash * 0.7)
	draw_set_transform(Vector2(0, radius * 0.9), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, radius * 1.05, Color(0, 0, 0, 0.35))  # ground shadow
	draw_set_transform(Vector2.ZERO)
	if is_hero():
		var half := radius * 0.35
		_capsule(half, radius + 3.0, accent)
		_capsule(half, radius, body)
		draw_rect(Rect2(-radius, -2.0, radius * 2.0, 4.0), accent)
	else:
		draw_circle(Vector2.ZERO, radius + 3.0, accent)
		draw_circle(Vector2.ZERO, radius, body)
		if is_ranged():
			draw_arc(Vector2.ZERO, radius * 0.55, 0.0, TAU, 20, accent, 2.0)
	if _swing > 0.0:
		var a := _swing_dir.angle()
		draw_arc(Vector2.ZERO, radius + 14.0, a - 0.9, a + 0.9, 12,
				Color(1, 1, 1, _swing / 0.14 * 0.8), 3.0)
	_draw_hp_bar()


func _capsule(half: float, r: float, c: Color) -> void:
	draw_circle(Vector2(0, -half), r, c)
	draw_circle(Vector2(0, half), r, c)
	draw_rect(Rect2(-r, -half, r * 2.0, half * 2.0), c)


func _draw_hp_bar() -> void:
	var w := maxf(36.0, radius * 2.4)
	var y := -_top() - 14.0
	draw_rect(Rect2(-w / 2 - 1, y - 1, w + 2, 7), Color(0, 0, 0, 0.8))
	var fill := Color("4fd06a") if is_hero() else Color("e0483c")
	draw_rect(Rect2(-w / 2, y, w * hp_ratio(), 5), fill)
