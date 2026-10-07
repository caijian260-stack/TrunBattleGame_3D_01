extends SceneTree

## 无界面自动化测试：用 headless Godot 验证状态机与剑修职业解耦。

const BattleEngineScript := preload("res://scripts/core/battle_engine.gd")
const BattleQTEScript := preload("res://scripts/core/battle_qte.gd")
const CharacterClassScript := preload("res://scripts/classes/character_class.gd")
const SwordCultivatorScript := preload("res://scripts/classes/sword_cultivator.gd")
const TrainingDummyScript := preload("res://scripts/classes/training_dummy.gd")

var failures := 0


func _init() -> void:
	_run()


func _run() -> void:
	_test_player_and_enemy_turn()
	_test_zero_action_points_blocks_action_commands()
	_test_domain_and_special_menu()
	_test_selfless_guard()
	_test_player_command_qte_policy()
	_test_player_action_qte_grades()
	_test_enemy_qte_types_and_resolution()
	_test_menu_structure()
	_test_escape()

	if failures == 0:
		print("BATTLE TESTS PASSED")
		quit(0)
	else:
		print("BATTLE TESTS FAILED: %d" % failures)
		quit(1)


func _make_engine() -> Dictionary:
	var engine = BattleEngineScript.new()
	var sword_class := SwordCultivatorScript.new()
	sword_class.spiritual_sense = 25
	var dummy_class := TrainingDummyScript.new()
	engine.setup_battle(
		[{"name": "剑修", "max_hp": 180, "attack": 20, "class": sword_class}],
		[{"name": "训练假人", "max_hp": 260, "attack": 14, "class": dummy_class}]
	)
	return {
		"engine": engine,
		"player": engine.player_units[0],
		"enemy": engine.enemy_units[0],
		"sword": sword_class,
		"dummy": dummy_class,
	}


func _test_player_and_enemy_turn() -> void:
	var setup := _make_engine()
	var engine = setup["engine"]
	var player = setup["player"]
	var enemy = setup["enemy"]
	var sword = setup["sword"]
	var enemy_hp_before: int = enemy.hp
	var player_turn_actors: Array[BattleUnit] = []
	engine.state_changed.connect(
		func(state: int) -> void:
			if state == BattleEngineScript.State.PLAYER_TURN:
				player_turn_actors.append(engine.active_actor)
	)

	engine.start()
	_check(engine.current_state == BattleEngineScript.State.PLAYER_TURN, "战斗应从玩家回合开始")
	_check(
		player_turn_actors.size() == 1 and player_turn_actors[0] == player,
		"进入玩家回合时active_actor应已切换为玩家"
	)

	_check(
		_submit_command(engine, SwordCultivatorScript.BASIC_ATTACK),
		"普攻应可提交并直接完成结算"
	)
	_check(enemy.hp < enemy_hp_before, "普攻应造成伤害")
	_check(engine.current_state == BattleEngineScript.State.PLAYER_TURN, "普攻不应触发QTE")
	_check(player.at == 0, "普攻应消耗行动次数")
	_check(player.ap == 2, "普攻应净回复1点AP")
	_check(sword.sword_intent == 1, "普攻应获得1点剑意")

	var player_turn_count_before_enemy := player_turn_actors.size()
	engine.end_player_turn()
	_check(engine.current_state == BattleEngineScript.State.QTE, "敌方攻击应下发QTE")
	_check(
		engine.resolve_qte(BattleQTEScript.Grade.SUCCESS),
		"玩家应可提交敌方攻击QTE结果"
	)
	_check(engine.current_state == BattleEngineScript.State.PLAYER_TURN, "敌方回合结束后应回到玩家回合")
	_check(
		player_turn_actors.size() == player_turn_count_before_enemy + 1
		and player_turn_actors[player_turn_actors.size() - 1] == player,
		"敌方回合结束后的玩家回合信号应携带玩家单位"
	)
	_check(player.hp == player.max_hp, "成功应对敌方QTE应完全免伤")
	_check(player.ap == 3, "新回合开始时应回复1点AP")


