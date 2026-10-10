class_name CharacterClass
extends RefCounted

## 职业层基类：所有职业都从这里继承。引擎只通过这份契约与职业交互，
## 因此引擎完全不知道剑势、留痕等具体机制，新增职业只需继承并覆写钩子。

var owner: BattleUnit = null
var display_name: String = ""


func setup() -> void:
	pass


func get_display_name() -> String:
	return display_name


func on_battle_start(engine: BattleEngine) -> void:
	pass


func on_turn_start(engine: BattleEngine) -> void:
	pass


func on_turn_end(engine: BattleEngine) -> void:
	pass


## 构建本职业在“攻击”按钮中使用的普通攻击。
func build_attack_command() -> BattleCommand:
	return null


## 构建角色当前装配的技能，UI 会以技能栏形式展示。
func build_skill_commands() -> Array[BattleCommand]:
	return []


## 构建角色当前装配的神通。未装配时返回 null，由 UI 显示默认“神通”。
func build_ultimate_command() -> BattleCommand:
	return null


## 构建职业反击技能。反击技不进入任何菜单，只由完美格挡反击触发。
func build_counter_command() -> BattleCommand:
	return null


## 构建职业独立控制菜单，UI 不解释这些指令的内容，只负责展示并回传 id。
func build_class_action_commands() -> Array[BattleCommand]:
	return []


## 职业独立控制菜单在主页面的显示名，子类按职业特性覆写。
func get_class_action_menu_name() -> String:
	return BattleMenu.option_label(BattleMenu.Option.CLASS_SPECIAL)


## 神通按钮的显示名；未装配神通时使用默认标签“神通”。
func get_ultimate_menu_name() -> String:
	return BattleMenu.option_label(BattleMenu.Option.ULTIMATE)


## 兼容旧接口：返回主页面可提交的全部指令（攻击 + 技能 + 神通）。
func build_commands() -> Array[BattleCommand]:
	var commands: Array[BattleCommand] = []
	var attack := build_attack_command()
	if attack != null:
		commands.append(attack)
	commands.append_array(build_skill_commands())
	var ultimate := build_ultimate_command()
	if ultimate != null:
		commands.append(ultimate)
	return commands


## 职业独立控制菜单。引擎与 UI 不解释这些指令的内容，只负责展示并回传 id。
func build_special_commands() -> Array[BattleCommand]:
	return build_class_action_commands()


func can_use(command_id: StringName) -> bool:
	return false


## 返回指令的显示名。UI 与 QTE 任务都从职业提供的指令构建结果中读取名称。
func get_command_display_name(command_id: StringName) -> String:
	for command in build_commands():
		if command != null and command.id == command_id:
			return command.display_name
	for command in build_special_commands():
		if command != null and command.id == command_id:
			return command.display_name
	return str(command_id)


## 查询指令分组。未列入常规菜单的职业内部技能默认按 SKILL 处理。
func get_command_group(command_id: StringName) -> int:
	for command in build_commands():
		if command != null and command.id == command_id:
			return command.group
	for command in build_special_commands():
		if command != null and command.id == command_id:
			return command.group
	return BattleCommand.Group.SKILL


## 玩家仅技能和神通触发 QTE；普通攻击、职业特殊行动和反击技不触发。
func command_triggers_qte(command_id: StringName) -> bool:
	var counter_command := build_counter_command()
	if counter_command != null and counter_command.id == command_id:
		return false
	var group := get_command_group(command_id)
	return group == BattleCommand.Group.SKILL or group == BattleCommand.Group.ULTIMATE


## 构建本职业对应的 QTE 任务。
## 玩家职业默认执行“行动判定”；敌人继承 EnemyClass 后覆写为闪避、格挡或反击任务。
func build_qte_task(command_id: StringName, engine: BattleEngine) -> BattleQTE:
	if owner == null or not owner.is_player:
		return null
	if not command_triggers_qte(command_id):
		return null
	var targets := engine.get_opponents(owner)
	var target: BattleUnit = targets[0] if not targets.is_empty() else null
	return BattleQTE.new_player_action(
		command_id,
		get_command_display_name(command_id),
		owner,
		target
	)


## 使用职业反击技能。默认实现调用子类提供的隐藏反击指令。
func use_counter_skill(engine: BattleEngine, attacker: BattleUnit) -> bool:
	var command := build_counter_command()
	if command == null:
		return false
	return resolve_command(command.id, engine, BattleQTE.Grade.PERFECT)


## 执行职业特有效果。通用 AP/AT 消耗已由引擎在调用前扣除。
func resolve_command(
	command_id: StringName,
	engine: BattleEngine,
	qte_grade: int = BattleQTE.Grade.SUCCESS
) -> bool:
	return false


func get_ap_cost(command_id: StringName) -> int:
	return 0


func get_uses_action(command_id: StringName) -> bool:
	return true


## AI 选择指令。默认取第一条可用指令，玩家职业通常不会走到这里。
func choose_ai_command(engine: BattleEngine) -> StringName:
	var commands: Array[BattleCommand] = build_commands()
	commands.append_array(build_special_commands())
	for command in commands:
		if command.available and can_use(command.id):
			return command.id
	return &""


func modify_outgoing_damage(amount: float, target: BattleUnit, tags: Array) -> float:
	return amount


func modify_incoming_damage(amount: float, source: BattleUnit, tags: Array) -> float:
	return amount


func on_deal_damage(amount: int, target: BattleUnit) -> void:
	pass


func on_take_damage(amount: int, source: BattleUnit) -> void:
	pass


func can_be_healed() -> bool:
	return true


func get_status_lines() -> Array[String]:
	return []
