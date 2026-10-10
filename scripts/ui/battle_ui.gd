extends Node3D

## 3D 战斗场景控制层：负责战场表现、HUD 与战斗引擎之间的连接。
## 行动内容仍完全由 CharacterClass 子类提供，场景不会判断玩家正在使用哪个职业。

const BattleEngineScript := preload("res://scripts/core/battle_engine.gd")
const BattleQTEScript := preload("res://scripts/core/battle_qte.gd")
const SwordCultivatorScript := preload("res://scripts/classes/sword_cultivator.gd")
const TrainingDummyScript := preload("res://scripts/classes/training_dummy.gd")
const BattleMenuScript := preload("res://scripts/core/battle_menu.gd")
const BattleUnitVisualScript := preload("res://scripts/ui/battle_unit_visual_3d.gd")
const BattleRadialMenuScript := preload("res://scripts/ui/battle_radial_menu.gd")

const PLAYER_WORLD_POSITION := Vector3(-4.6, 0.0, 2.8)
const ENEMY_WORLD_POSITION := Vector3(4.5, 0.0, -2.55)
const PLAYER_ACCENT := Color(0.2, 0.78, 1.0)
const ENEMY_ACCENT := Color(1.0, 0.32, 0.24)

var engine: BattleEngine
var player_unit: BattleUnit
var enemy_unit: BattleUnit

var current_view: int = BattleMenuScript.View.MAIN
var _radial_menu
var _camera: Camera3D
var _player_visual
var _enemy_visual

var _player_status: Label
var _enemy_status: Label
var _turn_label: Label
var _result_label: Label
var _result_hint: Label
var _result_panel: PanelContainer
var _return_scene_button: Button
var _log_label: RichTextLabel
var _end_turn_button: Button
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
var _encounter_data: Dictionary = {}


func _ready() -> void:
	_load_encounter_context()
	_build_world()
	_build_hud()
	_setup_battle()


func _process(delta: float) -> void:
	if _radial_menu != null and _radial_menu.visible:
		_update_radial_menu_position()
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


func _build_world() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.012, 0.022, 0.038)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.28, 0.4, 0.52)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	key_light.light_color = Color(0.82, 0.9, 1.0)
	key_light.light_energy = 1.15
	key_light.shadow_enabled = true
	add_child(key_light)

	var player_fill := OmniLight3D.new()
	player_fill.name = "PlayerFill"
	player_fill.position = Vector3(-4.5, 4.2, 3.5)
	player_fill.light_color = Color(0.35, 0.72, 1.0)
	player_fill.light_energy = 3.2
	player_fill.omni_range = 10.5
	add_child(player_fill)

	var enemy_fill := OmniLight3D.new()
	enemy_fill.name = "EnemyFill"
	enemy_fill.position = Vector3(4.8, 3.8, -2.8)
	enemy_fill.light_color = Color(1.0, 0.28, 0.18)
	enemy_fill.light_energy = 2.6
	enemy_fill.omni_range = 9.0
	add_child(enemy_fill)

	_build_arena()

	_camera = Camera3D.new()
	_camera.name = "BattleCamera"
	_camera.position = Vector3(0.0, 8.8, 13.6)
	_camera.fov = 42.0
	_camera.current = true
	add_child(_camera)
	_camera.look_at(Vector3(0.0, 0.85, 0.0), Vector3.UP)


func _build_arena() -> void:
	var floor_material := _make_material(Color(0.085, 0.12, 0.16), 0.9, 0.05)
	var surface_material := _make_material(Color(0.12, 0.18, 0.23), 0.82, 0.08)
	var line_material := _make_material(
		Color(0.16, 0.42, 0.55),
		0.55,
		0.15,
		Color(0.05, 0.2, 0.28)
	)

	var base := _add_cylinder("ArenaBase", 7.35, 0.30, floor_material)
	base.position.y = -0.16

	var surface := _add_cylinder("ArenaSurface", 6.98, 0.055, surface_material)
	surface.position.y = 0.005

	var outer_line := _add_torus("ArenaOuterLine", 6.45, 6.58, line_material)
	outer_line.position.y = 0.045

	var inner_line := _add_torus("ArenaInnerLine", 2.5, 2.58, line_material)
	inner_line.position.y = 0.045

	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var marker := _add_box("ArenaMarker", Vector3(0.8, 0.055, 0.16), line_material)
		marker.position = Vector3(sin(angle) * 5.72, 0.05, cos(angle) * 5.72)
		marker.rotation.y = -angle


