class_name BattleScene2D
extends Control

## 2D 战斗场景父类。
##
## 本类只负责 2D 表现与输入界面，战斗规则仍由 BattleEngine 和 CharacterClass
## 子类提供。具体 2D 场景可以通过继承本类替换职业、敌人和默认外观。

const BattleEngineScript := preload("res://scripts/core/battle_engine.gd")
const BattleQTEScript := preload("res://scripts/core/battle_qte.gd")
const SwordCultivatorScript := preload("res://scripts/classes/sword_cultivator.gd")
const TrainingDummyScript := preload("res://scripts/classes/training_dummy.gd")
const BattleMenuScript := preload("res://scripts/core/battle_menu.gd")

const PLAYER_ACCENT := Color(0.22, 0.74, 0.96)
const ENEMY_ACCENT := Color(0.96, 0.32, 0.25)
const HEALTH_HIGH := Color(0.25, 0.9, 0.52)
const HEALTH_MEDIUM := Color(1.0, 0.76, 0.2)
const HEALTH_LOW := Color(1.0, 0.25, 0.2)

enum View {
	MAIN,
	SKILLS,
	CLASS_SPECIAL,
}

var engine: BattleEngine
var player_unit: BattleUnit
var enemy_unit: BattleUnit
var current_view: int = View.MAIN
var encounter_data: Dictionary = {}

var _turn_label: Label
var _player_status: Label
var _enemy_status: Label
var _player_battle_label: Label
var _enemy_battle_label: Label
var _log_label: RichTextLabel
var _action_panel: PanelContainer
var _action_title: Label
var _action_grid: GridContainer
var _end_turn_button: Button
var _result_panel: PanelContainer
var _result_label: Label
var _result_hint: Label
var _return_scene_button: Button
var _qte_panel: PanelContainer
var _qte_title: Label
var _qte_instruction: Label
var _qte_input_hint: Label
var _qte_result: Label
var _qte_track: Control
var _qte_pointer: ColorRect
var _qte_success_zone: ColorRect
var _qte_perfect_zone: ColorRect
var _qte_task: BattleQTE = null
var _qte_active := false
var _qte_elapsed := 0.0
var _qte_hide_at := 0.0
var _scene_flow: Node = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_on_resized)
	_load_encounter_context()
	_build_hud()
	_setup_battle()
	_refresh_ui()


func _process(delta: float) -> void:
	if _qte_active and _qte_task != null:
		_qte_elapsed += delta
		var progress := clampf(
			_qte_elapsed / maxf(_qte_task.duration, 0.001),
			0.0,
			1.0
		)
		_set_qte_progress(progress)
		if progress >= 1.0:
			_finish_qte(BattleQTEScript.Grade.FAILURE)

	if (
		_qte_panel != null
		and _qte_panel.visible
		and not _qte_active
		and _qte_hide_at > 0.0
		and Time.get_ticks_msec() / 1000.0 >= _qte_hide_at
	):
		_qte_panel.visible = false
		_qte_hide_at = 0.0


func _draw() -> void:
	var canvas_size := size
	if canvas_size.x <= 1.0 or canvas_size.y <= 1.0:
		return

	draw_rect(Rect2(Vector2.ZERO, canvas_size), Color(0.035, 0.055, 0.08))
	draw_rect(
		Rect2(0.0, canvas_size.y * 0.58, canvas_size.x, canvas_size.y * 0.42),
		Color(0.06, 0.1, 0.12)
	)

	var arena_center := Vector2(canvas_size.x * 0.5, canvas_size.y * 0.72)
	var arena_radius := Vector2(canvas_size.x * 0.42, canvas_size.y * 0.2)
	var arena_points := _ellipse_points(arena_center, arena_radius, 72)
	arena_points.append(arena_points[0])
	draw_colored_polygon(arena_points, Color(0.09, 0.145, 0.18, 0.96))
	draw_polyline(arena_points, Color(0.18, 0.48, 0.62, 0.75), 3.0)
	draw_arc(
		arena_center,
		arena_radius.x * 0.55,
		0.0,
		TAU,
		72,
		Color(0.16, 0.34, 0.42, 0.65),
		2.0
	)

	if player_unit != null:
		_draw_unit(_player_origin(), PLAYER_ACCENT, true)
	if enemy_unit != null:
		_draw_unit(_enemy_origin(), ENEMY_ACCENT, false)


