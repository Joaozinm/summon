class_name YaraPaciencia
extends HeroBrain
## "Paciência" (ranged DPS): hold the ideal distance, focus the most wounded enemy in range,
## and kite (back away while still shooting) when anything gets too close.

const IDEAL := 240.0
const TOO_CLOSE := 140.0


func ai(delta: float) -> void:
	var foes := enemies()
	if foes.is_empty():
		hold()
		return
	var threat := nearest(foes)
	var in_range: Array[Unit] = foes.filter(func(u: Unit) -> bool: return me.in_reach(u))
	var target: Unit
	if in_range.is_empty():
		target = threat
	else:
		target = pick_min(in_range, func(u: Unit) -> float: return u.hp_ratio() + u.hp * 0.0001)
	if dist(threat) < TOO_CLOSE:
		flee(threat.position)  # kite
		battle.track("yara_kite_s", delta)
	else:
		keep_range(target, IDEAL)
	me.try_attack(target)