func _build_hud() -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "BattleHUD"
	canvas_layer.layer = 10
	add_child(canvas_layer)

	var hud_root := Control.new()
	hud_root.name = "HUDRoot"
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(hud_root)

	_turn_label = Label.new()
	_turn_label.name = "TurnLabel"
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_label.anchor_left = 0.5
	_turn_label.anchor_right = 0.5
	_turn_label.offset_left = -220.0
	_turn_label.offset_right = 220.0
	_turn_label.offset_top = 18.0
	_turn_label.offset_bottom = 58.0
	_turn_label.add_theme_font_size_override("font_size", 22)
	_turn_label.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0))
	_turn_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	_turn_label.add_theme_constant_override("shadow_offset_x", 1)
	_turn_label.add_theme_constant_override("shadow_offset_y", 2)
	hud_root.add_child(_turn_label)

	_player_status = _create_status_panel(
		hud_root,
		"玩家单位",
		PLAYER_ACCENT,
		false
	)
	_enemy_status = _create_status_panel(
		hud_root,
		"敌方单位",
		ENEMY_ACCENT,
		true
	)

	_create_control_log_panel(hud_root)
	_create_result_panel(hud_root)
	_create_qte_panel(hud_root)

	_radial_menu = BattleRadialMenuScript.new()
	_radial_menu.name = "RadialActionMenu"
	_radial_menu.entry_selected.connect(_on_radial_entry_selected)
	_radial_menu.back_requested.connect(_on_back_requested)
	canvas_layer.add_child(_radial_menu)
	_radial_menu.visible = false


func _create_status_panel(
	parent: Control,
	title: String,
	accent: Color,
	align_right: bool
) -> Label:
	var panel := PanelContainer.new()
	panel.name = "EnemyStatus" if align_right else "PlayerStatus"
	panel.anchor_left = 1.0 if align_right else 0.0
	panel.anchor_right = 1.0 if align_right else 0.0
	panel.offset_left = -354.0 if align_right else 18.0
	panel.offset_right = -18.0 if align_right else 354.0
	panel.offset_top = 18.0
	panel.offset_bottom = 178.0
	panel.add_theme_stylebox_override("panel", _panel_style(accent))
	parent.add_child(panel)

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
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", accent.lightened(0.2))
	content.add_child(heading)

	var status := Label.new()
	status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 15)
	status.add_theme_color_override("font_color", Color(0.9, 0.94, 0.97))
	content.add_child(status)
	return status


func _create_control_log_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "ControlLogPanel"
	panel.anchor_left = 1.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -414.0
	panel.offset_top = -246.0
	panel.offset_right = -18.0
	panel.offset_bottom = -18.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.28, 0.56, 0.68)))
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	content.add_child(button_row)

	_end_turn_button = Button.new()
	_end_turn_button.text = "结束回合"
	_end_turn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_style_command_button(_end_turn_button, Color(0.18, 0.52, 0.74))
	button_row.add_child(_end_turn_button)

	var restart_button := Button.new()
	restart_button.text = "重新开始"
	restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_button.pressed.connect(_on_restart_pressed)
	_style_command_button(restart_button, Color(0.4, 0.46, 0.55))
	button_row.add_child(restart_button)

	var log_heading := Label.new()
	log_heading.text = "战斗记录"
	log_heading.add_theme_font_size_override("font_size", 15)
	log_heading.add_theme_color_override("font_color", Color(0.64, 0.8, 0.9))
	content.add_child(log_heading)

	_log_label = RichTextLabel.new()
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.custom_minimum_size = Vector2(0.0, 138.0)
	_log_label.scroll_following = true
	_log_label.add_theme_font_size_override("normal_font_size", 14)
	_log_label.add_theme_color_override("default_color", Color(0.86, 0.9, 0.94))
	_log_label.add_theme_stylebox_override(
		"normal",
		_flat_style(Color(0.025, 0.04, 0.06, 0.82), Color(0.2, 0.34, 0.42, 0.8), 8)
	)
	content.add_child(_log_label)


