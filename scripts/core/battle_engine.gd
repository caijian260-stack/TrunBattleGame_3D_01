class_name BattleEngine
extends RefCounted

## 回合制战斗引擎：以状态机驱动游戏流，状态使用枚举表示。
## 引擎只处理通用流程与通用资源，职业特有行为全部委托给 CharacterClass 子类。

signal state_changed(state: int)
signal log_emitted(text: String)
signal unit_changed(unit: BattleUnit)
signal battle_finished(player_won: bool)
signal battle_escaped
signal qte_started(task: BattleQTE)
signal qte_resolved(task: BattleQTE, grade: int)

enum State {
	IDLE,
	BATTLE_START,
	TURN_START,
	PLAYER_TURN,
	QTE,
	RESOLVING,
	ENEMY_TURN,
	TURN_END,
	BATTLE_END,
}

var player_units: Array[BattleUnit] = []
var enemy_units: Array[BattleUnit] = []

var current_state: int = State.IDLE
var round_number: int = 0
var active_actor: BattleUnit = null
var pending_actor: BattleUnit = null
var pending_command: StringName = &""
var pending_qte: BattleQTE = null
var pending_qte_grade: int = BattleQTE.Grade.SUCCESS
var escaped: bool = false


func setup_battle(player_setup: Array, enemy_setup: Array) -> void:
	player_units = _create_units(player_setup, true)
	enemy_units = _create_units(enemy_setup, false)
	round_number = 0
	escaped = false


func start() -> void:
	_transition(State.BATTLE_START)


func submit_player_command(command_id: StringName) -> bool:
	if current_state != State.PLAYER_TURN:
		return false
	if active_actor == null:
		return false
	if not active_actor.battle_class.can_use(command_id):
		push_log("当前无法使用该指令")
		return false
	if active_actor.battle_class.get_uses_action(command_id) and active_actor.at <= 0:
		push_log("%s不足，无法使用该指令。" % BattleAttribute.label(BattleAttribute.Type.AT))
		return false
	_begin_action(active_actor, command_id)
	return true


func end_player_turn() -> void:
	if current_state == State.PLAYER_TURN:
		_transition(State.ENEMY_TURN)


## 提交 QTE 结果。UI 在判定窗口内计算档位，超时则提交 FAILURE。
func resolve_qte(grade: int) -> bool:
	if current_state != State.QTE or pending_qte == null:
		return false
	if not BattleQTE.is_valid_grade(grade):
		return false
	pending_qte_grade = grade
	qte_resolved.emit(pending_qte, grade)
	_transition(State.RESOLVING)
	return true


## 玩家从当前战斗逃走。逃走成功后战斗以“逃走”结果结束，不触发胜负结算。
func escape_player() -> bool:
	if current_state != State.PLAYER_TURN or active_actor == null:
		return false
	escaped = true
	push_log("%s 成功逃走了。" % active_actor.unit_name)
	_transition(State.BATTLE_END)
	return true


## 以下为职业层可调用的通用战斗 API。
func deal_damage(
	source: BattleUnit,
	target: BattleUnit,
	base_amount: float,
	tags: Array = []
) -> int:
	var amount: float = base_amount
	amount = source.battle_class.modify_outgoing_damage(amount, target, tags)
	amount = target.battle_class.modify_incoming_damage(amount, source, tags)
	var dealt := maxi(0, roundi(amount))
	target.modify_hp(-dealt)
	source.battle_class.on_deal_damage(dealt, target)
	target.battle_class.on_take_damage(dealt, source)
	unit_changed.emit(source)
	unit_changed.emit(target)
	return dealt


func heal(target: BattleUnit, amount: int) -> int:
	if not target.battle_class.can_be_healed():
		return 0
	var healed := mini(amount, target.max_hp - target.hp)
	target.modify_hp(healed)
	unit_changed.emit(target)
	return healed


func gain_ap(unit: BattleUnit, amount: int) -> void:
	unit.add_ap(amount)
	unit_changed.emit(unit)


func gain_at(unit: BattleUnit, amount: int) -> void:
	unit.at = maxi(0, unit.at + amount)
	unit_changed.emit(unit)


func push_log(text: String) -> void:
	log_emitted.emit(text)


func get_opponents(unit: BattleUnit) -> Array[BattleUnit]:
	var side := enemy_units if unit.is_player else player_units
	return _alive(side)


func get_allies(unit: BattleUnit) -> Array[BattleUnit]:
	var side := player_units if unit.is_player else enemy_units
	var result: Array[BattleUnit] = []
	for candidate in side:
		if candidate != unit and candidate.hp > 0:
			result.append(candidate)
	return result


func _transition(next_state: int) -> void:
	current_state = next_state
	state_changed.emit(current_state)
	_enter_state(next_state)