func _build_hud() -> void:
	_turn_label = Label.new()
	_turn_label.name = "TurnLabel"
	_turn_label.anchor_left = 0.5
	_turn_label.anchor_right = 0.5
	_turn_label.offset_left = -240.0
	_turn_label.offset_right = 240.0
	_turn_label.offset_top = 16.0
	_turn_label.offset_bottom = 58.0
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_label.add_theme_font_size_override("font_size", 24)
	_turn_label.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0))
	add_child(_turn_label)

	_player_status = _create_status_panel("玩家单位", PLAYER_ACCENT, false)
	_enemy_status = _create_status_panel("敌方单位", ENEMY_ACCENT, true)
	_player_battle_label = _create_battle_label(PLAYER_ACCENT)
	_enemy_battle_label = _create_battle_label(ENEMY_ACCENT)
	_create_action_panel()
	_create_log_panel()
	_create_qte_panel()
	_create_result_panel()


func _create_status_panel(title: String, accent: Color, align_right: bool) -> Label:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0 if align_right else 0.0
	panel.anchor_right = 1.0 if align_right else 0.0
	panel.offset_left = -348.0 if align_right else 18.0
	panel.offset_right = -18.0 if align_right else 348.0
	panel.offset_top = 18.0
	panel.offset_bottom = 172.0
	panel.add_theme_stylebox_override("panel", _panel_style(accent))
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)

	var accent_line := ColorRect.new()
	accent_line.custom_minimum_size = Vector2(0.0, 3.0)
	accent_line.color = accent
	content.add_child(accent_line)

	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 17)
	heading.add_theme_color_override("font_color", accent.lightened(0.22))
	content.add_child(heading)

	var status := Label.new()
	status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", Color(0.9, 0.94, 0.97))
	content.add_child(status)
	return status


func _create_battle_label(accent: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(220.0, 42.0)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", accent.lightened(0.15))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	return label


func _create_action_panel() -> void:
	_action_panel = PanelContainer.new()
	_action_panel.name = "ActionPanel"
	_action_panel.anchor_top = 1.0
	_action_panel.anchor_bottom = 1.0
	_action_panel.offset_left = 18.0
	_action_panel.offset_top = -286.0
	_action_panel.offset_right = 458.0
	_action_panel.offset_bottom = -18.0
	_action_panel.add_theme_stylebox_override("panel", _panel_style(PLAYER_ACCENT))
	add_child(_action_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_action_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	_action_title = Label.new()
	_action_title.text = "行动"
	_action_title.add_theme_font_size_override("font_size", 18)
	_action_title.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0))
	content.add_child(_action_title)

	_action_grid = GridContainer.new()
	_action_grid.columns = 2
	_action_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_action_grid.add_theme_constant_override("h_separation", 8)
	_action_grid.add_theme_constant_override("v_separation", 8)
	content.add_child(_action_grid)

	_end_turn_button = Button.new()
	_end_turn_button.text = "结束回合"
	_end_turn_button.custom_minimum_size = Vector2(0.0, 38.0)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_style_button(_end_turn_button, Color(0.18, 0.52, 0.74))
	content.add_child(_end_turn_button)


