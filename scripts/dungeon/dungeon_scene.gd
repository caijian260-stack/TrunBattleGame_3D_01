class_name DungeonScene
extends BaseGameScene

## 副本秘境玩法场景。
##
## 本场景只负责把 DungeonMaze 数据模型编排成可操作界面：
## - 掷骰获取移动力；
## - 点击可达格后沿唯一通道路径移动；
## - 结算随机事件，遇到战斗时保存快照并进入战斗场景；
## - 战斗返回后恢复同一层迷宫，出口处可继续深入。
##
## 生成、寻路、移动力、奖励与事件规则全部由 DungeonMaze 负责，场景不复制
## 规则逻辑，后期替换棋盘表现或新增事件时不需要改动数据模型。

const HexGridScript := preload("res://scripts/dungeon/hex_grid.gd")
const DungeonMazeScript := preload("res://scripts/dungeon/dungeon_maze.gd")
const DungeonBoardViewScript := preload(
	"res://scripts/dungeon/dungeon_board_view.gd"
)

const JIANZONG_SCENE_PATH := "res://scenes/main.tscn"
const MYSTIC_REALM_SCENE_PATH := "res://scenes/mystic_realm.tscn"
const BATTLE_RETURN_SPAWN_ID := &"mystic_battle_return"
const DEFAULT_GRID_RADIUS := 2
const EVENT_LOG_VISIBLE_LINES := 12

var maze: DungeonMaze = null

var _board_view: DungeonBoardView = null
var _status_label: Label = null
var _hint_label: Label = null
var _event_log_label: RichTextLabel = null
var _reward_label: Label = null
var _roll_button: Button = null
var _descend_button: Button = null
var _leave_button: Button = null
var _restored_from_battle := false


func _configure_scene() -> void:
	super()
	scene_id = &"mystic_realm"
	scene_display_name = "秘境·六合阵"
	source_scene_path = MYSTIC_REALM_SCENE_PATH
	battle_scene_path = DEFAULT_BATTLE_SCENE
	maze = DungeonMazeScript.new()
	maze.generate(0, 1, DEFAULT_GRID_RADIUS, true)


func _apply_scene_entry() -> void:
	super()
	if current_spawn_id == &"":
		current_spawn_id = &"mystic_arrival"
	if current_spawn_id != BATTLE_RETURN_SPAWN_ID:
		return

	var scene_flow := get_scene_flow()
	if not scene_flow.has_dungeon_state():
		return
	var dungeon_state: Dictionary = scene_flow.peek_dungeon_state()
	if str(dungeon_state.get("scene_path", "")) != source_scene_path:
		return

	var taken_state: Dictionary = scene_flow.take_dungeon_state()
	var maze_state: Variant = taken_state.get("maze_state", {})
	if maze_state is Dictionary and not (maze_state as Dictionary).is_empty():
		maze.restore_snapshot(maze_state)
		_restored_from_battle = true


func _build_scene_ui() -> void:
	_build_backdrop()
	super()
	_build_dungeon_hud()


func on_scene_ready() -> void:
	_board_view.set_maze(maze)
	_board_view.cell_clicked.connect(_on_board_cell_clicked)
	_board_view.cell_hovered.connect(_on_board_cell_hovered)
	_refresh_ui()
	if _restored_from_battle:
		show_message("战斗结束，秘境阵纹将你送回原处。")


# ---------------------------------------------------------------------------
# 界面
# ---------------------------------------------------------------------------


func _build_backdrop() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "DungeonBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.012, 0.024, 0.038)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_index = -10
	add_child(backdrop)


func _build_dungeon_hud() -> void:
	var layout := HBoxContainer.new()
	layout.name = "DungeonHUD"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 28.0
	layout.offset_top = 28.0
	layout.offset_right = -28.0
	layout.offset_bottom = -28.0
	layout.add_theme_constant_override("separation", 18)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layout)

	var board_panel := PanelContainer.new()
	board_panel.name = "BoardPanel"
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.2, 0.62, 0.7))
	)
	layout.add_child(board_panel)

	_board_view = DungeonBoardViewScript.new()
	_board_view.name = "DungeonBoard"
	_board_view.custom_minimum_size = Vector2(680.0, 680.0)
	_board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.add_child(_board_view)

	var sidebar := PanelContainer.new()
	sidebar.name = "DungeonSidebar"
	sidebar.custom_minimum_size = Vector2(390.0, 0.0)
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.72, 0.58, 0.28))
	)
	layout.add_child(sidebar)
	_build_sidebar(sidebar)


