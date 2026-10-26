class_name OrinTriagem
extends HeroBrain
## "Triagem" (support): whenever anyone is wounded, heal the ally with the lowest HP %.
## Keeps away from enemies. Attacks only when nobody needs healing.
## Under FOCAR: keeps healing allies below 30% HP; otherwise joins the focus.

const DANGER := 200.0


func ai(delta: float) -> void:
	var wounded: Array[Unit] = allies().filter(func(u: Unit) -> bool: return u.is_wounded())
	if not wounded.is_empty():
		_heal(pick_min(wounded, func(u: Unit) -> float: return u.hp_ratio()))
	else:
		_attack(nearest(enemies()))
		battle.track("orin_idle_attack_s", delta)


func focus(target: Unit, _delta: float) -> void:
	var critical: Array[Unit] = allies().filter(
			func(u: Unit) -> bool: return u.hp_ratio() < Defs.FOCUS_HEAL_THRESHOLD)
	if not critical.is_empty():
		_heal(pick_min(critical, func(u: Unit) -> float: return u.hp_ratio()))
	else:
		_attack(target)


func _heal(ally: Unit) -> void:
	if not _step_away_from_danger():
		if ally != me and dist(ally) > me.attack_range * 0.8:
			go_to(ally.position)
		else:
			hold()
	me.try_heal(ally)


func _attack(target: Unit) -> void:
	if target == null:
		hold()
		return
	if not _step_away_from_danger():
		keep_range(target, me.attack_range * 0.85)
	me.try_attack(target)


## An enemy inside DANGER always wins over positioning. Returns true if it moved away.
func _step_away_from_danger() -> bool:
	var threat := nearest(enemies())
	if threat != null and dist(threat) < DANGER:
		flee(threat.position)
		return true
	return false
