extends SceneTree

## 无界面自动化测试：验证固定视角 2D RPGScene、具体场景和互动物继承体系。
##
## 场景层没有可操控角色：玩家不能移动或转动视角，只能用鼠标点击 NPC、
## 调查物或传送门触发互动。战斗场景仍为 3D，不在此测试覆盖范围内。

const RPGSceneScript := preload("res://scripts/scenes/rpg_scene.gd")
const JianzongSceneScript := preload("res://scripts/scenes/jianzong_scene.gd")
const CloudTerraceSceneScript := preload(
	"res://scripts/scenes/cloud_terrace_scene.gd"
)
const SceneInteractableScript := preload(
	"res://scripts/core/scene_interactable.gd"
)
const SceneNPCScript := preload("res://scripts/scenes/interactables/scene_npc.gd")
const ScenePortalScript := preload(
	"res://scripts/scenes/interactables/scene_portal.gd"
)
const SceneInspectableScript := preload(
	"res://scripts/scenes/interactables/scene_inspectable.gd"
)
const SceneFlowScript := preload("res://scripts/core/scene_flow.gd")

var failures := 0
var _last_action: StringName = &""
var _last_payload: Variant = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _test_scene_hierarchy_and_registration()
	await _test_no_first_person_control()
	await _test_mouse_click_interactions()
	await _test_dialogue_action_flow()
	await _test_cloud_terrace_scene()
	_test_scene_flow_context()

	if failures == 0:
		print("SCENE TESTS PASSED")
		quit(0)
	else:
		print("SCENE TESTS FAILED: %d" % failures)
		quit(1)


func _test_scene_hierarchy_and_registration() -> void:
	var scene := JianzongSceneScript.new()
	root.add_child(scene)
	await process_frame

	_check(scene is Control, "场景根节点应为 2D Control")
	_check(scene is RPGScene, "剑宗场景应继承 RPGScene")
	_check(scene is RPGSceneScript, "剑宗场景应属于场景父类体系")
	_check(scene.background_enabled, "场景应启用背景绘制")
	_check(
		scene.get_node_or_null("SceneHUD/SceneTitle") is Label,
		"场景应生成标题 HUD"
	)
	_check(scene.dialogue_panel != null, "场景应生成对话 UI")
	_check(
		scene.get_node_or_null("LeftSwordBanner") is TextureRect,
		"场景应能放置 2D 贴图"
	)
	_check(
		scene.get_node_or_null("SwordRackAnchor") is Control,
		"场景应能放置 2D 建模节点"
	)

	var npc := scene.get_node_or_null("StewardNPC") as SceneNPC
	var inspectable := scene.get_node_or_null("SwordSchoolTablet") as SceneInspectable
	var mystic_portal := scene.get_node_or_null("MysticRealmPortal") as ScenePortal
	var portal := scene.get_node_or_null("CloudTerracePortal") as ScenePortal
	_check(npc != null, "具体场景应能放置 NPC")
	_check(inspectable != null, "具体场景应能放置调查物")
	_check(mystic_portal != null, "剑宗场景应放置秘境入口传送门")
	_check(portal != null, "具体场景应能放置传送门")
	_check(npc is SceneInteractable, "NPC 应继承互动物父类")
	_check(inspectable is SceneInteractable, "调查物应继承互动物父类")
	_check(mystic_portal is SceneInteractable, "秘境入口应继承互动物父类")
	_check(portal is SceneInteractable, "传送门应继承互动物父类")
	_check(
		scene.interactables.size() >= 3 if scene != null else false,
		"场景应自动注册所有互动物"
	)
	if mystic_portal != null:
		_check(
			mystic_portal.target_scene_path.ends_with("mystic_realm.tscn"),
			"秘境入口应连接到秘境场景"
		)
		_check(
			mystic_portal.target_spawn_id == &"mystic_arrival",
			"秘境入口应使用独立出生点"
		)
		_check(
			scene.spawn_points.has(&"mystic_return"),
			"剑宗场景应注册秘境返回出生点"
		)

	if portal != null:
		scene.unregister_interactable(portal)
		_check(
			not scene.interactables.has(portal),
			"互动物注销后应从未注册集合中移除"
		)
		scene.register_interactable(portal)
		_check(
			scene.interactables.has(portal),
			"互动物重新注册后应恢复"
		)

	scene.queue_free()
	await process_frame


