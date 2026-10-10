class_name CloudTerraceScene
extends RPGScene

## 具体场景示例：云台。与剑宗山门同为固定视角 2D 背景场景，
## 用于验证场景父类下的多地图切换与互动物复用。

const SceneNPCScript := preload("res://scripts/scenes/interactables/scene_npc.gd")
const ScenePortalScript := preload("res://scripts/scenes/interactables/scene_portal.gd")
const SceneInspectableScript := preload(
	"res://scripts/scenes/interactables/scene_inspectable.gd"
)
const JIANZONG_SCENE_PATH := "res://scenes/main.tscn"


func _configure_scene() -> void:
	scene_id = &"cloud_terrace"
	scene_display_name = "云台"
	source_scene_path = "res://scenes/cloud_terrace.tscn"
	background_top_color = Color(0.26, 0.42, 0.56)
	background_bottom_color = Color(0.09, 0.16, 0.24)
	battle_scene_path = DEFAULT_BATTLE_SCENE
	register_spawn_point(&"start", Vector2(0.0, 0.0), 0.0)
	register_spawn_point(&"cloud_arrival", Vector2(0.0, 0.0), 0.0)
	dialogue_action_requested.connect(_on_dialogue_action_requested)


func _draw_scene_background() -> void:
	# 云海分层
	draw_relative_circle(
		Vector2(0.24, 0.30),
		0.24,
		Color(0.86, 0.93, 0.97, 0.30)
	)
	draw_relative_circle(
		Vector2(0.72, 0.22),
		0.20,
		Color(0.80, 0.90, 0.96, 0.26)
	)
	draw_relative_circle(
		Vector2(0.50, 0.40),
		0.30,
		Color(0.78, 0.88, 0.95, 0.18)
	)
	draw_relative_circle(
		Vector2(0.10, 0.46),
		0.18,
		Color(0.86, 0.93, 0.97, 0.16)
	)
	draw_relative_circle(
		Vector2(0.90, 0.44),
		0.19,
		Color(0.86, 0.93, 0.97, 0.16)
	)

	# 石台与围栏
	draw_relative_ellipse(
		Vector2(0.5, 0.80),
		Vector2(0.44, 0.22),
		Color(0.36, 0.40, 0.43)
	)
	draw_relative_ellipse(
		Vector2(0.5, 0.795),
		Vector2(0.37, 0.175),
		Color(0.47, 0.51, 0.53)
	)
	draw_relative_ellipse(
		Vector2(0.5, 0.795),
		Vector2(0.19, 0.085),
		Color(0.24, 0.30, 0.34)
	)

	for index in range(16):
		var angle := PI + float(index) * PI / 15.0
		var point := Vector2(
			0.5 + cos(angle) * 0.40,
			0.80 + sin(angle) * 0.20
		)
		draw_relative_circle(point, 0.008, Color(0.60, 0.64, 0.66))

	# 云台石灯
	for x in [0.30, 0.70]:
		draw_relative_rect(Rect2(x - 0.006, 0.60, 0.012, 0.05), Color(0.22, 0.26, 0.29))
		draw_relative_circle(Vector2(x, 0.585), 0.017, Color(0.24, 0.72, 0.82))
		draw_relative_circle(Vector2(x, 0.585), 0.045, Color(0.24, 0.72, 0.82, 0.18))

	# 远处山影
	draw_relative_polygon(
		PackedVector2Array([
			Vector2(0.0, 0.30),
			Vector2(0.16, 0.14),
			Vector2(0.32, 0.30),
			Vector2(0.32, 0.36),
			Vector2(0.0, 0.36),
		]),
		Color(0.18, 0.28, 0.33, 0.65)
	)
	draw_relative_polygon(
		PackedVector2Array([
			Vector2(0.72, 0.32),
			Vector2(0.86, 0.16),
			Vector2(1.0, 0.30),
			Vector2(1.0, 0.36),
			Vector2(0.72, 0.36),
		]),
		Color(0.18, 0.28, 0.33, 0.65)
	)


