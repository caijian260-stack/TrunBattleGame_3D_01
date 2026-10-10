class_name EnemyClass
extends CharacterClass

## 敌人基类：后续敌人统一继承本类，并通过 QTE 任务类型描述攻击行为。

func get_qte_task_type(_command_id: StringName) -> int:
	return BattleQTE.TaskType.NONE


func build_qte_task(command_id: StringName, engine: BattleEngine) -> BattleQTE:
	var task_type := get_qte_task_type(command_id)
	if task_type == BattleQTE.TaskType.NONE:
		return null
	var targets := engine.get_opponents(owner)
	var target: BattleUnit = targets[0] if not targets.is_empty() else null
	if target == null:
		return null
	return BattleQTE.new_enemy_attack(
		task_type,
		command_id,
		get_command_display_name(command_id),
		owner,
		target
	)


func resolve_command(
	command_id: StringName,
	engine: BattleEngine,
	qte_grade: int = BattleQTE.Grade.SUCCESS
) -> bool:
	if not can_use(command_id):
		return false
	return resolve_enemy_attack(command_id, engine, qte_grade)


## 子类实现具体攻击，并在结算时调用 perform_enemy_attack()。
func resolve_enemy_attack(
	_command_id: StringName,
	_engine: BattleEngine,
	_qte_grade: int
) -> bool:
	return false


## 统一应用敌人 QTE 结果：成功免伤，完美免伤并获得 AP 奖励；
## 格挡反击的完美结果还会调用目标职业定义的反击技能。
func perform_enemy_attack(
	engine: BattleEngine,
	command_id: StringName,
	base_damage: float,
	tags: Array,
	qte_grade: int
) -> bool:
	var targets := engine.get_opponents(owner)
	if targets.is_empty():
		return false

	var target: BattleUnit = targets[0]
	var task_type := get_qte_task_type(command_id)
	var multiplier := BattleQTE.enemy_damage_multiplier(task_type, qte_grade)
	var dealt := 0
	if multiplier > 0.0:
		dealt = engine.deal_damage(owner, target, base_damage * multiplier, tags)

	if qte_grade == BattleQTE.Grade.PERFECT:
		if task_type == BattleQTE.TaskType.BLOCK_COUNTER:
			target.battle_class.use_counter_skill(engine, owner)
		else:
			engine.push_log(
				"%s%s，未受到伤害。" % [
					target.unit_name,
					BattleQTE.result_label(task_type, qte_grade),
				]
			)
		engine.gain_ap(target, 1)
		engine.push_log(
			"%s获得1点%s。"
			% [
				target.unit_name,
				BattleAttribute.label(BattleAttribute.Type.AP),
			]
		)
	elif qte_grade == BattleQTE.Grade.SUCCESS:
		engine.push_log(
			"%s%s，未受到伤害。"
			% [target.unit_name, BattleQTE.result_label(task_type, qte_grade)]
		)
	elif dealt > 0:
		engine.push_log(
			"%s在%s判定后受到%d点伤害。"
			% [
				target.unit_name,
				BattleQTE.result_label(task_type, qte_grade),
				dealt,
			]
		)
	return true