func _create_result_panel(parent: Control) -> void:
	_result_panel = PanelContainer.new()
	_result_panel.name = "ResultPanel"
	_result_panel.anchor_left = 0.5
	_result_panel.anchor_top = 0.5
	_result_panel.anchor_right = 0.5
	_result_panel.anchor_bottom = 0.5
	_result_panel.offset_left = -210.0
	_result_panel.offset_top = -72.0
	_result_panel.offset_right = 210.0
	_result_panel.offset_bottom = 72.0
	_result_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.35, 0.68, 0.85)))
	parent.add_child(_result_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_result_panel.add_child(margin)

	var result_content := VBoxContainer.new()
	result_content.alignment = BoxContainer.ALIGNMENT_CENTER
	result_content.add_theme_constant_override("separation", 8)
	margin.add_child(result_content)

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 24)
	_result_label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	result_content.add_child(_result_label)

	_result_hint = Label.new()
	_result_hint.text = "战斗结束后可返回场景"
	_result_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_hint.add_theme_font_size_override("font_size", 14)
	_result_hint.add_theme_color_override("font_color", Color(0.62, 0.74, 0.82))
	result_content.add_child(_result_hint)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 10)
	result_content.add_child(action_row)

	_return_scene_button = Button.new()
	_return_scene_button.text = "返回场景"
	_return_scene_button.custom_minimum_size = Vector2(124.0, 38.0)
	_return_scene_button.pressed.connect(_on_return_scene_pressed)
	_style_command_button(_return_scene_button, Color(0.24, 0.62, 0.78))
	action_row.add_child(_return_scene_button)

	var restart_button := Button.new()
	restart_button.text = "重新开始"
	restart_button.custom_minimum_size = Vector2(124.0, 38.0)
	restart_button.pressed.connect(_on_restart_pressed)
	_style_command_button(restart_button, Color(0.4, 0.46, 0.55))
	action_row.add_child(restart_button)

	_refresh_result_actions()
	_result_panel.visible = false


func _create_qte_panel(parent: Control) -> void:
	_qte_panel = PanelContainer.new()
	_qte_panel.name = "QTEPanel"
	_qte_panel.anchor_left = 0.5
	_qte_panel.anchor_top = 1.0
	_qte_panel.anchor_right = 0.5
	_qte_panel.anchor_bottom = 1.0
	_qte_panel.offset_left = -318.0
	_qte_panel.offset_top = -188.0
	_qte_panel.offset_right = 318.0
	_qte_panel.offset_bottom = -24.0
	_qte_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.92, 0.68, 0.22))
	)
	parent.add_child(_qte_panel)

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


func _load_encounter_context() -> void:
	var scene_flow := _get_scene_flow()
	if scene_flow == null:
		return
	_encounter_data = scene_flow.encounter_data.duplicate(true)


func _get_scene_flow() -> Node:
	return get_node_or_null("/root/SceneFlow")


