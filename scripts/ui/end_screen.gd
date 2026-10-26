class_name EndScreen
extends Control
## Result overlay on top of the frozen arena. "Invocar de novo" restarts the ritual
## (no permanent loss: every run starts from the same full roster).

signal again_requested

var victory: bool
var stats: Dictionary
var again_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	add_child(box)

	var title := _label("Vitória!" if victory else "Derrota", 72)
	title.add_theme_color_override("font_color", Color("f2d36b") if victory else Color("e0564a"))
	box.add_child(title)
	box.add_child(_label("Os goblins foram derrotados." if victory else "Seus heróis caíram.", 24))
	box.add_child(_label("Tempo: %ds  ·  Heróis de pé: %d/%d  ·  Goblins abatidos: %d/%d" % [
			roundi(stats.time), stats.heroes_alive, stats.heroes_total,
			stats.goblins_killed, Defs.GOBLIN_ORDER.size()], 18))

	var c := CenterContainer.new()
	box.add_child(c)
	again_button = Button.new()
	again_button.text = "Invocar de novo"
	again_button.custom_minimum_size = Vector2(360, 84)
	again_button.add_theme_font_size_override("font_size", 30)
	again_button.focus_mode = Control.FOCUS_NONE
	again_button.pressed.connect(func() -> void: again_requested.emit())
	c.add_child(again_button)
	GameLog.event("screen end victory=%s" % victory)


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