func _create_log_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "BattleLogPanel"
	panel.anchor_left = 1.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -424.0
	panel.offset_top = -286.0
	panel.offset_right = -18.0
	panel.offset_bottom = -18.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.3, 0.58, 0.72)))
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)

	var heading := Label.new()
	heading.text = "战斗记录"
	heading.add_theme_font_size_override("font_size", 17)
	heading.add_theme_color_override("font_color", Color(0.68, 0.84, 0.94))
	content.add_child(heading)

	_log_label = RichTextLabel.new()
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.scroll_following = true
	_log_label.add_theme_font_size_override("normal_font_size", 14)
	_log_label.add_theme_color_override("default_color", Color(0.86, 0.9, 0.94))
	_log_label.add_theme_stylebox_override(
		"normal",
		_flat_style(Color(0.025, 0.04, 0.06, 0.82), Color(0.2, 0.34, 0.42, 0.8), 8)
	)
	content.add_child(_log_label)


func _create_qte_panel() -> void:
	_qte_panel = PanelContainer.new()
	_qte_panel.name = "QTEPanel"
	_qte_panel.anchor_left = 0.5
	_qte_panel.anchor_top = 1.0
	_qte_panel.anchor_right = 0.5
	_qte_panel.anchor_bottom = 1.0
	_qte_panel.offset_left = -320.0
	_qte_panel.offset_top = -210.0
	_qte_panel.offset_right = 320.0
	_qte_panel.offset_bottom = -36.0
	_qte_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.92, 0.68, 0.22)))
	add_child(_qte_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_qte_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	_qte_title = Label.new()
	_qte_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qte_title.add_theme_font_size_override("font_size", 20)
	_qte_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	content.add_child(_qte_title)

	_qte_instruction = Label.new()
	_qte_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qte_instruction.add_theme_font_size_override("font_size", 14)
	_qte_instruction.add_theme_color_override("font_color", Color(0.84, 0.9, 0.95))
	content.add_child(_qte_instruction)

	_qte_track = Control.new()
	_qte_track.custom_minimum_size = Vector2(0.0, 48.0)
	_qte_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_qte_track)

	var track_background := ColorRect.new()
	track_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track_background.color = Color(0.06, 0.085, 0.12, 0.98)
	_qte_track.add_child(track_background)

	_qte_success_zone = ColorRect.new()
	_qte_success_zone.color = Color(0.16, 0.55, 0.72, 0.72)
	_qte_track.add_child(_qte_success_zone)

	_qte_perfect_zone = ColorRect.new()
	_qte_perfect_zone.color = Color(1.0, 0.72, 0.22, 0.92)
	_qte_track.add_child(_qte_perfect_zone)

	_qte_pointer = ColorRect.new()
	_qte_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_qte_pointer.color = Color.WHITE
	_qte_pointer.size = Vector2(4.0, 48.0)
	_qte_track.add_child(_qte_pointer)

	var hint_row := HBoxContainer.new()
	hint_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hint_row.add_theme_constant_override("separation", 18)
	content.add_child(hint_row)

	_qte_input_hint = Label.new()
	_qte_input_hint.text = "鼠标左键 / 空格"
	_qte_input_hint.add_theme_font_size_override("font_size", 14)
	_qte_input_hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.62))
	hint_row.add_child(_qte_input_hint)

	_qte_result = Label.new()
	_qte_result.text = "等待判定"
	_qte_result.add_theme_font_size_override("font_size", 14)
	_qte_result.add_theme_color_override("font_color", Color(0.7, 0.78, 0.84))
	hint_row.add_child(_qte_result)
	_qte_panel.visible = false


