class_name RitualScreen
extends Control
## Summoning ritual: tap the 4 cards to invoke, then "Lutar".

signal fight_requested(hero_ids: Array[String])

var cards: Array[HeroCard] = []
var fight_button: Button
var _counter: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()  # the Muse's ritual art, cover-scaled (rune circle centred)
	bg.texture = load("res://assets/final/ritual-fundo.webp")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var dim := ColorRect.new()  # keeps the title and cards readable over the art
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	add_child(box)

	box.add_child(_label("Ritual de Invocação", 44))
	box.add_child(_label("Toque nas 4 cartas para invocar seus heróis", 20))

	var center := CenterContainer.new()
	box.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	center.add_child(grid)
	for id in Defs.HERO_ORDER:
		var card := HeroCard.new(id)
		card.invoked.connect(_on_invoked)
		grid.add_child(card)
		cards.append(card)

	_counter = _label("", 22)
	box.add_child(_counter)

	var fb := CenterContainer.new()
	box.add_child(fb)
	fight_button = Button.new()
	fight_button.text = "Lutar"
	fight_button.custom_minimum_size = Vector2(320, 84)
	fight_button.add_theme_font_size_override("font_size", 34)
	fight_button.focus_mode = Control.FOCUS_NONE
	fight_button.pressed.connect(_on_fight)
	fb.add_child(fight_button)
	_refresh()
	GameLog.event("screen ritual")
	_warm_battle_sprites()


## Cut the battle sprites' backdrops now (one per frame) so the battle starts without a hitch.
func _warm_battle_sprites() -> void:
	for table: Dictionary in [Defs.HEROES, Defs.GOBLINS]:
		for id: String in table:
			if not is_inside_tree():
				return
			SpriteMatte.texture(table[id].sprite)
			await get_tree().process_frame


func invoked_count() -> int:
	return cards.filter(func(c: HeroCard) -> bool: return c.revealed).size()


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _on_invoked(_card: HeroCard) -> void:
	_refresh()


func _refresh() -> void:
	var n := invoked_count()
	_counter.text = "Invocados: %d/%d" % [n, cards.size()]
	fight_button.disabled = n < cards.size()


func _on_fight() -> void:
	if invoked_count() < cards.size():
		return
	var ids: Array[String] = []
	for c in cards:
		ids.append(c.hero_id)
	fight_requested.emit(ids)
