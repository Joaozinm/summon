extends Node
## Game flow: ritual → battle → result → ritual again.

var ritual: RitualScreen
var battle: Battle
var end_screen: EndScreen
var _ui: CanvasLayer


func _ready() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	show_ritual()
	if Autotest.requested():
		var t := Autotest.new()
		t.main = self
		add_child(t)


func show_ritual() -> void:
	_clear()
	ritual = RitualScreen.new()
	ritual.fight_requested.connect(start_battle)
	_ui.add_child(ritual)


func start_battle(hero_ids: Array[String]) -> void:
	_clear()
	battle = Battle.new()
	battle.hero_ids = hero_ids
	battle.finished.connect(_on_battle_finished)
	add_child(battle)


func _on_battle_finished(victory: bool, stats: Dictionary) -> void:
	end_screen = EndScreen.new()
	end_screen.victory = victory
	end_screen.stats = stats
	end_screen.again_requested.connect(show_ritual)
	_ui.add_child(end_screen)


func _clear() -> void:
	for n: Node in [ritual, battle, end_screen]:
		if is_instance_valid(n):
			n.queue_free()
	ritual = null
	battle = null
	end_screen = null