func _setup_battle() -> void:
	engine = BattleEngineScript.new()

	var sword_class := SwordCultivatorScript.new()
	sword_class.spiritual_sense = 25
	var dummy_class := TrainingDummyScript.new()
	var player_name := str(_encounter_data.get("player_name", "剑修"))
	var enemy_name := str(_encounter_data.get("enemy_name", "训练假人"))
	var enemy_max_hp := int(_encounter_data.get("enemy_max_hp", 260))
	var enemy_attack := int(_encounter_data.get("enemy_attack", 14))

	engine.state_changed.connect(_on_state_changed)
	engine.log_emitted.connect(_on_log_emitted)
	engine.unit_changed.connect(_on_unit_changed)
	engine.battle_finished.connect(_on_battle_finished)
	engine.battle_escaped.connect(_on_battle_escaped)
	engine.qte_started.connect(_on_qte_started)
	engine.qte_resolved.connect(_on_qte_resolved)

	engine.setup_battle(
		[{"name": player_name, "max_hp": 180, "attack": 20, "class": sword_class}],
		[{
			"name": enemy_name,
			"max_hp": enemy_max_hp,
			"attack": enemy_attack,
			"class": dummy_class,
		}]
	)
	player_unit = engine.player_units[0]
	enemy_unit = engine.enemy_units[0]

	_player_visual = BattleUnitVisualScript.new()
	_player_visual.name = "PlayerUnit"
	_player_visual.position = PLAYER_WORLD_POSITION
	_player_visual.use_custom_hero_model = true
	_player_visual.setup(player_unit, PLAYER_ACCENT, BattleUnitVisualScript.VisualStyle.HERO)
	add_child(_player_visual)
	_player_visual.look_at(ENEMY_WORLD_POSITION, Vector3.UP)

	_enemy_visual = BattleUnitVisualScript.new()
	_enemy_visual.name = "EnemyUnit"
	_enemy_visual.position = ENEMY_WORLD_POSITION
	_enemy_visual.setup(enemy_unit, ENEMY_ACCENT, BattleUnitVisualScript.VisualStyle.CONSTRUCT)
	add_child(_enemy_visual)
	_enemy_visual.look_at(PLAYER_WORLD_POSITION, Vector3.UP)

	current_view = BattleMenuScript.View.MAIN
	engine.start()
	_refresh_ui()


func _refresh_ui() -> void:
	if player_unit == null or enemy_unit == null or engine == null:
		return

	_player_status.text = _format_status(player_unit)
	_enemy_status.text = _format_status(enemy_unit)
	_turn_label.text = _turn_text()

	_player_visual.refresh()
	_enemy_visual.refresh()
	_player_visual.set_active(
		engine.current_state == BattleEngineScript.State.PLAYER_TURN
		or (
			(
				engine.current_state == BattleEngineScript.State.QTE
				or engine.current_state == BattleEngineScript.State.RESOLVING
			)
			and engine.active_actor != null
			and engine.active_actor.is_player
		)
	)
	_enemy_visual.set_active(
		engine.current_state == BattleEngineScript.State.ENEMY_TURN
		or (
			(
				engine.current_state == BattleEngineScript.State.QTE
				or engine.current_state == BattleEngineScript.State.RESOLVING
			)
			and engine.active_actor != null
			and not engine.active_actor.is_player
		)
	)

	_end_turn_button.disabled = engine.current_state != BattleEngineScript.State.PLAYER_TURN
	_refresh_action_menu()


func _refresh_action_menu() -> void:
	var is_player_turn := engine.current_state == BattleEngineScript.State.PLAYER_TURN
	var actor := engine.active_actor if is_player_turn else null
	if not is_player_turn or actor == null:
		_radial_menu.visible = false
		current_view = BattleMenuScript.View.MAIN
		return

	_radial_menu.visible = true
	match current_view:
		BattleMenuScript.View.MAIN:
			_configure_main_menu(actor)
		BattleMenuScript.View.SKILLS:
			_configure_command_menu(
				actor,
				actor.battle_class.build_skill_commands(),
				true
			)
		BattleMenuScript.View.CLASS_SPECIAL:
			_configure_command_menu(
				actor,
				actor.battle_class.build_class_action_commands(),
				true
			)
	_update_radial_menu_position()


func _configure_main_menu(actor: BattleUnit) -> void:
	var skill_commands := actor.battle_class.build_skill_commands()
	var special_commands := actor.battle_class.build_class_action_commands()
	var attack_command := actor.battle_class.build_attack_command()
	var ultimate_command := actor.battle_class.build_ultimate_command()

	var entries: Array[Dictionary] = []
	entries.append(
		_main_entry(
			actor,
			BattleMenuScript.Option.SKILLS,
			BattleMenuScript.option_label(BattleMenuScript.Option.SKILLS),
			null,
			not skill_commands.is_empty()
		)
	)
	entries.append(
		_main_entry(
			actor,
			BattleMenuScript.Option.CLASS_SPECIAL,
			actor.battle_class.get_class_action_menu_name(),
			null,
			not special_commands.is_empty()
		)
	)
	entries.append(
		_main_entry(
			actor,
			BattleMenuScript.Option.ATTACK,
			BattleMenuScript.option_label(BattleMenuScript.Option.ATTACK),
			attack_command
		)
	)
	entries.append(
		_main_entry(
			actor,
			BattleMenuScript.Option.ULTIMATE,
			actor.battle_class.get_ultimate_menu_name(),
			ultimate_command,
			ultimate_command != null
		)
	)
	entries.append(
		_main_entry(
			actor,
			BattleMenuScript.Option.ESCAPE,
			BattleMenuScript.option_label(BattleMenuScript.Option.ESCAPE),
			null,
			true
		)
	)
	_radial_menu.configure(entries, false)


