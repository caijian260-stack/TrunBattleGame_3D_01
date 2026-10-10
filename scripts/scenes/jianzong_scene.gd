class_name JianzongScene
extends RPGScene

## 具体场景示例：剑宗山门大殿。
##
## 固定第一视角的 2D 背景画面：玩家不能移动，只能点击执事 NPC、剑宗旧碑
## 与登云台传送门进行互动。场景只负责布局、氛围与剧情动作绑定。

const SceneNPCScript := preload("res://scripts/scenes/interactables/scene_npc.gd")
const ScenePortalScript := preload("res://scripts/scenes/interactables/scene_portal.gd")
const SceneInspectableScript := preload(
	"res://scripts/scenes/interactables/scene_inspectable.gd"
)
const CLOUD_TERRACE_SCENE_PATH := "res://scenes/cloud_terrace.tscn"
const MYSTIC_REALM_SCENE_PATH := "res://scenes/mystic_realm.tscn"


func _configure_scene() -> void:
	scene_id = &"jianzong_gate"
	scene_display_name = "剑宗山门"
	source_scene_path = "res://scenes/main.tscn"
	background_top_color = Color(0.10, 0.12, 0.16)
	background_bottom_color = Color(0.03, 0.04, 0.06)
	battle_scene_path = DEFAULT_BATTLE_SCENE
	register_spawn_point(&"start", Vector2(0.0, 0.0), 0.0)
	register_spawn_point(&"cloud_return", Vector2(0.0, 0.0), 0.0)
	register_spawn_point(&"mystic_return", Vector2(0.0, 0.0), 0.0)
	dialogue_action_requested.connect(_on_dialogue_action_requested)


func _draw_scene_background() -> void:
	# 后墙与地面
	draw_relative_rect(Rect2(0.0, 0.0, 1.0, 0.70), Color(0.075, 0.09, 0.115))
	draw_relative_rect(Rect2(0.0, 0.70, 1.0, 0.30), Color(0.16, 0.175, 0.19))
	draw_relative_rect(Rect2(0.0, 0.685, 1.0, 0.02), Color(0.05, 0.06, 0.075))

	# 中央石道
	draw_relative_polygon(
		PackedVector2Array([
			Vector2(0.40, 0.70),
			Vector2(0.60, 0.70),
			Vector2(0.78, 1.0),
			Vector2(0.22, 1.0),
		]),
		Color(0.235, 0.25, 0.27)
	)
	for index in range(7):
		var tile_y := 0.72 + float(index) * 0.045
		var inset := 0.40 - float(index) * 0.026
		draw_relative_line(
			Vector2(inset, tile_y),
			Vector2(1.0 - inset, tile_y),
			Color(0.15, 0.165, 0.18),
			2.0
		)

	# 立柱
	for x in [0.075, 0.925]:
		draw_relative_rect(
			Rect2(x - 0.028, 0.06, 0.056, 0.62),
			Color(0.125, 0.14, 0.16)
		)
		draw_relative_rect(
			Rect2(x - 0.038, 0.05, 0.076, 0.03),
			Color(0.30, 0.32, 0.34)
		)
		draw_relative_rect(
			Rect2(x - 0.038, 0.655, 0.076, 0.028),
			Color(0.78, 0.58, 0.24)
		)

	# 横梁
	draw_relative_rect(Rect2(0.0, 0.045, 1.0, 0.028), Color(0.19, 0.12, 0.075))
	draw_relative_rect(Rect2(0.0, 0.088, 1.0, 0.016), Color(0.25, 0.16, 0.09))

	# 殿内暖光
	draw_relative_circle(Vector2(0.5, 0.34), 0.34, Color(0.98, 0.72, 0.38, 0.10))
	draw_relative_circle(Vector2(0.5, 0.30), 0.18, Color(0.98, 0.78, 0.46, 0.12))


