class_name HeroRings
extends Node2D
## Identity-colour ground ring under each living hero (Brenna crimson, Yara green, Orin blue,
## Kess violet). Battle draws this layer above the goblins and below the heroes, so a hero's
## ring stays visible inside a melee crowd. Faint when the hero stands alone, bright when other
## units crowd them. Render-only.

const CROWD_RADIUS := 70.0
const ALPHA_ALONE := 0.4
const ALPHA_CROWDED := 0.95
const SEGMENTS := 36

var battle: Battle
var _alpha := {}  # Unit -> current alpha (eased)


func _process(delta: float) -> void:
	queue_redraw()
	for h in battle.alive(Unit.TEAM_HEROES):
		var want := ALPHA_CROWDED if _crowded(h) else ALPHA_ALONE
		_alpha[h] = move_toward(_alpha.get(h, ALPHA_ALONE), want, delta * 3.0)


func _crowded(hero: Unit) -> bool:
	for u in battle.units:
		if u != hero and not u.dead and u.position.distance_to(hero.position) < CROWD_RADIUS:
			return true
	return false


func _draw() -> void:
	for h in battle.alive(Unit.TEAM_HEROES):
		var a: float = _alpha.get(h, ALPHA_ALONE)
		var center := h.position + Vector2(0, h.radius * 0.9)
		var rx := h.radius + 14.0
		var pts := PackedVector2Array()
		for i in SEGMENTS + 1:
			var t := TAU * i / SEGMENTS
			pts.append(center + Vector2(cos(t) * rx, sin(t) * rx * 0.42))
		draw_polyline(pts, Color(0, 0, 0, a * 0.7), 7.0, true)
		draw_polyline(pts, Color(h.def.color.lightened(0.35), a), 4.0, true)