func _main_entry(
	actor: BattleUnit,
	option: int,
	text: String,
	command: BattleCommand = null,
	available_override: bool = true
) -> Dictionary:
	var available := available_override
	var tooltip := ""
	if command != null:
		available = available and _is_command_available_for_actor(actor, command)
		tooltip = _command_tooltip(actor, command)
	elif not available:
		tooltip = "当前没有可用的行动"

	return {
		"id": BattleMenuScript.main_option_id(option),
		"text": text,
		"detail": "",
		"available": available,
		"tooltip": tooltip,
	}


func _configure_command_menu(
	actor: BattleUnit,
	commands: Array[BattleCommand],
	allow_back: bool
) -> void:
	var entries: Array[Dictionary] = []
	for command in commands:
		entries.append({
			"id": command.id,
			"text": command.display_name,
			"detail": "%d %s" % [
				command.ap_cost,
				BattleAttribute.label(BattleAttribute.Type.AP),
			],
			"available": _is_command_available_for_actor(actor, command),
			"tooltip": _command_tooltip(actor, command),
		})
	_radial_menu.configure(entries, allow_back)


func _is_command_available_for_actor(actor: BattleUnit, command: BattleCommand) -> bool:
	if actor == null or command == null or not command.available:
		return false
	if command.uses_action and actor.at <= 0:
		return false
	return true


func _command_tooltip(actor: BattleUnit, command: BattleCommand) -> String:
	var tooltip := command.description
	if not command.disabled_reason.is_empty():
		tooltip += "\n不可用：" + command.disabled_reason
	elif command.uses_action and actor != null and actor.at <= 0:
		tooltip += "\n不可用：" + BattleAttribute.label(BattleAttribute.Type.AT) + "不足"
	return tooltip


func _update_radial_menu_position() -> void:
	if _camera == null or _player_visual == null or _radial_menu == null:
		return
	var anchor: Vector2 = _camera.unproject_position(
		_player_visual.global_position + Vector3(0.0, 1.35, 0.0)
	)
	var viewport_size := get_viewport().get_visible_rect().size
	var desired_center := anchor + Vector2(_radial_menu.size.x * 0.62, -8.0)
	var desired: Vector2 = desired_center - _radial_menu.size * 0.5
	_radial_menu.set_position_clamped(desired, viewport_size)


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


func _on_radial_entry_selected(entry_id: StringName) -> void:
	if current_view == BattleMenuScript.View.MAIN:
		for option in [
			BattleMenuScript.Option.SKILLS,
			BattleMenuScript.Option.CLASS_SPECIAL,
			BattleMenuScript.Option.ATTACK,
			BattleMenuScript.Option.ULTIMATE,
			BattleMenuScript.Option.ESCAPE,
		]:
			if entry_id == BattleMenuScript.main_option_id(option):
				_on_main_option_pressed(option)
				return
		return

	engine.submit_player_command(entry_id)
	_refresh_ui()


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


## 判定条上的成功区/完美区宽度直接来自任务配置，避免视觉与判定规则不一致。
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


func _on_qte_resolved(task: BattleQTE, grade: int) -> void:
	_qte_result.text = "结果：" + task.get_result_label(grade)
	var result_color := Color(0.72, 0.8, 0.86)
	match grade:
		BattleQTEScript.Grade.FAILURE:
			result_color = Color(1.0, 0.42, 0.36)
		BattleQTEScript.Grade.SUCCESS:
			result_color = Color(0.4, 0.86, 1.0)
		BattleQTEScript.Grade.PERFECT:
			result_color = Color(1.0, 0.82, 0.3)
	_qte_result.add_theme_color_override("font_color", result_color)
	_qte_hide_at = Time.get_ticks_msec() / 1000.0 + 0.75


