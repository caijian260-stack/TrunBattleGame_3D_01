class_name BattleUnitVisual3D
extends Node3D

## 战斗单位的 3D 表现层。只读取 BattleUnit 的通用数据，不读取任何职业技能字段。

enum VisualStyle {
	HERO,
	CONSTRUCT,
}

const ACCENT_PLAYER := Color(0.2, 0.78, 1.0)
const ACCENT_ENEMY := Color(1.0, 0.32, 0.24)
const HEALTH_HIGH := Color(0.25, 0.9, 0.52)
const HEALTH_MEDIUM := Color(1.0, 0.76, 0.2)
const HEALTH_LOW := Color(1.0, 0.25, 0.2)

var unit: BattleUnit = null
var accent_color := ACCENT_PLAYER
var visual_style: int = VisualStyle.HERO
var is_active := false

var _body_root: Node3D
var _active_ring: MeshInstance3D
var _health_fill: MeshInstance3D
var _health_material: StandardMaterial3D
var _name_label: Label3D
var _elapsed := 0.0
var _health_width := 1.7


func setup(
	p_unit: BattleUnit,
	p_accent_color: Color,
	p_visual_style: int = VisualStyle.HERO
) -> void:
	unit = p_unit
	accent_color = p_accent_color
	visual_style = p_visual_style
	_build_model()
	refresh()


func _process(delta: float) -> void:
	if _body_root == null:
		return

	_elapsed += delta
	var alive := unit != null and unit.hp > 0
	var bob := sin(_elapsed * 2.1) * 0.045 if alive else 0.0
	_body_root.position.y = bob

	if _active_ring != null:
		_active_ring.visible = is_active and alive
		_active_ring.rotate_y(delta * 0.85)


func set_active(active: bool) -> void:
	is_active = active
	if _active_ring != null:
		_active_ring.visible = active and unit != null and unit.hp > 0


func refresh() -> void:
	if unit == null:
		return

	var alive := unit.hp > 0
	_name_label.text = "%s\n%s %d / %d" % [
		unit.unit_name,
		BattleAttribute.label(BattleAttribute.Type.HP),
		unit.hp,
		unit.max_hp,
	]
	_name_label.modulate = Color.WHITE if alive else Color(0.55, 0.58, 0.62)

	var ratio := unit.hp_ratio()
	_health_fill.visible = alive
	_health_fill.scale.x = maxf(ratio, 0.001)
	_health_fill.position.x = -_health_width * (1.0 - ratio) * 0.5
	_health_material.albedo_color = _health_color(ratio)
	_health_material.emission = _health_color(ratio) * 0.55

	_body_root.rotation_degrees.z = 78.0 if not alive else 0.0
	_body_root.rotation_degrees.y = 18.0 if not alive else 0.0


func _build_model() -> void:
	_body_root = Node3D.new()
	_body_root.name = "Body"
	add_child(_body_root)

	_add_ground_shadow()
	_add_active_ring()

	if visual_style == VisualStyle.CONSTRUCT:
		_build_construct_body()
	else:
		_build_hero_body()

	_add_health_bar()
	_add_name_label()


func _add_ground_shadow() -> void:
	var shadow := MeshInstance3D.new()
	shadow.name = "GroundShadow"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.72
	mesh.bottom_radius = 0.72
	mesh.height = 0.025
	shadow.mesh = mesh
	shadow.position.y = 0.012
	shadow.material_override = _material(Color(0.0, 0.0, 0.0, 0.42))
	_body_root.add_child(shadow)


func _add_active_ring() -> void:
	_active_ring = MeshInstance3D.new()
	_active_ring.name = "ActiveRing"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.78
	mesh.outer_radius = 0.88
	_active_ring.mesh = mesh
	_active_ring.position.y = 0.055
	_active_ring.material_override = _material(accent_color, accent_color * 1.8)
	_active_ring.visible = false
	add_child(_active_ring)


func _build_hero_body() -> void:
	var armor := _material(accent_color.darkened(0.2), accent_color * 0.35)
	var cloth := _material(Color(0.12, 0.18, 0.28), Color(0.04, 0.1, 0.18))
	var skin := _material(Color(0.88, 0.7, 0.56))
	var metal := _material(Color(0.82, 0.86, 0.9), Color(0.12, 0.16, 0.2))

	_add_capsule("Torso", 0.34, 1.25, Vector3(0.0, 0.92, 0.0), cloth)
	_add_capsule("ChestGuard", 0.38, 0.82, Vector3(0.0, 1.12, -0.02), armor)
	_add_sphere("Head", 0.25, Vector3(0.0, 1.72, 0.0), skin)
	_add_box("ShoulderLeft", Vector3(0.34, 0.18, 0.38), Vector3(-0.43, 1.34, 0.0), armor)
	_add_box("ShoulderRight", Vector3(0.34, 0.18, 0.38), Vector3(0.43, 1.34, 0.0), armor)
	_add_capsule("ArmLeft", 0.105, 0.86, Vector3(-0.47, 0.92, 0.0), cloth)
	_add_capsule("ArmRight", 0.105, 0.86, Vector3(0.47, 0.92, 0.0), cloth)
	_add_capsule("LegLeft", 0.13, 0.72, Vector3(-0.18, 0.38, 0.0), armor)
	_add_capsule("LegRight", 0.13, 0.72, Vector3(0.18, 0.38, 0.0), armor)

	# 当前示例角色所持武器仅属于表现层，职业层仍决定实际指令与战斗效果。
	var weapon := MeshInstance3D.new()
	weapon.name = "Weapon"
	var blade := BoxMesh.new()
	blade.size = Vector3(0.06, 1.85, 0.12)
	weapon.mesh = blade
	weapon.position = Vector3(0.55, 1.05, -0.08)
	weapon.rotation_degrees = Vector3(0.0, 0.0, -28.0)
	weapon.material_override = metal
	_body_root.add_child(weapon)

	var hilt := MeshInstance3D.new()
	hilt.name = "Hilt"
	var hilt_mesh := BoxMesh.new()
	hilt_mesh.size = Vector3(0.42, 0.07, 0.1)
	hilt.mesh = hilt_mesh
	hilt.position = Vector3(0.82, 0.47, -0.08)
	hilt.rotation_degrees = Vector3(0.0, 0.0, -28.0)
	hilt.material_override = _material(Color(0.92, 0.66, 0.24), Color(0.45, 0.2, 0.03))
	_body_root.add_child(hilt)