func _build_concrete_scene() -> void:
	var banner_texture := _make_scene_banner_texture()
	add_scene_texture(
		"LeftSwordBanner",
		banner_texture,
		Rect2(0.145, 0.13, 0.075, 0.40)
	)
	add_scene_texture(
		"RightSwordBanner",
		banner_texture,
		Rect2(0.78, 0.13, 0.075, 0.40)
	)

	place_scene_node(
		"SwordRack",
		_make_sword_rack(),
		Vector2(0.235, 0.70)
	)
	place_scene_node(
		"SwordRack",
		_make_sword_rack(),
		Vector2(0.775, 0.70)
	)

	var steward := SceneNPCScript.new()
	steward.name = "StewardNPC"
	steward.npc_name = "守阁执事·沈砚"
	steward.display_name = steward.npc_name
	steward.anchor_position = Vector2(0.40, 0.58)
	steward.npc_color = Color(0.22, 0.58, 0.82)
	steward.robe_color = Color(0.11, 0.17, 0.25)
	steward.set_dialogue_data(_build_steward_dialogue())
	add_child(steward)

	var tablet := SceneInspectableScript.new()
	tablet.name = "SwordSchoolTablet"
	tablet.inspection_title = "剑宗旧碑"
	tablet.display_name = tablet.inspection_title
	tablet.inspection_text = (
		"碑上刻着一句话：剑有锋，心不可有锋。\n"
		+ "碑侧留有掌门亲传弟子才可阅的剑印。"
	)
	tablet.marker_color = Color(0.78, 0.55, 0.2)
	tablet.anchor_position = Vector2(0.615, 0.60)
	add_child(tablet)

	var mystic_portal := ScenePortalScript.new()
	mystic_portal.name = "MysticRealmPortal"
	mystic_portal.display_name = "秘境入口·古阵"
	mystic_portal.interaction_prompt = "进入"
	mystic_portal.target_scene_path = MYSTIC_REALM_SCENE_PATH
	mystic_portal.target_spawn_id = &"mystic_arrival"
	mystic_portal.portal_color = Color(0.58, 0.42, 0.92)
	mystic_portal.anchor_position = Vector2(0.18, 0.58)
	mystic_portal.hit_size = Vector2(180.0, 230.0)
	add_child(mystic_portal)

	var cloud_portal := ScenePortalScript.new()
	cloud_portal.name = "CloudTerracePortal"
	cloud_portal.display_name = "登云台"
	cloud_portal.interaction_prompt = "前往"
	cloud_portal.target_scene_path = CLOUD_TERRACE_SCENE_PATH
	cloud_portal.target_spawn_id = &"cloud_arrival"
	cloud_portal.portal_color = Color(0.22, 0.8, 0.92)
	cloud_portal.anchor_position = Vector2(0.80, 0.55)
	cloud_portal.hit_size = Vector2(180.0, 230.0)
	add_child(cloud_portal)


func _build_steward_dialogue() -> DialogueData:
	var data := DialogueData.new("守阁执事·沈砚")
	data.add_line(
		&"start",
		"你来得正好。演武场上的阵纹已经重新亮起，随时可以试探你的剑路。",
		&"main"
	)
	data.add_choice_node(
		&"main",
		"大殿内的风很静，只有远处木剑相击的声音。",
		[
			DialogueData.choice("我想去演武场", &"training_confirm"),
			DialogueData.choice("和我讲讲剑宗", &"history"),
			DialogueData.choice("告辞", &""),
		]
	)
	data.add_choice_node(
		&"training_confirm",
		"阵纹会召来一只训练假人。它不会留情，但也不会真正伤你。",
		[
			DialogueData.choice(
				"开始演武",
				&"",
				&"start_training_battle",
				{"source": "jianzong_steward"}
			),
			DialogueData.choice("我再准备一下", &"main"),
		]
	)
	data.add_line(
		&"history",
		"剑宗不问出身，只问出剑时是否仍记得自己的本心。",
		&"history_choice"
	)
	data.add_choice_node(
		&"history_choice",
		"大殿后方便是云台，历代弟子常在那里悟剑。",
		[
			DialogueData.choice("多谢指点", &"main"),
			DialogueData.choice("我现在去云台", &"", &"travel_cloud_terrace"),
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
		&"travel_cloud_terrace":
			change_to_scene(CLOUD_TERRACE_SCENE_PATH, &"cloud_arrival")
		&"scene_message":
			show_message(str(payload))


func _make_scene_banner_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.08, 0.2, 0.3),
		Color(0.2, 0.55, 0.72),
		Color(0.055, 0.09, 0.14),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.58, 1.0])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 256
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	return texture


## 程序化 2D 木架 + 练习用的模型节点。
func _make_sword_rack() -> Node2D:
	var root := Node2D.new()
	root.name = "SwordRackModel"

	var wood := Color(0.24, 0.13, 0.07)
	var metal := Color(0.62, 0.66, 0.7)

	var foot := ColorRect.new()
	foot.color = wood
	foot.position = Vector2(-46.0, -8.0)
	foot.size = Vector2(92.0, 8.0)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(foot)

	for x in [-30.0, 30.0]:
		var upright := ColorRect.new()
		upright.color = wood
		upright.position = Vector2(x - 5.0, -70.0)
		upright.size = Vector2(10.0, 62.0)
		upright.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(upright)

	var rail := ColorRect.new()
	rail.color = metal
	rail.position = Vector2(-34.0, -54.0)
	rail.size = Vector2(68.0, 7.0)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rail)

	for x in [-22.0, 0.0, 22.0]:
		var blade := ColorRect.new()
		blade.color = metal
		blade.position = Vector2(x - 3.0, -122.0)
		blade.size = Vector2(6.0, 70.0)
		blade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(blade)

	return root