func _create_result_panel() -> void:
	_result_panel = PanelContainer.new()
	_result_panel.name = "ResultPanel"
	_result_panel.anchor_left = 0.5
	_result_panel.anchor_top = 0.5
	_result_panel.anchor_right = 0.5
	_result_panel.anchor_bottom = 0.5
	_result_panel.offset_left = -220.0
	_result_panel.offset_top = -78.0
	_result_panel.offset_right = 220.0
	_result_panel.offset_bottom = 78.0
	_result_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.35, 0.68, 0.85)))
	add_child(_result_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_result_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 24)
	_result_label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	content.add_child(_result_label)

	_result_hint = Label.new()
	_result_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_hint.add_theme_font_size_override("font_size", 14)
	_result_hint.add_theme_color_override("font_color", Color(0.62, 0.74, 0.82))
	content.add_child(_result_hint)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 10)
	content.add_child(action_row)

	_return_scene_button = Button.new()
	_return_scene_button.text = "返回场景"
	_return_scene_button.custom_minimum_size = Vector2(124.0, 38.0)
	_return_scene_button.pressed.connect(_on_return_scene_pressed)
	_style_button(_return_scene_button, Color(0.24, 0.62, 0.78))
	action_row.add_child(_return_scene_button)

	var restart_button := Button.new()
	restart_button.text = "重新开始"
	restart_button.custom_minimum_size = Vector2(124.0, 38.0)
	restart_button.pressed.connect(_on_restart_pressed)
	_style_button(restart_button, Color(0.4, 0.46, 0.55))
	action_row.add_child(restart_button)
	_result_panel.visible = false


func _load_encounter_context() -> void:
	var scene_flow := _get_scene_flow()
	if scene_flow == null:
		return
	encounter_data = scene_flow.encounter_data.duplicate(true)


func _get_scene_flow() -> Node:
	if _scene_flow != null and is_instance_valid(_scene_flow):
		return _scene_flow
	_scene_flow = get_node_or_null("/root/SceneFlow")
	return _scene_flow


func _setup_battle() -> void:
	engine = BattleEngineScript.new()
	var player_class := _create_player_class()
	var enemy_class := _create_enemy_class()
	var player_name := str(encounter_data.get("player_name", "剑修"))
	var enemy_name := str(encounter_data.get("enemy_name", "训练假人"))
	var enemy_max_hp := int(encounter_data.get("enemy_max_hp", 260))
	var enemy_attack := int(encounter_data.get("enemy_attack", 14))

	engine.state_changed.connect(_on_state_changed)
	engine.log_emitted.connect(_on_log_emitted)
	engine.unit_changed.connect(_on_unit_changed)
	engine.battle_finished.connect(_on_battle_finished)
	engine.battle_escaped.connect(_on_battle_escaped)
	engine.qte_started.connect(_on_qte_started)
	engine.qte_resolved.connect(_on_qte_resolved)

	engine.setup_battle(
		[{
			"name": player_name,
			"max_hp": int(encounter_data.get("player_max_hp", 180)),
			"attack": int(encounter_data.get("player_attack", 20)),
			"class": player_class,
		}],
		[{
			"name": enemy_name,
			"max_hp": enemy_max_hp,
			"attack": enemy_attack,
			"class": enemy_class,
		}]
	)
	player_unit = engine.player_units[0]
	enemy_unit = engine.enemy_units[0]
	engine.start()


func _create_player_class() -> CharacterClass:
	var sword_class := SwordCultivatorScript.new()
	sword_class.spiritual_sense = 25
	return sword_class


func _create_enemy_class() -> CharacterClass:
	return TrainingDummyScript.new()


func _refresh_ui() -> void:
	if player_unit == null or enemy_unit == null or engine == null:
		return

	_player_status.text = _format_status(player_unit)
	_enemy_status.text = _format_status(enemy_unit)
	_turn_label.text = _turn_text()
	_player_battle_label.text = _format_battle_label(player_unit)
	_enemy_battle_label.text = _format_battle_label(enemy_unit)
	_layout_battle_labels()
	_end_turn_button.disabled = engine.current_state != BattleEngineScript.State.PLAYER_TURN
	_refresh_action_menu()
	queue_redraw()


