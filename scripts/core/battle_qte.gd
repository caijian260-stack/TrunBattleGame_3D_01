class_name BattleQTE
extends RefCounted

## QTE 的通用定义与判定规则。任务名称、结果名称和时序参数都集中在这里。

enum TaskType {
	NONE,
	EXECUTION,
	DODGE_A,
	DODGE_B,
	BLOCK_COUNTER,
}

enum Grade {
	FAILURE = 1,
	SUCCESS = 2,
	PERFECT = 3,
}

enum Source {
	PLAYER_ACTION,
	ENEMY_ATTACK,
}

const TASK_LABELS := {
	TaskType.NONE: "无",
	TaskType.EXECUTION: "行动判定",
	TaskType.DODGE_A: "闪避A",
	TaskType.DODGE_B: "闪避B",
	TaskType.BLOCK_COUNTER: "格挡反击",
}

const GRADE_LABELS := {
	Grade.FAILURE: "失败",
	Grade.SUCCESS: "成功",
	Grade.PERFECT: "完美",
}

const TASK_GRADE_LABELS := {
	TaskType.DODGE_A: {
		Grade.FAILURE: "闪避失败",
		Grade.SUCCESS: "闪避成功",
		Grade.PERFECT: "完美闪避",
	},
	TaskType.DODGE_B: {
		Grade.FAILURE: "闪避失败",
		Grade.SUCCESS: "闪避成功",
		Grade.PERFECT: "完美闪避",
	},
	TaskType.BLOCK_COUNTER: {
		Grade.FAILURE: "格挡失败",
		Grade.SUCCESS: "格挡成功",
		Grade.PERFECT: "反击成功",
	},
}

const TASK_PROFILES := {
	TaskType.EXECUTION: {
		"duration": 3.0,
		"perfect_window": 0.055,
		"success_window": 0.16,
	},
	TaskType.DODGE_A: {
		"duration": 2.6,
		"perfect_window": 0.045,
		"success_window": 0.14,
	},
	TaskType.DODGE_B: {
		"duration": 2.4,
		"perfect_window": 0.04,
		"success_window": 0.13,
	},
	TaskType.BLOCK_COUNTER: {
		"duration": 2.9,
		"perfect_window": 0.06,
		"success_window": 0.18,
	},
}

var task_type: int = TaskType.NONE
var source: int = Source.PLAYER_ACTION
var command_id: StringName = &""
var command_name: String = ""
var actor: BattleUnit = null
var target: BattleUnit = null
var duration: float = 3.0
var perfect_window: float = 0.055
var success_window: float = 0.16


static func new_player_action(
	p_command_id: StringName,
	p_command_name: String,
	p_actor: BattleUnit,
	p_target: BattleUnit
) -> BattleQTE:
	var task := BattleQTE.new()
	task._configure(
		TaskType.EXECUTION,
		Source.PLAYER_ACTION,
		p_command_id,
		p_command_name,
		p_actor,
		p_target
	)
	return task


static func new_enemy_attack(
	p_task_type: int,
	p_command_id: StringName,
	p_command_name: String,
	p_enemy: BattleUnit,
	p_player: BattleUnit
) -> BattleQTE:
	var task := BattleQTE.new()
	task._configure(
		p_task_type,
		Source.ENEMY_ATTACK,
		p_command_id,
		p_command_name,
		p_enemy,
		p_player
	)
	return task


static func task_label(task_type_value: int) -> String:
	return str(TASK_LABELS.get(task_type_value, "QTE"))


static func grade_label(grade: int) -> String:
	return str(GRADE_LABELS.get(grade, "未知"))


static func result_label(task_type_value: int, grade: int) -> String:
	var labels: Dictionary = TASK_GRADE_LABELS.get(task_type_value, {})
	return str(labels.get(grade, grade_label(grade)))


static func is_valid_grade(grade: int) -> bool:
	return grade >= Grade.FAILURE and grade <= Grade.PERFECT


static func evaluate_progress(
	progress: float,
	p_perfect_window: float,
	p_success_window: float
) -> int:
	var distance := absf(progress - 0.5)
	if distance <= p_perfect_window:
		return Grade.PERFECT
	if distance <= p_success_window:
		return Grade.SUCCESS
	return Grade.FAILURE


static func player_effect_multiplier(grade: int) -> float:
	match grade:
		Grade.FAILURE:
			return 0.65
		Grade.PERFECT:
			return 1.4
	return 1.0


static func enemy_damage_multiplier(task_type_value: int, grade: int) -> float:
	if grade != Grade.FAILURE:
		return 0.0
	return 1.0


func get_title() -> String:
	if source == Source.ENEMY_ATTACK:
		return "敌方" + task_label(task_type)
	return task_label(task_type)


func get_instruction() -> String:
	if source == Source.ENEMY_ATTACK:
		return "在攻击命中前点击鼠标或按空格完成%s" % task_label(task_type)
	return "在指针进入判定区时点击鼠标或按空格"


func get_input_hint() -> String:
	return "鼠标左键 / 空格"


func get_result_label(grade: int) -> String:
	if source == Source.ENEMY_ATTACK:
		return result_label(task_type, grade)
	return grade_label(grade)


func evaluate(progress: float) -> int:
	return evaluate_progress(progress, perfect_window, success_window)


func _configure(
	p_task_type: int,
	p_source: int,
	p_command_id: StringName,
	p_command_name: String,
	p_actor: BattleUnit,
	p_target: BattleUnit
) -> void:
	task_type = p_task_type
	source = p_source
	command_id = p_command_id
	command_name = p_command_name
	actor = p_actor
	target = p_target

	var profile: Dictionary = TASK_PROFILES.get(task_type, TASK_PROFILES[TaskType.EXECUTION])
	duration = float(profile["duration"])
	perfect_window = float(profile["perfect_window"])
	success_window = float(profile["success_window"])