func _test_domain_and_special_menu() -> void:
	var setup := _make_engine()
	var engine = setup["engine"]
	var player = setup["player"]
	var enemy = setup["enemy"]
	var sword = setup["sword"]
	var enemy_hp_before: int = enemy.hp

	engine.start()
	engine.gain_ap(player, 7)
	sword.sword_force = 5

	_check(
		_submit_command(engine, SwordCultivatorScript.SWORD_DOMAIN),
		"无极剑域应可提交并完成QTE"
	)
	_check(sword.sword_domain_active, "无极剑域应生效")
	_check(player.ap == 3, "无极剑域应消耗5点AP")

	_check(
		_submit_command(engine, SwordCultivatorScript.SWORD_CONTROL),
		"独立菜单中的御剑应可提交并直接完成结算"
	)
	_check(enemy.hp < enemy_hp_before, "御剑应造成伤害")
	_check(player.at == 0, "御剑不应消耗行动次数")
	_check(player.ap == 2, "域内御剑应只消耗1点AP")
	_check(sword.sword_force == 5, "域内御剑不应消耗剑势")


func _test_zero_action_points_blocks_action_commands() -> void:
	var setup := _make_engine()
	var engine = setup["engine"]
	var player = setup["player"]
	var enemy = setup["enemy"]
	var sword = setup["sword"]

	engine.start()
	player.at = 0
	engine.gain_ap(player, 7)
	sword.sword_force = 3
	var ap_before: int = player.ap
	var enemy_hp_before: int = enemy.hp

	_check(
		not engine.submit_player_command(SwordCultivatorScript.COLD_LIGHT),
		"行动力为0时不应允许使用消耗行动力的技能"
	)
	_check(engine.current_state == BattleEngineScript.State.PLAYER_TURN, "被拒绝的技能不应进入QTE")
	_check(player.at == 0, "被拒绝的技能不应消耗行动力")
	_check(player.ap == ap_before, "被拒绝的技能不应消耗AP")
	_check(enemy.hp == enemy_hp_before, "被拒绝的技能不应造成伤害")

	_check(
		_submit_command(engine, SwordCultivatorScript.SWORD_CONTROL),
		"行动力为0时仍应允许使用不消耗行动力的御剑"
	)
	_check(player.at == 0, "御剑不应消耗行动力")
	_check(enemy.hp < enemy_hp_before, "行动力为0时御剑仍应造成伤害")


func _test_selfless_guard() -> void:
	var setup := _make_engine()
	var engine = setup["engine"]
	var player = setup["player"]
	var enemy = setup["enemy"]
	var sword = setup["sword"]

	engine.start()
	engine.gain_ap(player, 7)
	sword.sword_force = 5

	_check(
		_submit_command(engine, SwordCultivatorScript.SELFLESS_SWORD),
		"剑心无我应可提交并完成QTE"
	)
	_check(sword.selfless_guard_active, "剑心无我应进入待触发状态")
	engine.deal_damage(enemy, player, 999.0)
	_check(player.hp == 1, "剑心无我应将濒死伤害转为1HP")
	_check(player.ap == player.max_ap, "剑心无我应回满AP")
	_check(sword.selfless, "剑心无我应进入无我状态")
	_check(not sword.can_be_healed(), "无我状态下应禁止治疗")


