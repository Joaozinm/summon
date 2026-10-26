class_name Autotest
extends Node
## End-to-end self-play, enabled with `-- --autotest` (native) or `?autotest` (web).
## Drives the game through real input events (Viewport.push_input), never by calling
## screen methods directly:
##   round 1: invoke 4 cards → Lutar → zoom → FOCAR on a goblin → natural result → Invocar de novo
##   round 2: same, then Battle.debug_defeat() to force the defeat path → Invocar de novo
## Prints "[summon] AUTOTEST PASS" and exits 0, or "AUTOTEST FAIL: …" and exits 1.

const BATTLE_TIMEOUT := 240.0

var main: Node
var _failed := false


static func requested() -> bool:
	if OS.get_cmdline_user_args().has("--autotest") or OS.get_cmdline_args().has("--autotest"):
		return true
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("window.location.search", true)).contains("autotest")
	return false


func _ready() -> void:
	_run()


func _run() -> void:
	GameLog.event("AUTOTEST start")
	await _wait(0.5)
	for round_i in 2:
		var forced_defeat := round_i == 1
		var r: RitualScreen = main.ritual
		if not _check(r != null and r.invoked_count() == 0, "ritual aberto com 0/4"):
			return
		for card in r.cards:
			_click(card.get_global_rect().get_center())
			await _wait(0.8)
		if not _check(r.invoked_count() == 4 and not r.fight_button.disabled,
				"4 cartas invocadas e Lutar habilitado"):
			return
		_click(r.fight_button.get_global_rect().get_center())
		await _wait(0.3)
		var b: Battle = main.battle
		if not _check(b != null and b.alive(0).size() == 4 and b.alive(1).size() == 5,
				"batalha com 4 heróis e 5 goblins"):
			return
		await _wait(1.5)
		var z0 := b.camera.zoom.x
		_wheel(MOUSE_BUTTON_WHEEL_UP)
		await _wait(0.1)
		if not _check(b.camera.zoom.x > z0, "zoom pela roda (%.2f -> %.2f)" % [z0, b.camera.zoom.x]):
			return
		var g: Unit = b.alive(1)[0]
		_click(g.get_global_transform_with_canvas().origin)
		await _wait(0.1)
		if not _check(b.focus_active() and b.focus_target == g, "FOCAR em %s" % g.def.name):
			return
		if forced_defeat:
			b.debug_defeat()
		var t := 0.0
		while main.end_screen == null and t < BATTLE_TIMEOUT:
			await _wait(0.5)
			t += 0.5
		var e: EndScreen = main.end_screen
		if not _check(e != null, "tela final apareceu (%.0fs de batalha)" % b.time):
			return
		GameLog.event("AUTOTEST round %d result=%s stats=%s" % [round_i + 1,
				"vitoria" if e.victory else "derrota", e.stats])
		if forced_defeat and not _check(not e.victory, "derrota forçada mostra Derrota"):
			return
		_click(e.again_button.get_global_rect().get_center())
		await _wait(0.3)
		if not _check(main.ritual != null and main.ritual.invoked_count() == 0
				and main.battle == null, "Invocar de novo volta ao ritual"):
			return
	if not _probe_behaviors():
		return
	GameLog.event("AUTOTEST PASS")
	get_tree().quit(0)


## Deterministic AI probes for behaviors a natural fight may not trigger. Each builds an
## isolated Battle (processing disabled) and ticks it manually.
func _probe_behaviors() -> bool:
	# Yara kites: a Rastejante 80px away → she backs off while shooting.
	var b := _probe_battle()
	var yara := _unit(b, "yara")
	var crawler := _unit(b, "rastejante")
	for g in b.alive(1):
		if g != crawler:
			g.dead = true
	crawler.position = yara.position + Vector2(0, -80)
	var d0 := yara.position.distance_to(crawler.position)
	_tick(b, 0.5)
	var d1 := yara.position.distance_to(crawler.position)
	var shot := crawler.hp < crawler.max_hp or not b.projectiles.is_empty()
	var ok := _check(b.telemetry.get("yara_kite_s", 0.0) > 0.0 and d1 > d0 and shot,
			"Yara recua atirando (dist %.0f -> %.0f, kite %.2fs, Rastejante %d/%d)" % [d0, d1,
			b.telemetry.get("yara_kite_s", 0.0), crawler.hp, crawler.max_hp])
	b.free()
	if not ok:
		return false

	# Orin under FOCAR: an ally below 30% still gets healed.
	b = _probe_battle()
	var brenna := _unit(b, "brenna")
	var orin := _unit(b, "orin")
	b.request_focus(_unit(b, "bruto"))
	brenna.hp = brenna.max_hp * 0.2
	orin.position = brenna.position + Vector2(0, 150)
	_tick(b, 0.3)
	ok = _check(b.focus_active() and b.telemetry.get("orin_heals", 0.0) >= 1.0,
			"Orin cura aliado <30%% durante o FOCAR (Brenna %d/%d)" % [brenna.hp, brenna.max_hp])
	b.free()
	return ok


func _probe_battle() -> Battle:
	var b := Battle.new()
	b.hero_ids = Defs.HERO_ORDER.duplicate()
	b.process_mode = Node.PROCESS_MODE_DISABLED
	b.visible = false
	add_child(b)
	return b


func _unit(b: Battle, id: String) -> Unit:
	for u in b.units:
		if u.id == id:
			return u
	return null


func _tick(b: Battle, seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		b._tick(1.0 / 60.0)


func _check(ok: bool, what: String) -> bool:
	if ok:
		GameLog.event("AUTOTEST ok: " + what)
	else:
		GameLog.event("AUTOTEST FAIL: " + what)
		_failed = true
		get_tree().quit(1)
	return ok


func _click(pos: Vector2) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		get_viewport().push_input(ev, true)


func _wheel(button: MouseButton) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	ev.position = get_viewport().get_visible_rect().get_center()
	get_viewport().push_input(ev, true)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
