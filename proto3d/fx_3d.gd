class_name Fx3D
## Short-lived 3D feedback (all primitives): rising numbers, particle bursts, heal beam, tombstone.


static func number(parent: Node, at: Vector3, text: String, color: Color, big := false) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64 if big else 48
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = at + Vector3(randf_range(-0.2, 0.2), 0.0, 0.0)
	parent.add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y + 0.9, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.45)
	tw.chain().tween_callback(l.queue_free)


static func burst(parent: Node, at: Vector3, color: Color, amount := 10) -> void:
	var p := CPUParticles3D.new()
	p.position = at
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3(0, -6, 0)
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	var s := SphereMesh.new()
	s.radius = 0.05
	s.height = 0.1
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	s.material = m
	p.mesh = s
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func beam(parent: Node, from: Vector3, to: Vector3, color: Color) -> void:
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.04
	cyl.height = length
	mesh.mesh = cyl
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color, 0.85)
	mesh.material_override = m
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.global_position = (from + to) * 0.5
	var dir := (to - from).normalized()
	var axis := Vector3.UP.cross(dir)
	if axis.length() > 0.0001:
		mesh.global_basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
	var tw := mesh.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(mesh.queue_free)


static func tombstone(parent: Node, at: Vector3) -> void:
	var stone := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.7, 0.16)
	stone.mesh = box
	stone.material_override = SoftToon.make(null, Color("8a8f98"))
	stone.position = at + Vector3(0, -0.4, 0)
	parent.add_child(stone)
	var tw := stone.create_tween()
	tw.tween_property(stone, "position:y", 0.35, 0.5).set_delay(0.4).set_trans(Tween.TRANS_BACK)