func _test_player_command_qte_policy() -> void:
	var basic_setup := _make_engine()
	var basic_engine = basic_setup["engine"]
	var basic_enemy = basic_setup["enemy"]
	var basic_enemy_hp_before: int = basic_enemy.hp
	basic_engine.start()
	_check(
		_submit_command(basic_engine, SwordCultivatorScript.BASIC_ATTACK),
		"普攻应可直接提交"
	)
	_check(
		basic_engine.current_state == BattleEngineScript.State.PLAYER_TURN
		and basic_engine.pending_qte == null,
		"普攻不应进入QTE状态"
	)
	_check(basic_enemy.hp < basic_enemy_hp_before, "不触发QTE的普攻仍应正常结算")

	var special_setup := _make_engine()
	var special_engine = special_setup["engine"]
	var special_player = special_setup["player"]
	var special_enemy = special_setup["enemy"]
	var special_sword = special_setup["sword"]
	var special_enemy_hp_before: int = special_enemy.hp
	special_engine.start()
	special_engine.gain_ap(special_player, 7)
	special_sword.sword_force = 3
	_check(
		_submit_command(special_engine, SwordCultivatorScript.SWORD_CONTROL),
		"职业特殊行动应可直接提交"
	)
	_check(
		special_engine.current_state == BattleEngineScript.State.PLAYER_TURN
		and special_engine.pending_qte == null,
		"职业特殊行动不应进入QTE状态"
	)
	_check(special_enemy.hp < special_enemy_hp_before, "职业特殊行动仍应正常结算")

	var skill_setup := _make_engine()
	var skill_engine = skill_setup["engine"]
	skill_engine.start()
	_check(
		skill_engine.submit_player_command(SwordCultivatorScript.COLD_LIGHT),
		"技能应可提交"
	)
	_check(
		skill_engine.current_state == BattleEngineScript.State.QTE
		and skill_engine.pending_qte != null
		and skill_engine.pending_qte.task_type == BattleQTEScript.TaskType.EXECUTION,
		"技能应进入行动判定QTE"
	)
	_check(
		skill_engine.resolve_qte(BattleQTEScript.Grade.SUCCESS),
		"技能行动QTE应可结算"
	)

	var ultimate_setup := _make_engine()
	var ultimate_engine = ultimate_setup["engine"]
	var ultimate_player = ultimate_setup["player"]
	var ultimate_sword = ultimate_setup["sword"]
	ultimate_engine.start()
	ultimate_engine.gain_ap(ultimate_player, 8)
	ultimate_sword.sword_intent = 20
	_check(
		ultimate_engine.submit_player_command(SwordCultivatorScript.HEAVEN_OPENING),
		"神通应可提交"
	)
	_check(
		ultimate_engine.current_state == BattleEngineScript.State.QTE
		and ultimate_engine.pending_qte != null
		and ultimate_engine.pending_qte.task_type == BattleQTEScript.TaskType.EXECUTION,
		"神通应进入行动判定QTE"
	)
	_check(
		ultimate_engine.resolve_qte(BattleQTEScript.Grade.SUCCESS),
		"神通行动QTE应可结算"
	)

	var menu_setup := _make_engine()
	var menu_sword = menu_setup["sword"]
	_check(
		not menu_sword.command_triggers_qte(SwordCultivatorScript.BASIC_ATTACK),
		"普攻不应触发QTE"
	)
	_check(
		not menu_sword.command_triggers_qte(SwordCultivatorScript.SWORD_CONTROL),
		"职业特殊行动不应触发QTE"
	)
	_check(
		menu_sword.command_triggers_qte(SwordCultivatorScript.COLD_LIGHT),
		"技能应触发QTE"
	)
	_check(
		menu_sword.command_triggers_qte(SwordCultivatorScript.HEAVEN_OPENING),
		"神通应触发QTE"
	)
	_check(
		not menu_sword.command_triggers_qte(SwordCultivatorScript.COUNTER_STRIKE),
		"隐藏反击技不应触发QTE"
	)
	_check(
		not _commands_contain(
			menu_sword.build_skill_commands(),
			SwordCultivatorScript.COUNTER_STRIKE
		)
		and not _commands_contain(
			menu_sword.build_class_action_commands(),
			SwordCultivatorScript.COUNTER_STRIKE
		)
		and not _commands_contain(
			menu_sword.build_commands(),
			SwordCultivatorScript.COUNTER_STRIKE
		),
		"反击技不应出现在任何行动菜单"
	)


