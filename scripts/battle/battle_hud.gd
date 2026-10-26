class_name BattleHud
extends CanvasLayer
## Battle UI (pt-BR): hero HP rows, goblin count, FOCAR button with duration/cooldown bar.
## Default-theme widgets only.

var battle: Battle
var focus_button: Button
var _focus_bar: ProgressBar
var _hint: Label
var _goblins: Label
var _bars: HeroBars


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 12
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	_bars = HeroBars.new()
	_bars.battle = battle
	top.add_child(_bars)
	_goblins = _label(20)
	top.add_child(_goblins)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -28
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)
	_hint = _label(18)
	bottom.add_child(_hint)
	focus_button = Button.new()
	focus_button.custom_minimum_size = Vector2(320, 84)
	focus_button.add_theme_font_size_override("font_size", 30)
	focus_button.focus_mode = Control.FOCUS_NONE
	focus_button.pressed.connect(func() -> void: battle.arm_focus())
	bottom.add_child(focus_button)
	_focus_bar = ProgressBar.new()
	_focus_bar.custom_minimum_size = Vector2(320, 14)
	_focus_bar.show_percentage = false
	bottom.add_child(_focus_bar)
	_refresh()


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	_goblins.text = "Goblins restantes: %d/%d" % [battle.alive(Unit.TEAM_GOBLINS).size(),
			Defs.GOBLIN_ORDER.size()]
	if battle.focus_active():
		focus_button.text = "FOCANDO… %ds" % ceili(battle.focus_left)
		focus_button.disabled = true
		_focus_bar.value = battle.focus_left / Defs.FOCUS_DURATION * 100.0
		_hint.text = "Heróis atacando o alvo marcado"
	elif battle.focus_cd > 0.0:
		focus_button.text = "FOCAR (%ds)" % ceili(battle.focus_cd)
		focus_button.disabled = true
		_focus_bar.value = (1.0 - battle.focus_cd / Defs.FOCUS_COOLDOWN) * 100.0
		_hint.text = "FOCAR recarregando"
	elif battle.focus_armed:
		focus_button.text = "Escolha um goblin"
		focus_button.disabled = false
		_focus_bar.value = 100.0
		_hint.text = "Toque num goblin para marcar o alvo (toque no botão para cancelar)"
	else:
		focus_button.text = "FOCAR"
		focus_button.disabled = false
		_focus_bar.value = 100.0
		_hint.text = "Toque num goblin para FOCAR · role o mouse para zoom"


## Compact HP rows for the summoned heroes.
class HeroBars extends Control:
	const ROW := 26.0
	var battle: Battle

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, ROW * battle.hero_ids.size())

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var font := get_theme_default_font()
		var i := 0
		for u in battle.units:
			if not u.is_hero():
				continue
			var y := i * ROW
			i += 1
			var a := 0.4 if u.dead else 1.0
			# PLACEHOLDER TEMPORÁRIO — color swatch stands in for the Muse's hero icon.
			draw_rect(Rect2(0, y + 4, 18, 18), Color(u.def.color, a))
			draw_string(font, Vector2(26, y + 19), u.def.name, HORIZONTAL_ALIGNMENT_LEFT, 90, 17,
					Color(1, 1, 1, a))
			var bar := Rect2(120, y + 7, size.x - 220, 12)
			draw_rect(bar, Color(0, 0, 0, 0.7))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * u.hp_ratio(), bar.size.y)),
					Color("4fd06a"))
			var txt := "caído" if u.dead else "%d/%d" % [ceili(u.hp), roundi(u.max_hp)]
			draw_string(font, Vector2(size.x - 92, y + 19), txt, HORIZONTAL_ALIGNMENT_RIGHT, 92,
					16, Color(1, 1, 1, a))
