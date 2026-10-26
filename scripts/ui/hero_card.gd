class_name HeroCard
extends Control
## Ritual card with a standardized frame drawn in code. Face-down until tapped; tapping
## "invokes" the hero (flip + bell). The revealed face shows the Muse's portrait of the hero.

signal invoked(card: HeroCard)

const SIZE := Vector2(300, 420)
const FRAME := Color("8f969f")  # Comum
const FRAME_DARK := Color("4b5058")
const BG := Color("1a1c22")

var hero_id: String
var def: Dictionary
var revealed := false
var _portrait: Texture2D
var _flipping := false
var _flash := 0.0


func _init(id: String) -> void:
	hero_id = id
	def = Defs.HEROES[id]
	_portrait = load(def.portrait)
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	pivot_offset = SIZE / 2.0


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		invoke()
		accept_event()


func invoke() -> void:
	if revealed or _flipping:
		return
	_flipping = true
	Sfx.play(&"sino")
	var tw := create_tween()
	tw.tween_property(self, "scale:x", 0.0, 0.14).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		revealed = true
		_flash = 1.0
		queue_redraw())
	tw.tween_property(self, "scale:x", 1.0, 0.16).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_flash", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		_flipping = false
		GameLog.event("invoked %s" % hero_id)
		invoked.emit(self))


func _process(_delta: float) -> void:
	if _flash > 0.0:
		queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var r := Rect2(Vector2.ZERO, SIZE)
	var frame := StyleBoxFlat.new()
	frame.bg_color = BG
	frame.border_color = FRAME
	frame.set_border_width_all(6)
	frame.set_corner_radius_all(14)
	draw_style_box(frame, r)
	draw_rect(r.grow(-12), FRAME_DARK, false, 2.0)

	if revealed:
		var portrait := Rect2(24, 24, SIZE.x - 48, 236)
		draw_texture_rect_region(_portrait, portrait, _cover_region(portrait.size))
		draw_rect(portrait, def.accent, false, 4.0)
		draw_string(font, Vector2(0, 300), def.name, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 30)
		draw_string(font, Vector2(0, 332), def.role, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 19,
				Color(1, 1, 1, 0.75))
		var banner := Rect2(SIZE.x / 2 - 60, 354, 120, 32)
		var b := StyleBoxFlat.new()
		b.bg_color = FRAME_DARK
		b.border_color = FRAME
		b.set_border_width_all(2)
		b.set_corner_radius_all(8)
		draw_style_box(b, banner)
		draw_string(font, Vector2(banner.position.x, banner.position.y + 23), def.rarity,
				HORIZONTAL_ALIGNMENT_CENTER, banner.size.x, 17)
	else:
		var c := SIZE / 2.0 - Vector2(0, 20)
		for k in 3:
			var s := 60.0 + k * 34.0
			var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.75, 0),
					c + Vector2(0, s), c + Vector2(-s * 0.75, 0), c + Vector2(0, -s)])
			draw_polyline(pts, Color(FRAME, 0.5 - k * 0.12), 2.0)
		draw_string(font, Vector2(0, c.y + 22), "?", HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 64,
				Color(FRAME, 0.9))
		draw_string(font, Vector2(0, SIZE.y - 40), "Toque para invocar",
				HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 19, Color(1, 1, 1, 0.7))

	if _flash > 0.0:
		draw_rect(r, Color(1, 1, 1, _flash * 0.8))


## Source region of the portrait that covers `target` without distortion, kept near the top so
## the face stays in frame (portraits are 1:1, Kess's is 1:2).
func _cover_region(target: Vector2) -> Rect2:
	var ts := _portrait.get_size()
	var want := target.x / target.y
	var w := ts.x
	var h := w / want
	if h > ts.y:
		h = ts.y
		w = h * want
	var top := clampf(ts.y * 0.06, 0.0, ts.y - h) if ts.y > ts.x * 1.2 else (ts.y - h) * 0.2
	return Rect2((ts.x - w) * 0.5, top, w, h)
