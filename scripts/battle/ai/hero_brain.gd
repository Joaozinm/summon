class_name HeroBrain
extends Brain
## Heroes share the FOCAR override: while a focus is active it replaces the personal AI.


func think(delta: float) -> void:
	if battle.focus_active():
		focus(battle.focus_target, delta)
	else:
		ai(delta)


func focus(target: Unit, _delta: float) -> void:
	engage(target)


func ai(_delta: float) -> void:
	pass