func _refresh_action_menu() -> void:
	for child in _action_grid.get_children():
		_action_grid.remove_child(child)
		child.queue_free()

	var is_player_turn := engine.current_state == BattleEngineScript.State.PLAYER_TURN
	var actor := engine.active_actor if is_player_turn else null
	if not is_player_turn or actor == null:
		_action_title.text = "等待行动"
		var waiting := Label.new()
		waiting.text = "当前不是玩家回合"
		waiting.add_theme_color_override("font_color", Color(0.6, 0.7, 0.78))
		waiting.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_action_grid.add_child(waiting)
		return

	match current_view:
		View.SKILLS:
			_action_title.text = "技能"
			_add_command_buttons(actor, actor.battle_class.build_skill_commands(), true)
		View.CLASS_SPECIAL:
			_action_title.text = actor.battle_class.get_class_action_menu_name()
			_add_command_buttons(
				actor,
				actor.battle_class.build_class_action_commands(),
				true
			)
		_:
			_action_title.text = "行动"
			_add_main_buttons(actor)


func _add_main_buttons(actor: BattleUnit) -> void:
	var skill_commands := actor.battle_class.build_skill_commands()
	var special_commands := actor.battle_class.build_class_action_commands()
	var attack_command := actor.battle_class.build_attack_command()
	var ultimate_command := actor.battle_class.build_ultimate_command()

	_add_action_button(
		"技能",
		func() -> void: _set_view(View.SKILLS),
		"" if not skill_commands.is_empty() else "当前没有可用技能",
		not skill_commands.is_empty()
	)
	_add_action_button(
		actor.battle_class.get_class_action_menu_name(),
		func() -> void: _set_view(View.CLASS_SPECIAL),
		"" if not special_commands.is_empty() else "当前没有职业特殊行动",
		not special_commands.is_empty()
	)
	_add_action_button(
		"攻击",
		func() -> void: _submit_command(attack_command.id if attack_command != null else &""),
		_command_tooltip(actor, attack_command),
		_is_command_available_for_actor(actor, attack_command)
	)
	if ultimate_command != null:
		_add_action_button(
			ultimate_command.display_name,
			func() -> void: _submit_command(ultimate_command.id),
			_command_tooltip(actor, ultimate_command),
			_is_command_available_for_actor(actor, ultimate_command)
		)
	_add_action_button(
		BattleMenuScript.option_label(BattleMenuScript.Option.ESCAPE),
		func() -> void: engine.escape_player(),
		"尝试离开战斗",
		true
	)


func _add_command_buttons(
	actor: BattleUnit,
	commands: Array[BattleCommand],
	allow_back: bool
) -> void:
	for command in commands:
		_add_action_button(
			command.display_name,
			func() -> void: _submit_command(command.id),
			_command_tooltip(actor, command),
			_is_command_available_for_actor(actor, command)
		)
	if allow_back:
		_add_action_button("返回", _on_back_requested, "返回主菜单", true)