func _build_construct_body() -> void:
	var shell := _material(Color(0.36, 0.12, 0.13), accent_color * 0.35)
	var core := _material(accent_color, accent_color * 1.5)
	var dark_metal := _material(Color(0.12, 0.13, 0.16), Color(0.02, 0.02, 0.03))

	_add_box("Torso", Vector3(1.0, 1.25, 0.72), Vector3(0.0, 1.0, 0.0), shell)
	_add_box("Head", Vector3(0.58, 0.48, 0.56), Vector3(0.0, 1.78, 0.0), dark_metal)
	_add_box("ShoulderLeft", Vector3(0.34, 0.5, 0.64), Vector3(-0.64, 1.34, 0.0), dark_metal)
	_add_box("ShoulderRight", Vector3(0.34, 0.5, 0.64), Vector3(0.64, 1.34, 0.0), dark_metal)
	_add_box("ArmLeft", Vector3(0.26, 0.92, 0.3), Vector3(-0.64, 0.78, 0.0), shell)
	_add_box("ArmRight", Vector3(0.26, 0.92, 0.3), Vector3(0.64, 0.78, 0.0), shell)
	_add_box("LegLeft", Vector3(0.34, 0.78, 0.42), Vector3(-0.27, 0.4, 0.0), dark_metal)
	_add_box("LegRight", Vector3(0.34, 0.78, 0.42), Vector3(0.27, 0.4, 0.0), dark_metal)
	_add_sphere("Core", 0.2, Vector3(0.0, 1.05, -0.39), core)


func _add_health_bar() -> void:
	var backdrop := MeshInstance3D.new()
	backdrop.name = "HealthBackdrop"
	var backdrop_mesh := BoxMesh.new()
	backdrop_mesh.size = Vector3(_health_width + 0.08, 0.13, 0.04)
	backdrop.mesh = backdrop_mesh
	backdrop.position = Vector3(0.0, 2.13, 0.0)
	backdrop.material_override = _material(Color(0.03, 0.045, 0.06))
	_body_root.add_child(backdrop)

	_health_fill = MeshInstance3D.new()
	_health_fill.name = "HealthFill"
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(_health_width, 0.095, 0.045)
	_health_fill.mesh = fill_mesh
	_health_fill.position = Vector3(0.0, 2.13, -0.025)
	_health_material = _material(HEALTH_HIGH, HEALTH_HIGH * 0.55)
	_health_fill.material_override = _health_material
	_body_root.add_child(_health_fill)


func _add_name_label() -> void:
	_name_label = Label3D.new()
	_name_label.name = "Name"
	_name_label.position = Vector3(0.0, 2.55, 0.0)
	_name_label.font_size = 34
	_name_label.outline_size = 8
	_name_label.modulate = Color.WHITE
	_name_label.outline_modulate = Color(0.02, 0.035, 0.05, 0.95)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = true
	_body_root.add_child(_name_label)


func _add_box(
	node_name: String,
	size: Vector3,
	local_position: Vector3,
	material: StandardMaterial3D
) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = material
	_body_root.add_child(instance)


func _add_capsule(
	node_name: String,
	radius: float,
	height: float,
	local_position: Vector3,
	material: StandardMaterial3D
) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = material
	_body_root.add_child(instance)


func _add_sphere(
	node_name: String,
	radius: float,
	local_position: Vector3,
	material: StandardMaterial3D
) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = material
	_body_root.add_child(instance)


func _material(
	color: Color,
	emission: Color = Color(0.0, 0.0, 0.0, 0.0)
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	material.metallic = 0.18
	material.emission_enabled = emission.a > 0.0 or emission != Color(0.0, 0.0, 0.0, 0.0)
	material.emission = emission
	material.emission_energy_multiplier = 1.35
	return material


func _health_color(ratio: float) -> Color:
	if ratio > 0.55:
		return HEALTH_HIGH
	if ratio > 0.25:
		return HEALTH_MEDIUM
	return HEALTH_LOW
