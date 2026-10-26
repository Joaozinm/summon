class_name Fx
## Stateless helpers that spawn short-lived feedback nodes (all drawn from Godot primitives).


static func damage_number(parent: Node, pos: Vector2, text: String, color: Color,
		big := false) -> void:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = 30 if big else 22
	ls.font_color = color
	ls.outline_size = 5
	ls.outline_color = Color(0, 0, 0, 0.9)
	l.label_settings = ls
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(80, 36)
	l.position = pos + Vector2(-40 + randf_range(-10, 10), -60)
	l.z_index = 50
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 42, 0.8) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.45)
	tw.chain().tween_callback(l.queue_free)


static func burst(parent: Node, pos: Vector2, color: Color, amount := 10, speed := 140.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 40
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0, 220)
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	p.color = color
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func beam(parent: Node, from: Vector2, to: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = 4.0
	line.default_color = color
	line.z_index = 30
	parent.add_child(line)
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.3)
	tw.tween_callback(line.queue_free)


static func tombstone(parent: Node, pos: Vector2) -> void:
	var t := Tombstone.new()
	t.position = pos
	t.modulate.a = 0.0
	parent.add_child(t)
	var tw := t.create_tween()
	tw.tween_property(t, "modulate:a", 1.0, 0.35).set_delay(0.35)
	tw.tween_property(t, "modulate:a", 0.55, 2.0).set_delay(0.8)
