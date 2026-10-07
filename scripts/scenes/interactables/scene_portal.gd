class_name ScenePortal
extends SceneInteractable

## 场景传送门。2D 场景中用光圈 / 门框表现，只保存目标场景路径与出生点，
## 不拥有目标地图逻辑。

@export_file("*.tscn") var target_scene_path: String = ""
@export var target_spawn_id: StringName = &""
@export var portal_color: Color = Color(0.24, 0.76, 0.9)


func interact(scene_ref: Node) -> void:
	if target_scene_path.is_empty():
		if scene_ref != null and scene_ref.has_method("show_message"):
			scene_ref.show_message("传送门尚未连接。")
		return
	if scene_ref != null and scene_ref.has_method("change_to_scene"):
		scene_ref.change_to_scene(target_scene_path, target_spawn_id)


func get_accent_color() -> Color:
	return portal_color


func _configure_interactable() -> void:
	if interaction_prompt == DEFAULT_PROMPT:
		interaction_prompt = "前往"
	hit_size = Vector2(190.0, 240.0)


func _build_visual() -> void:
	var width := hit_size.x
	var height := hit_size.y
	var center := Vector2(width * 0.5, height * 0.5)

	var glow := TextureRect.new()
	glow.name = "Glow"
	glow.texture = make_glow_texture(portal_color, Vector2i(192, 192))
	glow.position = Vector2(-14.0, -8.0)
	glow.size = Vector2(width + 28.0, height + 16.0)
	glow.modulate = Color(1.0, 1.0, 1.0, 0.55)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual_root.add_child(glow)

	var platform := make_polygon2d(
		"Platform",
		make_ellipse_polygon(
			Vector2(center.x, height * 0.9),
			Vector2(66.0, 16.0),
			40
		),
		Color(0.12, 0.17, 0.22)
	)
	_visual_root.add_child(platform)

	var ring_outer := make_polygon2d(
		"RingOuter",
		make_circle_polygon(center, 68.0, 48),
		portal_color
	)
	_visual_root.add_child(ring_outer)

	var ring_inner := make_polygon2d(
		"RingInner",
		make_circle_polygon(center, 57.0, 48),
		Color(0.02, 0.05, 0.08, 1.0)
	)
	_visual_root.add_child(ring_inner)

	var surface := make_polygon2d(
		"PortalSurface",
		make_circle_polygon(center, 50.0, 48),
		Color(portal_color.r, portal_color.g, portal_color.b, 0.34)
	)
	_visual_root.add_child(surface)

	var core := make_polygon2d(
		"PortalCore",
		make_circle_polygon(center, 26.0, 40),
		Color(
			portal_color.lightened(0.35).r,
			portal_color.lightened(0.35).g,
			portal_color.lightened(0.35).b,
			0.5
		)
	)
	_visual_root.add_child(core)
