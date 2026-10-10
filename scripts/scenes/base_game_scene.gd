class_name BaseGameScene
extends Control

## 所有游戏场景的公共父类。
##
## 本类只负责与具体玩法无关的公共流程：
## - 场景标识（scene_id / scene_display_name / source_scene_path）
## - 跨场景流程（SceneFlow）与命名出生点消费
## - 场景切换与战斗切换
## - 通用提示信息 HUD
##
## 具体玩法通过模板方法接入：
##   _configure_scene()       声明场景标识、注册出生点、准备数据模型
##   _build_scene_ui()        构建 HUD 与操作界面
##   _build_concrete_scene()  布置场景内容
##   _apply_scene_entry()     消费入口上下文（覆写时必须调用 super()）
##   on_scene_ready()         内容布置完毕后的收尾钩子
##
## 2D 固定视角 RPG 场景（RPGScene）与本项目的战棋秘境场景（DungeonScene）
## 都继承本类，后续新增玩法只需再实现自己的钩子，不必重复公共流程。

signal scene_entered(scene: BaseGameScene, entry: Dictionary)
signal scene_exited(scene: BaseGameScene)

const SceneFlowScript := preload("res://scripts/core/scene_flow.gd")

const DEFAULT_BATTLE_SCENE := "res://scenes/battle.tscn"
const DEFAULT_MESSAGE_DURATION := 4.0

@export var scene_id: StringName = &""
@export var scene_display_name: String = "场景"
## 用于进入战斗后返回；留空时退回到 SceneTree 当前场景文件路径。
@export var source_scene_path: String = ""
@export var battle_scene_path: String = DEFAULT_BATTLE_SCENE

## 最近一次请求切换的场景与出生点，供测试和外部流程读取。
var requested_scene_path: String = ""
var requested_spawn_id: StringName = &""
var current_spawn_id: StringName = &""
var last_message_text: String = ""

var _scene_flow: Node = null
var _pending_entry: Dictionary = {}
var _message_label: Label = null
var _message_timer: Timer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_on_scene_resized)
	_configure_scene()
	_apply_scene_entry()
	_build_scene_ui()
	_build_concrete_scene()
	queue_redraw()
	on_scene_ready()
	scene_entered.emit(self, _pending_entry)


func _exit_tree() -> void:
	scene_exited.emit(self)


# ---------------------------------------------------------------------------
# 子类钩子
# ---------------------------------------------------------------------------


## 声明场景标识、注册出生点、准备数据模型。子类覆写时应先调用 super()。
func _configure_scene() -> void:
	if scene_id == &"":
		scene_id = StringName(name.to_snake_case())
	if scene_display_name.is_empty():
		scene_display_name = name


## 构建本场景的 HUD 与操作界面。默认只创建通用提示信息。
func _build_scene_ui() -> void:
	_build_message_hud()


## 布置本场景的贴图、模型与互动物。默认不放置任何内容。
func _build_concrete_scene() -> void:
	pass


## 内容布置完毕后的收尾钩子（绑定信号、刷新首帧显示等）。
func on_scene_ready() -> void:
	pass


## 窗口尺寸变化时的钩子。子类覆写时应先调用 super()。
func _on_scene_resized() -> void:
	pass


# ---------------------------------------------------------------------------
# 场景 / 战斗切换
# ---------------------------------------------------------------------------


func change_to_scene(
	target_path: String,
	spawn_id: StringName = &""
) -> void:
	if target_path.is_empty():
		return
	requested_scene_path = target_path
	requested_spawn_id = spawn_id
	get_scene_flow().queue_scene_entry(target_path, spawn_id)
	if not _can_change_scene():
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(target_path)


func enter_battle(encounter_data: Dictionary = {}) -> void:
	var data: Dictionary = encounter_data.duplicate(true)
	data["scene_id"] = scene_id
	get_scene_flow().begin_battle(_resolve_scene_path(), null, 0.0, data)
	if battle_scene_path.is_empty() or not _can_change_scene():
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(battle_scene_path)


func get_scene_flow() -> Node:
	if _scene_flow != null and is_instance_valid(_scene_flow):
		return _scene_flow
	var flow := get_node_or_null("/root/SceneFlow")
	if flow == null:
		flow = SceneFlowScript.new()
		flow.name = "SceneFlowFallback"
		add_child(flow)
	_scene_flow = flow
	return _scene_flow


func _resolve_scene_path() -> String:
	if not source_scene_path.is_empty():
		return source_scene_path
	if not is_inside_tree():
		return ""
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return ""
	return tree.current_scene.scene_file_path


func _can_change_scene() -> bool:
	if not is_inside_tree():
		return false
	var tree := get_tree()
	if tree == null:
		return false
	return tree.current_scene == self


## 消费进入本场景时排队携带的入口上下文（出生点、坐标覆写等）。
func _apply_scene_entry() -> void:
	_pending_entry = get_scene_flow().consume_scene_entry(_resolve_scene_path())
	current_spawn_id = StringName(_pending_entry.get("spawn_id", &""))


# ---------------------------------------------------------------------------
# 通用提示信息
# ---------------------------------------------------------------------------


func _build_message_hud() -> void:
	_message_label = Label.new()
	_message_label.name = "SceneMessage"
	_message_label.anchor_left = 0.5
	_message_label.anchor_right = 0.5
	_message_label.anchor_top = 0.0
	_message_label.anchor_bottom = 0.0
	_message_label.offset_left = -330.0
	_message_label.offset_right = 330.0
	_message_label.offset_top = 92.0
	_message_label.offset_bottom = 172.0
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_label.add_theme_font_size_override("font_size", 18)
	_message_label.add_theme_color_override(
		"font_color",
		Color(0.95, 0.9, 0.72)
	)
	_message_label.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.9)
	)
	_message_label.add_theme_constant_override("shadow_offset_x", 1)
	_message_label.add_theme_constant_override("shadow_offset_y", 2)
	_message_label.visible = false
	add_child(_message_label)

	_message_timer = Timer.new()
	_message_timer.name = "MessageTimer"
	_message_timer.one_shot = true
	_message_timer.wait_time = DEFAULT_MESSAGE_DURATION
	_message_timer.timeout.connect(_on_message_timeout)
	add_child(_message_timer)


func show_message(
	text: String,
	duration: float = DEFAULT_MESSAGE_DURATION
) -> void:
	last_message_text = text
	if _message_label == null:
		return
	_message_label.text = text
	_message_label.visible = true
	if _message_timer != null:
		_message_timer.start(maxf(duration, 0.2))


func is_message_visible() -> bool:
	return _message_label != null and _message_label.visible


func _on_message_timeout() -> void:
	if _message_label != null:
		_message_label.visible = false
