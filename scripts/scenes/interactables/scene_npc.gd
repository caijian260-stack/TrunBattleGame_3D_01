class_name SceneNPC
extends SceneInteractable

## 场景 NPC。2D 场景中没有可操控角色，NPC 以人物立绘 / 剪影形式直接
## 画在背景上，玩家用鼠标点击后由所在 RPGScene 打开对话面板。

@export var npc_name: String = "无名修士"
@export var npc_color: Color = Color(0.24, 0.52, 0.74)
@export var robe_color: Color = Color(0.14, 0.18, 0.27)
@export var skin_color: Color = Color(0.78, 0.61, 0.46)
@export var hair_color: Color = Color(0.05, 0.06, 0.08)
## 可选：直接使用一张人物贴图替代程序化剪影。
@export var portrait_texture: Texture2D

var dialogue_data: DialogueData = null


func set_dialogue_data(value: DialogueData) -> void:
	dialogue_data = value


func get_dialogue_data() -> DialogueData:
	if dialogue_data == null:
		dialogue_data = _build_dialogue()
	return dialogue_data


func interact(scene_ref: Node) -> void:
	if scene_ref == null or not scene_ref.has_method("open_dialogue"):
		return
	scene_ref.open_dialogue(get_dialogue_data(), self)


func get_accent_color() -> Color:
	return npc_color


func _configure_interactable() -> void:
	if display_name == DEFAULT_NAME:
		display_name = npc_name
	if interaction_prompt == DEFAULT_PROMPT:
		interaction_prompt = "交谈"
	hit_size = Vector2(150.0, 220.0)
	if dialogue_data == null:
		dialogue_data = _build_dialogue()


func _build_dialogue() -> DialogueData:
	return DialogueData.single(display_name, "这位道友，初次见面。")


func _build_visual() -> void:
	if portrait_texture != null:
		var portrait := TextureRect.new()
		portrait.name = "Portrait"
		portrait.texture = portrait_texture
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_visual_root.add_child(portrait)
		return
	_build_placeholder_body()


func _build_placeholder_body() -> void:
	var width := hit_size.x
	var height := hit_size.y
	var center_x := width * 0.5

	var glow := TextureRect.new()
	glow.name = "Glow"
	glow.texture = make_glow_texture(npc_color, Vector2i(160, 160))
	glow.position = Vector2(-24.0, -6.0)
	glow.size = Vector2(width + 48.0, height + 24.0)
	glow.modulate = Color(1.0, 1.0, 1.0, 0.5)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual_root.add_child(glow)

	var robe := make_polygon2d(
		"Robe",
		PackedVector2Array([
			Vector2(center_x - 30.0, height * 0.34),
			Vector2(center_x + 30.0, height * 0.34),
			Vector2(center_x + 48.0, height * 0.95),
			Vector2(center_x - 48.0, height * 0.95),
		]),
		robe_color
	)
	_visual_root.add_child(robe)

	var shoulders := make_polygon2d(
		"Shoulders",
		PackedVector2Array([
			Vector2(center_x - 44.0, height * 0.38),
			Vector2(center_x + 44.0, height * 0.38),
			Vector2(center_x + 34.0, height * 0.30),
			Vector2(center_x - 34.0, height * 0.30),
		]),
		Color(npc_color.r, npc_color.g, npc_color.b, 0.9)
	)
	_visual_root.add_child(shoulders)

	var sash := make_polygon2d(
		"Sash",
		PackedVector2Array([
			Vector2(center_x - 32.0, height * 0.60),
			Vector2(center_x + 32.0, height * 0.60),
			Vector2(center_x + 30.0, height * 0.66),
			Vector2(center_x - 30.0, height * 0.66),
		]),
		npc_color
	)
	_visual_root.add_child(sash)

	var neck := make_polygon2d(
		"Neck",
		PackedVector2Array([
			Vector2(center_x - 11.0, height * 0.26),
			Vector2(center_x + 11.0, height * 0.26),
			Vector2(center_x + 11.0, height * 0.34),
			Vector2(center_x - 11.0, height * 0.34),
		]),
		skin_color.darkened(0.08)
	)
	_visual_root.add_child(neck)

	var head := make_polygon2d(
		"Head",
		make_circle_polygon(
			Vector2(center_x, height * 0.19),
			26.0,
			32
		),
		skin_color
	)
	_visual_root.add_child(head)

	var hair := make_polygon2d(
		"Hair",
		PackedVector2Array([
			Vector2(center_x - 27.0, height * 0.19),
			Vector2(center_x - 22.0, height * 0.07),
			Vector2(center_x + 22.0, height * 0.07),
			Vector2(center_x + 27.0, height * 0.19),
			Vector2(center_x + 14.0, height * 0.15),
			Vector2(center_x - 14.0, height * 0.15),
		]),
		hair_color
	)
	_visual_root.add_child(hair)