func _build_concrete_scene() -> void:
	add_scene_texture(
		"CloudScrollTexture",
		_make_cloud_scroll_texture(),
		Rect2(0.365, 0.16, 0.27, 0.22)
	)
	place_scene_control(
		_make_scroll_frame(),
		Rect2(0.352, 0.148, 0.296, 0.244)
	)

	place_scene_node(
		"AncientPine",
		_make_pine(),
		Vector2(0.20, 0.74)
	)

	var attendant := SceneNPCScript.new()
	attendant.name = "CloudAttendantNPC"
	attendant.npc_name = "白鹤童子·清越"
	attendant.display_name = attendant.npc_name
	attendant.anchor_position = Vector2(0.60, 0.60)
	attendant.npc_color = Color(0.65, 0.86, 0.94)
	attendant.robe_color = Color(0.66, 0.72, 0.74)
	attendant.set_dialogue_data(_build_attendant_dialogue())
	add_child(attendant)

	var cloud_tablet := SceneInspectableScript.new()
	cloud_tablet.name = "CloudTablet"
	cloud_tablet.inspection_title = "云海剑铭"
	cloud_tablet.display_name = cloud_tablet.inspection_title
	cloud_tablet.inspection_text = (
		"云层在山下缓慢翻涌。\n"
		+ "石上剑痕深浅不一，似乎在记录不同弟子领悟剑势的瞬间。"
	)
	cloud_tablet.marker_color = Color(0.34, 0.78, 0.86)
	cloud_tablet.anchor_position = Vector2(0.36, 0.62)
	add_child(cloud_tablet)

	var return_portal := ScenePortalScript.new()
	return_portal.name = "JianzongReturnPortal"
	return_portal.display_name = "返回山门"
	return_portal.interaction_prompt = "返回"
	return_portal.target_scene_path = JIANZONG_SCENE_PATH
	return_portal.target_spawn_id = &"cloud_return"
	return_portal.portal_color = Color(0.76, 0.68, 0.36)
	return_portal.anchor_position = Vector2(0.80, 0.58)
	return_portal.hit_size = Vector2(180.0, 230.0)
	add_child(return_portal)


func _build_attendant_dialogue() -> DialogueData:
	var data := DialogueData.new("白鹤童子·清越")
	data.add_line(
		&"start",
		"云台风大，站稳些。师兄说，人在心乱的时候最容易被自己的剑气惊到。",
		&"main"
	)
	data.add_choice_node(
		&"main",
		"清越把一柄短木剑抱在怀里，眼神却很认真。",
		[
			DialogueData.choice("我想练一场", &"training_confirm"),
			DialogueData.choice("这里为什么叫云台", &"lore"),
			DialogueData.choice("先回去了", &"", &"travel_jianzong"),
		]
	)
	data.add_choice_node(
		&"training_confirm",
		"阵纹已经准备好了。若你应付得来，我会替你记下这一场。",
		[
			DialogueData.choice(
				"开始切磋",
				&"",
				&"start_training_battle",
				{"source": "cloud_attendant"}
			),
			DialogueData.choice("我再看看云", &"main"),
		]
	)
	data.add_line(
		&"lore",
		"这里原本只是山腰的一块石台。后来剑宗祖师在此观云七日，刻下第一式剑意，才有了云台之名。",
		&"lore_end"
	)
	data.add_choice_node(
		&"lore_end",
		"远处的云海不断变化，仿佛每一道剑势都能在其中找到回声。",
		[
			DialogueData.choice("受教了", &"main"),
			DialogueData.choice("去演武场", &"training_confirm"),
		]
	)
	return data


func _on_dialogue_action_requested(
	_scene: RPGScene,
	_source: SceneInteractable,
	action_id: StringName,
	payload: Variant
) -> void:
	match action_id:
		&"start_training_battle":
			var encounter_data: Dictionary = {}
			if payload is Dictionary:
				encounter_data = payload
			enter_battle(encounter_data)
		&"travel_jianzong":
			change_to_scene(JIANZONG_SCENE_PATH, &"cloud_return")
		&"scene_message":
			show_message(str(payload))


func _make_cloud_scroll_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.025, 0.1, 0.16),
		Color(0.2, 0.58, 0.72),
		Color(0.7, 0.88, 0.94),
		Color(0.12, 0.24, 0.32),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 0.7, 1.0])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 160
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(1.0, 1.0)
	return texture


func _make_scroll_frame() -> Panel:
	var frame := Panel.new()
	frame.name = "CloudScrollFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.78, 0.86, 0.9, 0.85)
	style.set_border_width_all(5)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 6
	frame.add_theme_stylebox_override("panel", style)
	return frame


func _make_pine() -> Node2D:
	var root := Node2D.new()
	root.name = "AncientPineModel"

	var trunk := ColorRect.new()
	trunk.color = Color(0.25, 0.13, 0.07)
	trunk.position = Vector2(-6.0, -30.0)
	trunk.size = Vector2(12.0, 30.0)
	trunk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(trunk)

	var foliage := Color(0.08, 0.26, 0.19)
	for index in range(4):
		var crown := Polygon2D.new()
		crown.polygon = PackedVector2Array([
			Vector2(0.0, -108.0 + float(index) * 24.0),
			Vector2(-56.0 + float(index) * 9.0, -46.0 + float(index) * 16.0),
			Vector2(56.0 - float(index) * 9.0, -46.0 + float(index) * 16.0),
		])
		crown.color = foliage.lightened(float(index) * 0.05)
		crown.antialiased = true
		root.add_child(crown)

	return root