func _test_player_action_qte_grades() -> void:
	var failure_setup := _make_engine()
	var success_setup := _make_engine()
	var perfect_setup := _make_engine()

	_start_and_submit(
		failure_setup,
		SwordCultivatorScript.COLD_LIGHT,
		BattleQTEScript.Grade.FAILURE
	)
	_start_and_submit(
		success_setup,
		SwordCultivatorScript.COLD_LIGHT,
		BattleQTEScript.Grade.SUCCESS
	)
	_start_and_submit(
		perfect_setup,
		SwordCultivatorScript.COLD_LIGHT,
		BattleQTEScript.Grade.PERFECT
	)

	var failure_damage: int = failure_setup["enemy"].max_hp - failure_setup["enemy"].hp
	var success_damage: int = success_setup["enemy"].max_hp - success_setup["enemy"].hp
	var perfect_damage: int = perfect_setup["enemy"].max_hp - perfect_setup["enemy"].hp
	_check(failure_damage < success_damage, "行动QTE失败应降低技能效果")
	_check(success_damage < perfect_damage, "行动QTE完美应提高技能效果")
	_check(failure_setup["player"].ap == 2, "技能QTE失败应获得较低AP收益")
	_check(success_setup["player"].ap == 3, "技能QTE成功应获得正常AP收益")
	_check(perfect_setup["player"].ap == 4, "技能QTE完美应获得额外AP")


func _test_enemy_qte_types_and_resolution() -> void:
	var mapping_setup := _make_engine()
	var dummy = mapping_setup["dummy"]
	_check(
		dummy.get_qte_task_type(TrainingDummyScript.DODGE_ATTACK)
		== BattleQTEScript.TaskType.DODGE_A,
		"扫击应下发闪避A QTE"
	)
	_check(
		dummy.get_qte_task_type(TrainingDummyScript.BLOCK_ATTACK)
		== BattleQTEScript.TaskType.DODGE_B,
		"重压应下发闪避B QTE"
	)
	_check(
		dummy.get_qte_task_type(TrainingDummyScript.COUNTER_ATTACK)
		== BattleQTEScript.TaskType.BLOCK_COUNTER,
		"突进应下发格挡反击QTE"
	)

	var dodge_a_failure := _run_enemy_attack(
		TrainingDummyScript.DODGE_ATTACK,
		BattleQTEScript.Grade.FAILURE,
		BattleQTEScript.TaskType.DODGE_A,
		"闪避A失败"
	)
	_check(
		dodge_a_failure["player"].hp < dodge_a_failure["player"].max_hp,
		"闪避A失败应受到伤害"
	)
	_check(
		dodge_a_failure["player"].ap == 1,
		"闪避A失败不应获得AP奖励"
	)

	var dodge_a_perfect := _run_enemy_attack(
		TrainingDummyScript.DODGE_ATTACK,
		BattleQTEScript.Grade.PERFECT,
		BattleQTEScript.TaskType.DODGE_A,
		"完美闪避A"
	)
	_check(
		dodge_a_perfect["player"].hp == dodge_a_perfect["player"].max_hp,
		"完美闪避A应免伤"
	)
	_check(dodge_a_perfect["player"].ap == 2, "完美闪避A应额外获得1点AP")
	_check(
		dodge_a_perfect["enemy"].hp == dodge_a_perfect["enemy"].max_hp,
		"完美闪避A不应触发反击"
	)

	var dodge_b_success := _run_enemy_attack(
		TrainingDummyScript.BLOCK_ATTACK,
		BattleQTEScript.Grade.SUCCESS,
		BattleQTEScript.TaskType.DODGE_B,
		"闪避B成功"
	)
	_check(
		dodge_b_success["player"].hp == dodge_b_success["player"].max_hp,
		"闪避B成功应免伤"
	)
	_check(dodge_b_success["player"].ap == 1, "闪避B成功不应获得额外AP")

	var counter_success := _run_enemy_attack(
		TrainingDummyScript.COUNTER_ATTACK,
		BattleQTEScript.Grade.SUCCESS,
		BattleQTEScript.TaskType.BLOCK_COUNTER,
		"格挡成功"
	)
	_check(
		counter_success["player"].hp == counter_success["player"].max_hp,
		"格挡成功应免伤"
	)
	_check(
		counter_success["enemy"].hp == counter_success["enemy"].max_hp,
		"格挡成功不应触发反击"
	)

	var counter_perfect := _run_enemy_attack(
		TrainingDummyScript.COUNTER_ATTACK,
		BattleQTEScript.Grade.PERFECT,
		BattleQTEScript.TaskType.BLOCK_COUNTER,
		"反击成功"
	)
	_check(
		counter_perfect["player"].hp == counter_perfect["player"].max_hp,
		"反击成功应先免除敌方伤害"
	)
	_check(counter_perfect["player"].ap == 2, "反击成功应额外获得1点AP")
	_check(
		counter_perfect["enemy"].hp < counter_perfect["enemy"].max_hp,
		"反击成功应使用职业隐藏反击技攻击敌人"
	)
	_check(
		counter_perfect["engine"].current_state
		== BattleEngineScript.State.PLAYER_TURN,
		"敌人QTE结算后应回到玩家回合"
	)


