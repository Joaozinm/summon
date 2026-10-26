class_name Autotest3D
extends Node
## 3D prototype checks.
## - End-to-end (`--autotest3d` / `?autotest3d`): real input events through the v1 ritual → Lutar →
##   zoom → FOCAR tap on a goblin → natural result → "Invocar de novo"; round 2 forces defeat.
## - Batch (`--proto-batch=N`): N battles per policy (no FOCAR / FOCAR on Fundeiros), prints stats.

const BATTLE_TIMEOUT := 300.0

var main: Node
var batch := 0


static func flag(name: String) -> bool:
	if OS.get_cmdline_user_args().has("--" + name):
		return true
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("window.location.search", true)).contains(name)
	return false


static func batch_count() -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--proto-batch="):
			return int(a.trim_prefix("--proto-batch="))
	return 0


func _ready() -> void:
	if batch > 0:
		_run_batch()
	else:
		_run_e2e()


# --- end to end ------------------------------------------------------------------------------

func _run_e2e() -> void:
	GameLog.event("AUTOTEST3D start")
	await _wait(0.6)
	for round_i in 2:
		var forced := round_i == 1
		var r: RitualScreen = main.ritual
		if not _check(r != null and r.invoked_count() == 0, "ritual aberto"):
			return
		for card in r.cards:
			_click(card.get_global_rect().get_center())
			await _wait(0.8)
		if not _check(r.invoked_count() == 4, "4 cartas invocadas"):
			return
		_click(r.fight_button.get_global_rect().get_center())
		await _wait(0.5)
		var b: Battle3D = main.battle
		if not _check(b != null and b.alive(0).size() == 4 and b.alive(1).size() == 5, "batalha 3D com 4 heróis e 5 goblins"):
			return
		await _wait(2.0)
		var d0 := b.camera.distance
		_wheel(MOUSE_BUTTON_WHEEL_UP)
		await _wait(0.1)
		if not _check(b.camera.distance < d0, "zoom por distância (%.1f -> %.1f m)" % [d0, b.camera.distance]):
			return
		_wheel(MOUSE_BUTTON_WHEEL_DOWN)
		var g: Unit3D = null
		for u in b.alive(1):
			if u.id == "fundeiro":
				g = u
		if g == null:
			g = b.alive(1)[0]
		_click(b.camera.cam.unproject_position(g.chest()))
		await _wait(0.1)
		if not _check(b.focus_active() and b.focus_target == g, "FOCAR por toque em %s" % g.def.name):
			return
		if not forced:
			await _shots(b)
		if forced:
			b.debug_defeat()
		var t := 0.0
		while main.end_screen == null and t < BATTLE_TIMEOUT:
			await _wait(0.5)
			t += 0.5
		var e: EndScreen = main.end_screen
		if not _check(e != null, "tela final (%.0fs de batalha)" % b.time):
			return
		GameLog.event("AUTOTEST3D round %d result=%s stats=%s" % [round_i + 1, "vitoria" if e.victory else "derrota", e.stats])
		_click(e.again_button.get_global_rect().get_center())
		await _wait(0.4)
		if not _check(main.ritual != null and main.battle == null, "Invocar de novo volta ao ritual"):
			return
	GameLog.event("AUTOTEST3D PASS")
	get_tree().quit(0)


## `--shots=<dir>` (windowed runs only): battle screenshots at default zoom, close zoom and far zoom.
func _shots(b: Battle3D) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.trim_prefix("--shots=")
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	var tag := RenderingServer.get_current_rendering_method()
	for step: Array in [["a_default", 1.0, 1.2], ["b_close", 0.62, 1.5], ["c_far", 1.6, 1.5], ["d_mid", 1.0, 4.0]]:
		b.camera.distance = CameraBG3.DIST_DEFAULT * float(step[1])
		await _wait(float(step[2]))
		await RenderingServer.frame_post_draw
		var path := "%s/%s_%s.png" % [dir, tag, step[0]]
		get_viewport().get_texture().get_image().save_png(path)
		GameLog.event("SHOT %s (distance %.1f m)" % [path, b.camera.distance])
	b.camera.distance = CameraBG3.DIST_DEFAULT


func _check(ok: bool, what: String) -> bool:
	GameLog.event(("AUTOTEST3D ok: " if ok else "AUTOTEST3D FAIL: ") + what)
	if not ok:
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


# --- batch -------------------------------------------------------------------------------------

func _run_batch() -> void:
	for policy in ["sem_foco", "foco_fundeiro"]:
		var rows: Array[Dictionary] = []
		for i in batch:
			seed(2000 + i)
			var b := Battle3D.new()
			b.hero_ids = Defs.HERO_ORDER.duplicate()
			main.add_child(b)
			while not b.decided() and b.time < BATTLE_TIMEOUT:
				if policy == "foco_fundeiro" and b.focus_ready():
					var pick: Unit3D = null
					for g in b.alive(1):
						if pick == null or (g.id == "fundeiro" and pick.id != "fundeiro"):
							pick = g
					b.request_focus(pick)
				await get_tree().physics_frame
			var s := b.stats()
			s.victory = b.victory and b.decided()
			s.timeout = not b.decided()
			rows.append(s)
			GameLog.event("BATCH3D %s #%d %s %.1fs heroes_alive=%d dead=[%s]" % [policy, i + 1,
					"W" if s.victory else ("T" if s.timeout else "L"), s.time, s.heroes_alive, s.dead])
			b.free()
		var n := rows.size()
		var wins := rows.filter(func(r: Dictionary) -> bool: return r.victory).size()
		var tsum := 0.0
		var dsum := 0.0
		for r in rows:
			tsum += float(r.time)
			dsum += float(r.heroes_total) - float(r.heroes_alive)
		GameLog.event("BATCH3D SUMMARY %s n=%d avg_time=%.1fs wins=%d/%d avg_deaths=%.2f" % [policy, n, tsum / n, wins, n, dsum / n])
	get_tree().quit(0)
