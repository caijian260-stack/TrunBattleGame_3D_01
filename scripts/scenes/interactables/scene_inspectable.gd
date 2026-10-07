class_name SceneInspectable
extends SceneInteractable

## 可调查对象。2D 场景中以告示牌 / 石碑形式表现，可显示一段文本，
## 也可以携带 DialogueData 展开对话。

@export var inspection_title: String = "旧物"
@export_multiline var inspection_text: String = "上面留着岁月侵蚀的痕迹。"
@export var display_duration: float = 4.2
@export var marker_color: Color = Color(0.72, 0.57, 0.28)
## 可选：使用一张贴图替代程序化石碑。
@export var board_texture: Texture2D

var dialogue_data: DialogueData = null


func set_dialogue_data(value: DialogueData) -> void:
	dialogue_data = value


func interact(scene_ref: Node) -> void:
	if scene_ref == null:
		return
	if dialogue_data != null and scene_ref.has_method("open_dialogue"):
		scene_ref.open_dialogue(dialogue_data, self)
		return
	if scene_ref.has_method("show_message"):
		scene_ref.show_message(
			"%s\n%s" % [inspection_title, inspection_text],
			display_duration
		)


func get_accent_color() -> Color:
	return marker_color


func _configure_interactable() -> void:
	if display_name == DEFAULT_NAME:
		display_name = inspection_title
	if interaction_prompt == DEFAULT_PROMPT:
		interaction_prompt = "查看"
	hit_size = Vector2(160.0, 200.0)


func _build_visual() -> void:
	if board_texture != null:
		var board := TextureRect.new()
		board.name = "BoardTexture"
		board.texture = board_texture
		board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		board.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		board.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_visual_root.add_child(board)
		return
	_build_placeholder_board()


func _build_placeholder_board() -> void:
	var width := hit_size.x
	var height := hit_size.y
	var center_x := width * 0.5

	var glow := TextureRect.new()
	glow.name = "Glow"
	glow.texture = make_glow_texture(marker_color, Vector2i(144, 144))
	glow.position = Vector2(-18.0, 4.0)
	glow.size = Vector2(width + 36.0, height - 8.0)
	glow.modulate = Color(1.0, 1.0, 1.0, 0.36)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual_root.add_child(glow)

	var post := make_polygon2d(
		"Post",
		PackedVector2Array([
			Vector2(center_x - 9.0, height * 0.52),
			Vector2(center_x + 9.0, height * 0.52),
			Vector2(center_x + 13.0, height * 0.94),
			Vector2(center_x - 13.0, height * 0.94),
		]),
		Color(0.28, 0.21, 0.14)
	)
	_visual_root.add_child(post)

	var base := make_polygon2d(
		"Base",
		make_ellipse_polygon(
			Vector2(center_x, height * 0.94),
			Vector2(30.0, 9.0),
			32
		),
		Color(0.19, 0.15, 0.11)
	)
	_visual_root.add_child(base)

	var board := make_rounded_panel(
		Rect2(center_x - 52.0, height * 0.14, 104.0, height * 0.42),
		Color(0.23, 0.19, 0.15),
		8,
		Color(marker_color.r, marker_color.g, marker_color.b, 0.55),
		2
	)
	board.name = "Board"
	_visual_root.add_child(board)

	var seal := make_polygon2d(
		"Seal",
		make_circle_polygon(
			Vector2(center_x + 30.0, height * 0.46),
			11.0,
			24
		),
		marker_color
	)
	_visual_root.add_child(seal)

	var inscription := Label.new()
	inscription.name = "Inscription"
	inscription.text = "碑"
	inscription.position = Vector2(center_x - 52.0, height * 0.14)
	inscription.size = Vector2(104.0, height * 0.42)
	inscription.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inscription.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inscription.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inscription.add_theme_font_size_override("font_size", 34)
	inscription.add_theme_color_override(
		"font_color",
		Color(marker_color.r, marker_color.g, marker_color.b, 0.9)
	)
	_visual_root.add_child(inscription)
