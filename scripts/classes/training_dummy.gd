class_name TrainingDummy
extends EnemyClass

## 训练假人：循环使用三种带 QTE 的敌方攻击，用来验证敌人基类和应对流程。

const DODGE_ATTACK := &"dummy_dodge_attack"
const BLOCK_ATTACK := &"dummy_block_attack"
const COUNTER_ATTACK := &"dummy_counter_attack"

var attack_index := 0


func setup() -> void:
	display_name = "训练假人"


func build_attack_command() -> BattleCommand:
	return _make_attack_command(DODGE_ATTACK)


func build_commands() -> Array[BattleCommand]:
	return [
		_make_attack_command(DODGE_ATTACK),
		_make_attack_command(BLOCK_ATTACK),
		_make_attack_command(COUNTER_ATTACK),
	]


func can_use(command_id: StringName) -> bool:
	return command_id in [DODGE_ATTACK, BLOCK_ATTACK, COUNTER_ATTACK] and owner != null


func get_ap_cost(_command_id: StringName) -> int:
	return 0


func get_qte_task_type(command_id: StringName) -> int:
	match command_id:
		DODGE_ATTACK:
			return BattleQTE.TaskType.DODGE_A
		BLOCK_ATTACK:
			return BattleQTE.TaskType.DODGE_B
		COUNTER_ATTACK:
			return BattleQTE.TaskType.BLOCK_COUNTER
	return BattleQTE.TaskType.NONE


## 敌人 AI 循环三种攻击；若要接入更复杂的行为树，只需覆写此方法。
func choose_ai_command(_engine: BattleEngine) -> StringName:
	var commands := build_commands()
	if commands.is_empty():
		return &""
	var command := commands[attack_index % commands.size()]
	attack_index += 1
	return command.id


func resolve_enemy_attack(
	command_id: StringName,
	engine: BattleEngine,
	qte_grade: int
) -> bool:
	match command_id:
		DODGE_ATTACK:
			return perform_enemy_attack(
				engine,
				command_id,
				float(owner.attack) * 1.0,
				["enemy_attack", "dodge_a"],
				qte_grade
			)
		BLOCK_ATTACK:
			return perform_enemy_attack(
				engine,
				command_id,
				float(owner.attack) * 1.15,
				["enemy_attack", "dodge_b"],
				qte_grade
			)
		COUNTER_ATTACK:
			return perform_enemy_attack(
				engine,
				command_id,
				float(owner.attack) * 1.3,
				["enemy_attack", "block_counter"],
				qte_grade
			)
	return false


func _make_attack_command(command_id: StringName) -> BattleCommand:
	match command_id:
		DODGE_ATTACK:
			return BattleCommand.new(
				command_id,
				"扫击",
				"攻击玩家并下发闪避A QTE。",
				0,
				true,
				BattleCommand.Group.BASIC
			)
		BLOCK_ATTACK:
			return BattleCommand.new(
				command_id,
				"重压",
				"攻击玩家并下发闪避B QTE。",
				0,
				true,
				BattleCommand.Group.BASIC
			)
		COUNTER_ATTACK:
			return BattleCommand.new(
				command_id,
				"突进",
				"攻击玩家并下发格挡反击 QTE。",
				0,
				true,
				BattleCommand.Group.BASIC
			)
	return null