func _enter_state(state: int) -> void:
	match state:
		State.BATTLE_START:
			_enter_battle_start()
		State.TURN_START:
			_enter_turn_start()
		State.PLAYER_TURN:
			_enter_player_turn()
		State.QTE:
			_enter_qte()
		State.RESOLVING:
			_enter_resolving()
		State.ENEMY_TURN:
			_enter_enemy_turn()
		State.TURN_END:
			_enter_turn_end()
		State.BATTLE_END:
			_enter_battle_end()


func _enter_battle_start() -> void:
	push_log("战斗开始")
	for unit in _all_units():
		unit.battle_class.on_battle_start(self)
	_transition(State.TURN_START)


func _enter_turn_start() -> void:
	round_number += 1
	push_log("—— 第 %d 回合 ——" % round_number)
	for unit in _all_units():
		unit.at = unit.max_at
		unit.add_ap(unit.ap_gain)
		unit.battle_class.on_turn_start(self)
		unit_changed.emit(unit)
	active_actor = _first_alive(player_units)
	if active_actor != null:
		_transition(State.PLAYER_TURN)
	else:
		_transition(State.TURN_END)


func _enter_player_turn() -> void:
	active_actor = _first_alive(player_units)
	if active_actor == null:
		_transition(State.TURN_END)


func _enter_qte() -> void:
	if pending_qte == null:
		_transition(State.RESOLVING)
		return
	qte_started.emit(pending_qte)


func _enter_resolving() -> void:
	var cost := pending_actor.battle_class.get_ap_cost(pending_command)
	var uses_action := pending_actor.battle_class.get_uses_action(pending_command)
	pending_actor.add_ap(-cost)
	if uses_action:
		pending_actor.at = maxi(0, pending_actor.at - 1)
	pending_actor.battle_class.resolve_command(
		pending_command,
		self,
		pending_qte_grade
	)
	pending_qte = null
	pending_qte_grade = BattleQTE.Grade.SUCCESS
	unit_changed.emit(pending_actor)
	_after_resolve()


func _after_resolve() -> void:
	if _check_battle_end():
		_transition(State.BATTLE_END)
		return
	if pending_actor.is_player:
		# 玩家回合由 UI 显式结束，保留额外动作技能（uses_action=false）的连续使用机会。
		_transition(State.PLAYER_TURN)
	else:
		_transition(State.ENEMY_TURN)


func _enter_enemy_turn() -> void:
	if _check_battle_end():
		_transition(State.BATTLE_END)
		return
	var enemy := _next_enemy_to_act()
	if enemy == null:
		_transition(State.TURN_END)
		return
	active_actor = enemy
	var command_id := enemy.battle_class.choose_ai_command(self)
	if command_id == &"":
		enemy.at = 0
		unit_changed.emit(enemy)
		_transition(State.ENEMY_TURN)
		return
	_begin_action(enemy, command_id)


func _begin_action(actor: BattleUnit, command_id: StringName) -> void:
	pending_actor = actor
	pending_command = command_id
	var task := actor.battle_class.build_qte_task(command_id, self)
	if task == null:
		pending_qte = null
		pending_qte_grade = BattleQTE.Grade.SUCCESS
		_transition(State.RESOLVING)
		return
	pending_qte = task
	pending_qte_grade = BattleQTE.Grade.SUCCESS
	_transition(State.QTE)


func _enter_turn_end() -> void:
	for unit in _all_units():
		unit.battle_class.on_turn_end(self)
	if _check_battle_end():
		_transition(State.BATTLE_END)
	else:
		_transition(State.TURN_START)


func _enter_battle_end() -> void:
	if escaped:
		push_log("战斗结束：成功逃走")
		battle_escaped.emit()
		return
	var player_won := _side_alive(player_units)
	push_log("战斗结束：" + ("胜利" if player_won else "失败"))
	battle_finished.emit(player_won)


func _check_battle_end() -> bool:
	return not _side_alive(player_units) or not _side_alive(enemy_units)


func _create_units(setups: Array, is_player: bool) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for setup in setups:
		var unit := BattleUnit.new()
		unit.setup(setup["name"], setup["max_hp"], setup["attack"], is_player, setup["class"])
		result.append(unit)
	return result


func _all_units() -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	result.append_array(player_units)
	result.append_array(enemy_units)
	return result


func _alive(units: Array[BattleUnit]) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit in units:
		if unit.hp > 0:
			result.append(unit)
	return result


func _side_alive(units: Array[BattleUnit]) -> bool:
	return _alive(units).size() > 0


func _first_alive(units: Array[BattleUnit]) -> BattleUnit:
	for unit in units:
		if unit.hp > 0:
			return unit
	return null


func _any_unit_can_act(units: Array[BattleUnit]) -> bool:
	for unit in units:
		if unit.hp > 0 and unit.at > 0:
			return true
	return false


func _next_enemy_to_act() -> BattleUnit:
	for unit in enemy_units:
		if unit.hp > 0 and unit.at > 0:
			return unit
	return null