func _test_menu_structure() -> void:
	var setup := _make_engine()
	var sword = setup["sword"]
	var base_class := CharacterClassScript.new()

	_check(base_class.get_class_action_menu_name() == "职业特殊行动", "未覆写职业行动名时应使用默认枚举标签")
	_check(base_class.get_ultimate_menu_name() == "神通", "未装配神通时应使用默认神通标签")
	_check(sword.build_attack_command() != null, "剑修应提供独立攻击指令")
	_check(sword.build_skill_commands().size() == 4, "剑修技能栏应装配4个技能")
	_check(sword.build_class_action_commands().size() == 2, "剑修职业特殊行动应有2个选项")
	_check(sword.build_ultimate_command() != null, "剑修应提供已装配神通")
	_check(sword.get_class_action_menu_name() == "御剑/剑气", "剑修职业特殊行动菜单名应为御剑/剑气")
	_check(sword.get_ultimate_menu_name() == "开天", "剑修神通按钮应显示开天")


func _test_escape() -> void:
	var setup := _make_engine()
	var engine = setup["engine"]

	engine.start()
	_check(engine.current_state == BattleEngineScript.State.PLAYER_TURN, "逃走测试应从玩家回合开始")
	_check(engine.escape_player(), "玩家回合应允许逃走")
	_check(engine.escaped, "逃走成功后应标记为已逃走")
	_check(engine.current_state == BattleEngineScript.State.BATTLE_END, "逃走成功后战斗应结束")


func _run_enemy_attack(
	command_id: StringName,
	grade: int,
	expected_task_type: int,
	label: String
) -> Dictionary:
	var setup := _make_engine()
	var engine = setup["engine"]
	var player = setup["player"]
	var dummy = setup["dummy"]

	engine.start()
	dummy.attack_index = _training_dummy_attack_index(command_id)
	# 隔离回合开始的固定 AP 回复，单独验证QTE奖励。
	player.ap_gain = 0
	engine.end_player_turn()
	_check(engine.current_state == BattleEngineScript.State.QTE, label + "应进入QTE状态")
	_check(
		engine.pending_qte != null
		and engine.pending_qte.task_type == expected_task_type,
		label + "应下发正确类型的QTE"
	)
	_check(engine.resolve_qte(grade), label + "应可提交判定结果")
	return setup


func _training_dummy_attack_index(command_id: StringName) -> int:
	match command_id:
		TrainingDummyScript.BLOCK_ATTACK:
			return 1
		TrainingDummyScript.COUNTER_ATTACK:
			return 2
	return 0


func _commands_contain(
	commands: Array[BattleCommand],
	command_id: StringName
) -> bool:
	for command in commands:
		if command != null and command.id == command_id:
			return true
	return false


func _start_and_submit(
	setup: Dictionary,
	command_id: StringName,
	grade: int
) -> void:
	var engine = setup["engine"]
	engine.start()
	_submit_command(engine, command_id, grade)


func _submit_command(
	engine,
	command_id: StringName,
	grade: int = BattleQTEScript.Grade.SUCCESS
) -> bool:
	if not engine.submit_player_command(command_id):
		return false
	if engine.current_state == BattleEngineScript.State.QTE:
		return engine.resolve_qte(grade)
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)