func _add_action_button(
	text: String,
	action: Callable,
	tooltip: String,
	available: bool = true
) -> void:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.disabled = not available
	button.custom_minimum_size = Vector2(0.0, 40.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	_style_button(button, PLAYER_ACCENT)
	_action_grid.add_child(button)


func _set_view(view: int) -> void:
	current_view = view
	_refresh_ui()


func _submit_command(command_id: StringName) -> void:
	if command_id == &"":
		return
	engine.submit_player_command(command_id)
	_refresh_ui()


func _on_back_requested() -> void:
	current_view = View.MAIN
	_refresh_ui()


func _on_end_turn_pressed() -> void:
	if engine != null:
		engine.end_player_turn()
	_refresh_ui()


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _on_return_scene_pressed() -> void:
	var scene_flow := _get_scene_flow()
	if scene_flow == null or not scene_flow.has_battle_return():
		return
	var target: Dictionary = scene_flow.take_battle_return()
	var scene_path := str(target.get("scene_path", ""))
	if scene_path.is_empty():
		return
	scene_flow.queue_scene_entry(
		scene_path,
		StringName(target.get("spawn_id", &"")),
		target.get("position", null),
		target.get("yaw", null)
	)
	get_tree().change_scene_to_file(scene_path)


func _on_state_changed(state: int) -> void:
	if state != BattleEngineScript.State.PLAYER_TURN:
		current_view = View.MAIN
	_refresh_ui()


func _on_unit_changed(_unit: BattleUnit) -> void:
	_refresh_ui()


func _on_battle_finished(player_won: bool) -> void:
	_result_label.text = "战斗结束：" + ("胜利" if player_won else "失败")
	_refresh_result_panel()


func _on_battle_escaped() -> void:
	_result_label.text = "战斗结束：成功逃走"
	_refresh_result_panel()


func _refresh_result_panel() -> void:
	var scene_flow := _get_scene_flow()
	var can_return := scene_flow != null and bool(scene_flow.has_battle_return())
	_return_scene_button.visible = can_return
	_result_hint.text = "选择返回场景或重新开始" if can_return else "点击重新开始再战"
	_result_panel.visible = true
	_refresh_ui()


func _on_log_emitted(text: String) -> void:
	_log_label.append_text(text + "\n")


func _input(event: InputEvent) -> void:
	if not _qte_active or _qte_task == null:
		return
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		_finish_qte(_qte_task.evaluate(_qte_progress()))
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_SPACE:
			_finish_qte(_qte_task.evaluate(_qte_progress()))
			get_viewport().set_input_as_handled()


func _on_qte_started(task: BattleQTE) -> void:
	_qte_task = task
	_qte_active = true
	_qte_elapsed = 0.0
	_qte_hide_at = 0.0
	_qte_panel.visible = true
	_qte_title.text = task.get_title()
	_qte_instruction.text = task.get_instruction()
	_qte_input_hint.text = task.get_input_hint()
	_qte_result.text = "等待判定"
	_qte_result.add_theme_color_override("font_color", Color(0.7, 0.78, 0.84))
	_apply_qte_zones(task)
	_set_qte_progress(0.0)


func _on_qte_resolved(task: BattleQTE, grade: int) -> void:
	_qte_result.text = "结果：" + task.get_result_label(grade)
	var color := Color(0.72, 0.8, 0.86)
	match grade:
		BattleQTEScript.Grade.FAILURE:
			color = Color(1.0, 0.42, 0.36)
		BattleQTEScript.Grade.SUCCESS:
			color = Color(0.4, 0.86, 1.0)
		BattleQTEScript.Grade.PERFECT:
			color = Color(1.0, 0.82, 0.3)
	_qte_result.add_theme_color_override("font_color", color)
	_qte_hide_at = Time.get_ticks_msec() / 1000.0 + 0.75


func _finish_qte(grade: int) -> void:
	if not _qte_active or _qte_task == null or engine == null:
		return
	_qte_active = false
	_set_qte_progress(_qte_progress())
	engine.resolve_qte(grade)


func _apply_qte_zones(task: BattleQTE) -> void:
	if _qte_success_zone == null or _qte_perfect_zone == null or task == null:
		return
	_qte_success_zone.anchor_left = 0.5 - task.success_window
	_qte_success_zone.anchor_right = 0.5 + task.success_window
	_qte_success_zone.anchor_top = 0.0
	_qte_success_zone.anchor_bottom = 1.0
	_qte_perfect_zone.anchor_left = 0.5 - task.perfect_window
	_qte_perfect_zone.anchor_right = 0.5 + task.perfect_window
	_qte_perfect_zone.anchor_top = 0.0
	_qte_perfect_zone.anchor_bottom = 1.0


func _qte_progress() -> float:
	if _qte_task == null:
		return 0.0
	return clampf(_qte_elapsed / maxf(_qte_task.duration, 0.001), 0.0, 1.0)


func _set_qte_progress(progress: float) -> void:
	if _qte_track == null or _qte_pointer == null:
		return
	var width := maxf(_qte_track.size.x, 1.0)
	_qte_pointer.size.y = _qte_track.size.y
	_qte_pointer.position = Vector2(
		clampf(progress, 0.0, 1.0) * width - _qte_pointer.size.x * 0.5,
		0.0
	)


func _format_status(unit: BattleUnit) -> String:
	var text := "%s %d/%d    %s %d/%d    %s %d/%d    %s %d" % [
		BattleAttribute.label(BattleAttribute.Type.HP),
		unit.hp,
		unit.max_hp,
		BattleAttribute.label(BattleAttribute.Type.AP),
		unit.ap,
		unit.max_ap,
		BattleAttribute.label(BattleAttribute.Type.AT),
		unit.at,
		unit.max_at,
		BattleAttribute.label(BattleAttribute.Type.ATTACK),
		unit.attack,
	]
	for line in unit.battle_class.get_status_lines():
		text += "\n" + line
	return text


func _format_battle_label(unit: BattleUnit) -> String:
	return "%s\nHP %d / %d" % [unit.unit_name, unit.hp, unit.max_hp]


func _turn_text() -> String:
	var state_name := ""
	match engine.current_state:
		BattleEngineScript.State.PLAYER_TURN:
			state_name = "玩家回合"
		BattleEngineScript.State.ENEMY_TURN:
			state_name = "敌方回合"
		BattleEngineScript.State.QTE:
			state_name = "QTE判定"
		BattleEngineScript.State.RESOLVING:
			state_name = "行动结算"
		BattleEngineScript.State.TURN_START:
			state_name = "回合开始"
		BattleEngineScript.State.TURN_END:
			state_name = "回合结束"
		BattleEngineScript.State.BATTLE_END:
			state_name = "战斗结束"
		_:
			state_name = "战斗准备"
	return "第 %d 回合  |  %s" % [engine.round_number, state_name]


func _command_tooltip(actor: BattleUnit, command: BattleCommand) -> String:
	if command == null:
		return ""
	var tooltip := command.description
	if not command.disabled_reason.is_empty():
		tooltip += "\n不可用：" + command.disabled_reason
	elif command.uses_action and actor != null and actor.at <= 0:
		tooltip += (
			"\n不可用："
			+ BattleAttribute.label(BattleAttribute.Type.AT)
			+ "不足"
		)
	return tooltip


func _is_command_available_for_actor(actor: BattleUnit, command: BattleCommand) -> bool:
	if actor == null or command == null or not command.available:
		return false
	if command.uses_action and actor.at <= 0:
		return false
	return true


func _on_resized() -> void:
	if _qte_track != null:
		_set_qte_progress(_qte_progress())
	_layout_battle_labels()
	queue_redraw()


func _layout_battle_labels() -> void:
	if _player_battle_label == null or _enemy_battle_label == null:
		return
	_player_battle_label.position = _player_origin() + Vector2(-110.0, 82.0)
	_enemy_battle_label.position = _enemy_origin() + Vector2(-110.0, 82.0)


func _player_origin() -> Vector2:
	return Vector2(size.x * 0.27, size.y * 0.67)


func _enemy_origin() -> Vector2:
	return Vector2(size.x * 0.73, size.y * 0.67)


func _draw_unit(origin: Vector2, accent: Color, is_player: bool) -> void:
	var unit := player_unit if is_player else enemy_unit
	if unit == null:
		return
	var alive := unit.hp > 0
	var active := engine != null and engine.active_actor == unit
	var shadow := Color(0.0, 0.0, 0.0, 0.36)
	var skin := Color(0.88, 0.72, 0.58)
	var cloth := accent.darkened(0.28)
	var metal := Color(0.76, 0.84, 0.9)

	draw_circle(origin + Vector2(0.0, 36.0), 48.0, shadow)
	if active and alive:
		draw_arc(origin + Vector2(0.0, 36.0), 54.0, 0.0, TAU, 48, accent, 3.0)

	if not alive:
		draw_rect(Rect2(origin + Vector2(-62.0, 12.0), Vector2(124.0, 24.0)), cloth)
		draw_rect(
			Rect2(origin + Vector2(-18.0, 11.0), Vector2(36.0, 26.0)),
			Color(0.42, 0.46, 0.5)
		)
		_draw_health_bar(origin, unit, accent)
		return

	draw_circle(origin + Vector2(-18.0, -30.0), 22.0, skin)
	draw_rect(
		Rect2(origin + Vector2(-30.0, -8.0), Vector2(60.0, 80.0)),
		cloth
	)
	draw_rect(
		Rect2(origin + Vector2(-38.0, 0.0), Vector2(20.0, 58.0)),
		accent.darkened(0.12)
	)
	draw_rect(
		Rect2(origin + Vector2(18.0, 0.0), Vector2(20.0, 58.0)),
		accent.darkened(0.12)
	)
	draw_rect(
		Rect2(origin + Vector2(-28.0, 68.0), Vector2(22.0, 42.0)),
		Color(0.12, 0.16, 0.2)
	)
	draw_rect(
		Rect2(origin + Vector2(6.0, 68.0), Vector2(22.0, 42.0)),
		Color(0.12, 0.16, 0.2)
	)

	if is_player:
		draw_line(
			origin + Vector2(28.0, 4.0),
			origin + Vector2(76.0, -70.0),
			metal,
			5.0
		)
		draw_line(
			origin + Vector2(22.0, 12.0),
			origin + Vector2(46.0, 2.0),
			Color(0.92, 0.68, 0.24),
			5.0
		)
	else:
		draw_line(
			origin + Vector2(28.0, 4.0),
			origin + Vector2(58.0, -76.0),
			Color(0.46, 0.38, 0.32),
			6.0
		)
		draw_circle(origin + Vector2(60.0, -78.0), 10.0, accent)

	_draw_health_bar(origin, unit, accent)


func _draw_health_bar(origin: Vector2, unit: BattleUnit, accent: Color) -> void:
	var width := 132.0
	var height := 12.0
	var top_left := origin + Vector2(-width * 0.5, 54.0)
	var ratio := clampf(unit.hp_ratio(), 0.0, 1.0)
	draw_rect(Rect2(top_left, Vector2(width, height)), Color(0.02, 0.03, 0.04, 0.92))
	draw_rect(
		Rect2(top_left + Vector2(2.0, 2.0), Vector2((width - 4.0) * ratio, height - 4.0)),
		_health_color(ratio)
	)
	draw_rect(Rect2(top_left, Vector2(width, height)), accent, false, 1.0)


func _health_color(ratio: float) -> Color:
	if ratio > 0.55:
		return HEALTH_HIGH
	if ratio > 0.25:
		return HEALTH_MEDIUM
	return HEALTH_LOW


func _ellipse_points(
	center: Vector2,
	radius: Vector2,
	segments: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(
			center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		)
	return points


func _panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.075, 0.94)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


func _flat_style(
	color: Color,
	border_color: Color,
	radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override(
		"normal",
		_flat_style(Color(0.045, 0.075, 0.1, 0.98), accent.darkened(0.18), 7)
	)
	button.add_theme_stylebox_override(
		"hover",
		_flat_style(Color(0.08, 0.14, 0.18, 1.0), accent.lightened(0.08), 7)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_flat_style(Color(0.12, 0.22, 0.28, 1.0), accent.lightened(0.18), 7)
	)
	button.add_theme_stylebox_override(
		"disabled",
		_flat_style(Color(0.04, 0.05, 0.06, 0.9), Color(0.22, 0.25, 0.28), 7)
	)
	button.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.42, 0.46, 0.5))