func _build_sidebar(parent: Control) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	parent.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var title := Label.new()
	title.name = "DungeonTitle"
	title.text = scene_display_name
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.96, 0.91, 0.72))
	content.add_child(title)

	_status_label = Label.new()
	_status_label.name = "DungeonStatus"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(0.82, 0.92, 0.95))
	content.add_child(_status_label)

	_hint_label = Label.new()
	_hint_label.name = "DungeonHint"
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 15)
	_hint_label.add_theme_color_override("font_color", Color(0.58, 0.78, 0.82))
	content.add_child(_hint_label)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	content.add_child(action_row)

	_roll_button = Button.new()
	_roll_button.name = "RollMovementButton"
	_roll_button.text = "掷骰获取移动力"
	_roll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roll_button.custom_minimum_size = Vector2(0.0, 44.0)
	_roll_button.pressed.connect(_on_roll_movement_pressed)
	_style_button(_roll_button, Color(0.2, 0.66, 0.72))
	action_row.add_child(_roll_button)

	_descend_button = Button.new()
	_descend_button.name = "DescendButton"
	_descend_button.text = "深入下一层"
	_descend_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_descend_button.custom_minimum_size = Vector2(0.0, 44.0)
	_descend_button.pressed.connect(_on_descend_pressed)
	_style_button(_descend_button, Color(0.76, 0.54, 0.22))
	action_row.add_child(_descend_button)

	var reward_heading := Label.new()
	reward_heading.text = "本次收获"
	reward_heading.add_theme_font_size_override("font_size", 17)
	reward_heading.add_theme_color_override("font_color", Color(0.94, 0.78, 0.42))
	content.add_child(reward_heading)

	_reward_label = Label.new()
	_reward_label.name = "RewardSummary"
	_reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reward_label.custom_minimum_size = Vector2(0.0, 86.0)
	_reward_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_reward_label.add_theme_font_size_override("font_size", 15)
	_reward_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.9))
	content.add_child(_reward_label)

	var log_heading := Label.new()
	log_heading.text = "秘境见闻"
	log_heading.add_theme_font_size_override("font_size", 17)
	log_heading.add_theme_color_override("font_color", Color(0.64, 0.84, 0.9))
	content.add_child(log_heading)

	_event_log_label = RichTextLabel.new()
	_event_log_label.name = "EventLog"
	_event_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_event_log_label.custom_minimum_size = Vector2(0.0, 210.0)
	_event_log_label.scroll_following = true
	_event_log_label.add_theme_font_size_override("normal_font_size", 15)
	_event_log_label.add_theme_color_override(
		"default_color",
		Color(0.82, 0.88, 0.9)
	)
	_event_log_label.add_theme_stylebox_override(
		"normal",
		_make_flat_style(
			Color(0.02, 0.04, 0.055, 0.9),
			Color(0.24, 0.42, 0.48, 0.8),
			7
		)
	)
	content.add_child(_event_log_label)

	_leave_button = Button.new()
	_leave_button.name = "LeaveDungeonButton"
	_leave_button.text = "离开秘境"
	_leave_button.custom_minimum_size = Vector2(0.0, 42.0)
	_leave_button.pressed.connect(_on_leave_dungeon_pressed)
	_style_button(_leave_button, Color(0.46, 0.42, 0.52))
	content.add_child(_leave_button)


# ---------------------------------------------------------------------------
# 操作
# ---------------------------------------------------------------------------


func _on_roll_movement_pressed() -> void:
	var result: Dictionary = maze.roll_movement()
	var granted := int(result.get("granted", 0))
	if granted > 0:
		show_message("掷骰结果：获得 %d 点移动力。" % granted)
	else:
		show_message(str(result.get("detail", "尚有移动力可用。")))
	_refresh_ui()


func _on_board_cell_clicked(cell: Vector2i) -> void:
	if not maze.has_cell(cell) or cell == maze.current_cell:
		return
	var reachable := maze.reachable_cells()
	var cell_key := HexGridScript.key(cell)
	if not reachable.has(cell_key):
		show_message("当前移动力无法到达该格。")
		return
	if int(reachable[cell_key]) <= 0:
		return
	_move_along_path(cell)


func _move_along_path(target: Vector2i) -> void:
	var path := maze.find_path(target)
	if path.size() <= 1:
		show_message("没有通向该格的路径。")
		return

	for index in range(1, path.size()):
		var result: Dictionary = maze.step_to(path[index])
		if not bool(result.get("ok", false)):
			show_message(str(result.get("reason", "无法继续移动。")))
			break
		var event_data: Dictionary = result.get("event", {})
		if not event_data.is_empty():
			_show_event_feedback(event_data)
			if event_data.has("encounter"):
				_refresh_ui()
				_start_encounter(event_data["encounter"])
				return

	_refresh_ui()


func _show_event_feedback(event_data: Dictionary) -> void:
	var message := str(event_data.get("message", ""))
	if not message.is_empty():
		show_message(message)


