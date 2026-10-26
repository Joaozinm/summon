class_name GoblinBrains
## Goblin AIs. Kept together because each is a few lines.


## Rastejante: chase the nearest hero and bite.
class Rastejante extends Brain:
	func think(_delta: float) -> void:
		engage(nearest(enemies()))


## Fundeiro: keep its distance and sling at the nearest hero.
class Fundeiro extends Brain:
	const IDEAL := 200.0

	func think(_delta: float) -> void:
		var target := nearest(enemies())
		if target == null:
			hold()
			return
		keep_range(target, IDEAL, 50.0)
		me.try_attack(target)


## Bruto: lock onto the hero with the most HP (re-evaluated each second).
class Bruto extends Brain:
	var _target: Unit
	var _retarget := 0.0

	func think(delta: float) -> void:
		_retarget -= delta
		if _target == null or _target.dead or _retarget <= 0.0:
			_retarget = 1.0
			_target = pick_min(enemies(), func(u: Unit) -> float: return -u.hp)
		engage(_target)
