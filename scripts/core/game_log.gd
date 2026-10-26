class_name GameLog
## Tagged stdout/console log, used by the headless autotest and browser verification.


static func event(msg: String) -> void:
	print("[summon] %s" % msg)