func _test_no_first_person_control() -> void:
	var scene := JianzongSceneScript.new()
	root.add_child(scene)
	await process_frame

	_check(
		scene.find_children("*", "Camera3D", true, false).is_empty(),
		"2D 场景不应包含相机节点"
	)
	_check(
		scene.find_children("*", "Node3D", true, false).is_empty(),
		"2D 场景不应包含任何 3D 节点"
	)
	_check(
		scene.find_children("*", "CharacterBody3D", true, false).is_empty(),
		"2D 场景不应再生成第一人称玩家"
	)
	_check(
		scene.get_node_or_null("Player") == null,
		"场景不应存在可操控玩家节点"
	)

	scene.queue_free()
	await process_frame


func _test_mouse_click_interactions() -> void:
	var scene := JianzongSceneScript.new()
	root.add_child(scene)
	await process_frame

	var npc := scene.get_node_or_null("StewardNPC") as SceneNPC
	_check(npc != null, "点击交互测试应能找到 NPC")
	if npc != null:
		_click(npc)
		_check(
			scene.dialogue_panel != null and scene.dialogue_panel.visible,
			"鼠标点击 NPC 应打开对话面板"
		)
		_check(
			scene.active_interactable == npc,
			"点击 NPC 后应记录发起互动物"
		)
		scene.close_dialogue()
		_check(
			not scene.dialogue_panel.visible,
			"关闭对话后对话面板应隐藏"
		)

	var tablet := scene.get_node_or_null("SwordSchoolTablet") as SceneInspectable
	_check(tablet != null, "点击交互测试应能找到调查物")
	if tablet != null:
		scene.last_message_text = ""
		_click(tablet)
		_check(scene.is_message_visible(), "鼠标点击调查物应显示提示信息")
		_check(
			scene.last_message_text.contains("剑宗旧碑"),
			"调查物提示应包含调查标题"
		)

	var portal := scene.get_node_or_null("CloudTerracePortal") as ScenePortal
	_check(portal != null, "点击交互测试应能找到传送门")
	if portal != null:
		scene.requested_scene_path = ""
		_click(portal)
		_check(
			scene.requested_scene_path.ends_with("cloud_terrace.tscn"),
			"鼠标点击传送门应请求切换到目标场景"
		)

	var mystic_portal := scene.get_node_or_null(
		"MysticRealmPortal"
	) as ScenePortal
	_check(mystic_portal != null, "点击交互测试应能找到秘境入口")
	if mystic_portal != null:
		scene.requested_scene_path = ""
		_click(mystic_portal)
		_check(
			scene.requested_scene_path.ends_with("mystic_realm.tscn"),
			"鼠标点击秘境入口应请求进入秘境场景"
		)

	# 禁用后的互动物不应再响应点击。
	if portal != null:
		scene.requested_scene_path = ""
		portal.enabled = false
		_click(portal)
		_check(
			scene.requested_scene_path.is_empty(),
			"禁用后的互动物不应再响应鼠标点击"
		)
		portal.enabled = true

	scene.queue_free()
	await process_frame