func _start_encounter(raw_encounter: Variant) -> void:
	if raw_encounter is not Dictionary:
		return
	var encounter_data: Dictionary = (raw_encounter as Dictionary).duplicate(true)
	encounter_data["return_spawn_id"] = BATTLE_RETURN_SPAWN_ID
	_save_dungeon_state()
	enter_battle(encounter_data)


func _save_dungeon_state() -> void:
	get_scene_flow().set_dungeon_state({
		"scene_path": source_scene_path,
		"maze_state": maze.snapshot(),
	})


func _on_descend_pressed() -> void:
	if not maze.can_exit():
		show_message("需要先抵达秘境出口，才能深入下一层。")
		return
	maze.descend()
	show_message("踏入第 %d 层秘境。" % maze.floor_index)
	_refresh_ui()


func _on_leave_dungeon_pressed() -> void:
	get_scene_flow().clear_dungeon_state()
	change_to_scene(JIANZONG_SCENE_PATH, &"mystic_return")


func _on_board_cell_hovered(cell: Vector2i) -> void:
	if _hint_label == null or maze == null:
		return
	if not maze.has_cell(cell):
		_hint_label.text = "请选择发光的可达格。"
		return
	var event_type := maze.event_at(cell)
	var detail := maze.event_detail_at(cell)
	if detail.is_empty():
		_hint_label.text = maze_event_label(event_type)
	else:
		_hint_label.text = "%s：%s" % [maze_event_label(event_type), detail]


func maze_event_label(event_type: int) -> String:
	return DungeonMazeScript.event_label(event_type)


# ---------------------------------------------------------------------------
# 刷新
# ---------------------------------------------------------------------------


func _refresh_ui() -> void:
	if maze == null or _status_label == null or _board_view == null:
		return

	var current_event := maze.event_at(maze.current_cell)
	_status_label.text = "第 %d 层    移动力 %d    %s" % [
		maze.floor_index,
		maze.remaining_movement,
		maze.movement_dice.label(),
	]
	_status_label.text += "\n当前位置：%s" % DungeonMazeScript.event_label(current_event)

	if maze.remaining_movement > 0:
		_hint_label.text = "选择高亮格移动，遇战斗会立即停下。"
		_board_view.set_reachable_cells(maze.reachable_cells())
	else:
		_hint_label.text = (
			"已抵达出口，可深入下一层。"
			if maze.can_exit()
			else "移动力已耗尽，请掷骰获取新的移动力。"
		)
		_board_view.clear_reachable_cells()
	_board_view.refresh()

	_roll_button.disabled = maze.remaining_movement > 0
	_descend_button.disabled = not maze.can_exit()
	_reward_label.text = _format_rewards()
	_event_log_label.text = _format_event_log()


func _format_rewards() -> String:
	var lines := PackedStringArray()
	lines.append("炼器材料：%d" % int(
		maze.collected_rewards.get(
			DungeonMazeScript.RewardType.FORGE_MATERIAL,
			0
		)
	))
	lines.append("炼丹材料：%d" % int(
		maze.collected_rewards.get(
			DungeonMazeScript.RewardType.ALCHEMY_MATERIAL,
			0
		)
	))
	lines.append("法宝机缘：%d" % maze.collected_artifacts.size())
	lines.append("任务线索：%d" % maze.quest_clues.size())
	if not maze.collected_artifacts.is_empty():
		lines.append("法宝：" + ", ".join(maze.collected_artifacts))
	return "\n".join(lines)


func _format_event_log() -> String:
	var start := maxi(maze.event_log.size() - EVENT_LOG_VISIBLE_LINES, 0)
	var lines := PackedStringArray()
	for index in range(start, maze.event_log.size()):
		lines.append("- " + maze.event_log[index])
	return "\n".join(lines)


# ---------------------------------------------------------------------------
# 样式
# ---------------------------------------------------------------------------


func _make_panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.035, 0.052, 0.94)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.62)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 8
	return style


func _make_flat_style(
	color: Color,
	border_color: Color,
	radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override(
		"normal",
		_make_flat_style(
			accent.darkened(0.62),
			Color(accent.r, accent.g, accent.b, 0.72),
			7
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_flat_style(
			accent.darkened(0.42),
			Color(accent.r, accent.g, accent.b, 0.92),
			7
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_flat_style(accent.darkened(0.22), Color.WHITE, 7)
	)
	button.add_theme_stylebox_override(
		"disabled",
		_make_flat_style(
			Color(0.09, 0.11, 0.13),
			Color(0.24, 0.28, 0.31),
			7
		)
	)
	button.add_theme_color_override("font_color", Color(0.9, 0.95, 0.98))
	button.add_theme_color_override(
		"font_disabled_color",
		Color(0.42, 0.47, 0.51)
	)