func _finish_qte(grade: int) -> void:
	if not _qte_active or _qte_task == null or engine == null:
		return
	_qte_active = false
	_set_qte_progress(_qte_progress())
	engine.resolve_qte(grade)


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


func _on_main_option_pressed(option: int) -> void:
	if engine == null or engine.current_state != BattleEngineScript.State.PLAYER_TURN:
		return
	var actor := engine.active_actor
	if actor == null:
		return

	match option:
		BattleMenuScript.Option.SKILLS:
			current_view = BattleMenuScript.View.SKILLS
		BattleMenuScript.Option.CLASS_SPECIAL:
			current_view = BattleMenuScript.View.CLASS_SPECIAL
		BattleMenuScript.Option.ATTACK:
			var attack := actor.battle_class.build_attack_command()
			if attack != null:
				engine.submit_player_command(attack.id)
		BattleMenuScript.Option.ULTIMATE:
			var ultimate := actor.battle_class.build_ultimate_command()
			if ultimate != null:
				engine.submit_player_command(ultimate.id)
		BattleMenuScript.Option.ESCAPE:
			engine.escape_player()

	_refresh_ui()


func _on_back_requested() -> void:
	current_view = BattleMenuScript.View.MAIN
	_refresh_ui()


func _on_end_turn_pressed() -> void:
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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(scene_path)


func _refresh_result_actions() -> void:
	var scene_flow := _get_scene_flow()
	var can_return: bool = (
		scene_flow != null
		and bool(scene_flow.has_battle_return())
	)
	if _return_scene_button != null:
		_return_scene_button.visible = can_return
	if _result_hint != null:
		_result_hint.text = (
			"选择返回场景或重新开始"
			if can_return
			else "点击重新开始再战"
		)


func _on_state_changed(state: int) -> void:
	if state != BattleEngineScript.State.PLAYER_TURN:
		current_view = BattleMenuScript.View.MAIN
	_refresh_ui()


func _on_unit_changed(_unit: BattleUnit) -> void:
	_refresh_ui()


func _on_battle_finished(player_won: bool) -> void:
	_result_label.text = "战斗结束：" + ("胜利" if player_won else "失败")
	_refresh_result_actions()
	_result_panel.visible = true
	_refresh_ui()


func _on_battle_escaped() -> void:
	_result_label.text = "战斗结束：成功逃走"
	_refresh_result_actions()
	_result_panel.visible = true
	_refresh_ui()


func _on_log_emitted(text: String) -> void:
	_log_label.append_text(text + "\n")


func _add_cylinder(
	node_name: String,
	radius: float,
	height: float,
	material: StandardMaterial3D
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)
	return instance


func _add_torus(
	node_name: String,
	inner_radius: float,
	outer_radius: float,
	material: StandardMaterial3D
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)
	return instance


func _add_box(
	node_name: String,
	size: Vector3,
	material: StandardMaterial3D
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)
	return instance


func _make_material(
	color: Color,
	roughness: float = 0.75,
	metallic: float = 0.1,
	emission: Color = Color(0.0, 0.0, 0.0, 0.0)
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.emission_enabled = emission.a > 0.0
	material.emission = emission
	material.emission_energy_multiplier = 1.25
	return material


func _panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.07, 0.92)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 8
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
	return style


func _style_command_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override(
		"normal",
		_flat_style(accent.darkened(0.58), Color(accent.r, accent.g, accent.b, 0.72), 7)
	)
	button.add_theme_stylebox_override(
		"hover",
		_flat_style(accent.darkened(0.38), Color(accent.r, accent.g, accent.b, 0.9), 7)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_flat_style(accent.darkened(0.22), Color.WHITE, 7)
	)
	button.add_theme_stylebox_override(
		"disabled",
		_flat_style(Color(0.1, 0.12, 0.15), Color(0.26, 0.3, 0.34), 7)
	)
	button.add_theme_color_override("font_color", Color(0.9, 0.95, 0.98))
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.5, 0.55))