func _test_dialogue_action_flow() -> void:
	var scene := JianzongSceneScript.new()
	root.add_child(scene)
	await process_frame

	var npc := scene.get_node_or_null("StewardNPC") as SceneNPC
	_check(npc != null, "对话动作测试应能找到 NPC")
	if npc == null:
		scene.queue_free()
		await process_frame
		return

	var dialogue := DialogueData.new("测试引路人")
	dialogue.add_choice_node(
		&"start",
		"请选择下一步。",
		[
			DialogueData.choice(
				"记录选择",
				&"",
				&"test_dialogue_action",
				{"value": 7}
			),
			DialogueData.choice("结束", &""),
		]
	)
	_last_action = &""
	_last_payload = null
	scene.dialogue_action_requested.connect(_on_test_dialogue_action)

	_check(scene.open_dialogue(dialogue, npc), "NPC 互动应能打开通用对话 UI")
	_check(scene.dialogue_panel.visible, "打开对话后对话面板应可见")
	_check(scene.active_interactable == npc, "打开对话时应记录发起互动物")
	scene.dialogue_panel.select_choice(0)
	_check(
		_last_action == &"test_dialogue_action",
		"对话选项应通过稳定 action_id 派发到场景层"
	)
	_check(
		_last_payload is Dictionary and _last_payload.get("value", 0) == 7,
		"对话选项应保留 payload"
	)
	_check(not scene.dialogue_panel.visible, "没有后续节点时选择选项应关闭对话")

	scene.queue_free()
	await process_frame


func _test_cloud_terrace_scene() -> void:
	var scene := CloudTerraceSceneScript.new()
	root.add_child(scene)
	await process_frame

	_check(scene is Control, "云台场景根节点应为 2D Control")
	_check(scene is RPGScene, "云台场景应继承 RPGScene")
	_check(scene.scene_id == &"cloud_terrace", "云台场景应提供自己的场景 ID")
	_check(
		scene.get_node_or_null("CloudScrollTexture") is TextureRect,
		"云台场景应能放置 2D 贴图"
	)
	_check(
		scene.get_node_or_null("CloudAttendantNPC") is SceneNPC,
		"云台场景应能复用 NPC 子类"
	)
	_check(
		scene.find_children("*", "Node3D", true, false).is_empty(),
		"云台场景不应包含任何 3D 节点"
	)

	var tablet := scene.get_node_or_null("CloudTablet") as SceneInspectable
	if tablet != null:
		scene.last_message_text = ""
		_click(tablet)
		_check(
			scene.is_message_visible(),
			"云台调查物应响应鼠标点击并显示提示"
		)

	scene.queue_free()
	await process_frame


func _test_scene_flow_context() -> void:
	var flow := SceneFlowScript.new()
	flow.begin_battle(
		"res://scenes/main.tscn",
		null,
		0.0,
		{"enemy_name": "测试敌人"}
	)
	_check(flow.has_battle_return(), "进入战斗后应保存返回场景")
	var target: Dictionary = flow.take_battle_return()
	_check(
		target.get("scene_path", "") == "res://scenes/main.tscn",
		"战斗返回目标应保留场景路径"
	)
	_check(
		target.get("position") == null,
		"2D 场景进入战斗时不应保存玩家位置"
	)
	_check(not flow.has_battle_return(), "取出返回目标后应清除战斗上下文")

	flow.queue_scene_entry(
		"res://scenes/cloud_terrace.tscn",
		&"cloud_arrival"
	)
	var entry: Dictionary = flow.consume_scene_entry(
		"res://scenes/cloud_terrace.tscn"
	)
	_check(
		StringName(entry.get("spawn_id", &"")) == &"cloud_arrival",
		"场景入口应保留目标出生点"
	)
	_check(
		flow.consume_scene_entry(
			"res://scenes/cloud_terrace.tscn"
		).is_empty(),
		"场景入口上下文应只消费一次"
	)
	flow.free()


## 直接向互动物派发一次左键点击，模拟鼠标点击场景对象。
func _click(target: SceneInteractable) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	target._gui_input(event)


func _on_test_dialogue_action(
	_scene: RPGScene,
	_source: SceneInteractable,
	action_id: StringName,
	payload: Variant
) -> void:
	_last_action = action_id
	_last_payload = payload


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)
