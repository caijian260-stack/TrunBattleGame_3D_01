class_name SwordCultivator
extends CharacterClass

## 剑修职业层：只负责剑势、剑意、留痕和技能效果。
## 引擎仍只通过 CharacterClass 契约调用本类，不会读取这些字段。

const BASIC_ATTACK := &"sword_basic_attack"
const CONDENSE_SWORD := &"sword_condense"
const COLD_LIGHT := &"sword_cold_light"
const CRUSH := &"sword_crush"
const SWORD_DOMAIN := &"sword_domain"
const RAINBOW := &"sword_rainbow"
const COSMIC_BLADE := &"sword_cosmic_blade"
const INFINITE_SLASH := &"sword_infinite_slash"
const SELFLESS_SWORD := &"sword_selfless"
const HEAVEN_OPENING := &"sword_heaven_opening"
const SWORD_CONTROL := &"sword_control"
const SWORD_QI := &"sword_qi"
const COUNTER_STRIKE := &"sword_counter"

var spiritual_sense: int = 25
var sword_force: int = 1
var sword_force_limit: int = 5
var sword_intent: int = 0
var sword_mark: int = 0
var selfless: bool = false
var selfless_used: bool = false
var selfless_guard_active: bool = false
var sword_domain_active: bool = false
var heaven_opening_used: bool = false


func setup() -> void:
	display_name = "剑修"
	_reset_battle_state()


func on_battle_start(_engine: BattleEngine) -> void:
	_reset_battle_state()


func on_turn_end(_engine: BattleEngine) -> void:
	sword_domain_active = false
	selfless_guard_active = false


func build_attack_command() -> BattleCommand:
	return _make_command(BASIC_ATTACK, "普攻", "0费攻击，获得1点AP和1点剑意。", BattleCommand.Group.BASIC)


func build_skill_commands() -> Array[BattleCommand]:
	return [
		_make_command(COLD_LIGHT, "寒光", "攻击并回复3点AP。", BattleCommand.Group.SKILL),
		_make_command(CRUSH, "摧城", "攻击并提升剑势。", BattleCommand.Group.SKILL),
		_make_command(INFINITE_SLASH, "无量连斩", "高伤攻击，剑势+2。", BattleCommand.Group.SKILL),
		_make_command(RAINBOW, "贯虹", "飞剑攻击，自身残血时提高伤害。", BattleCommand.Group.SKILL),
	]


func build_class_action_commands() -> Array[BattleCommand]:
	return [
		_make_command(SWORD_CONTROL, "御剑", "不消耗行动的飞剑攻击。", BattleCommand.Group.SPECIAL),
		_make_command(SWORD_QI, "剑气", "不消耗行动的剑气攻击，获得1点剑意。", BattleCommand.Group.SPECIAL),
	]


func build_ultimate_command() -> BattleCommand:
	return _make_command(HEAVEN_OPENING, "开天", "消耗全部留痕释放终击，每场一次。", BattleCommand.Group.ULTIMATE)


func build_counter_command() -> BattleCommand:
	return _make_command(
		COUNTER_STRIKE,
		"反击",
		"完美格挡反击时自动使用，不显示在行动菜单中。",
		BattleCommand.Group.SPECIAL
	)


func get_class_action_menu_name() -> String:
	return "御剑/剑气"


func get_ultimate_menu_name() -> String:
	return "开天"


func can_use(command_id: StringName) -> bool:
	return _requirement_error(command_id).is_empty()


func get_ap_cost(command_id: StringName) -> int:
	var base_cost := _base_ap_cost(command_id)
	if sword_domain_active and command_id in [SWORD_CONTROL, RAINBOW, COSMIC_BLADE]:
		return maxi(0, base_cost - 1)
	return base_cost


func get_uses_action(command_id: StringName) -> bool:
	return command_id not in [SWORD_CONTROL, SWORD_QI]


func resolve_command(
	command_id: StringName,
	engine: BattleEngine,
	qte_grade: int = BattleQTE.Grade.SUCCESS
) -> bool:
	match command_id:
		BASIC_ATTACK:
			_resolve_basic_attack(engine, qte_grade)
		COLD_LIGHT:
			_resolve_cold_light(engine, qte_grade)
		CRUSH:
			_resolve_crush(engine, qte_grade)
		INFINITE_SLASH:
			_resolve_infinite_slash(engine, qte_grade)
		CONDENSE_SWORD:
			_resolve_condense_sword(engine, qte_grade)
		SWORD_DOMAIN:
			_resolve_sword_domain(engine, qte_grade)
		SELFLESS_SWORD:
			_resolve_selfless_sword(engine, qte_grade)
		RAINBOW:
			_resolve_rainbow(engine, qte_grade)
		COSMIC_BLADE:
			_resolve_cosmic_blade(engine, qte_grade)
		HEAVEN_OPENING:
			_resolve_heaven_opening(engine, qte_grade)
		SWORD_CONTROL:
			_resolve_sword_control(engine, qte_grade)
		SWORD_QI:
			_resolve_sword_qi(engine, qte_grade)
		COUNTER_STRIKE:
			_resolve_counter_strike(engine)
		_:
			return false
	if command_triggers_qte(command_id):
		engine.push_log(
			"%s的%s判定为%s。"
			% [
				owner.unit_name,
				BattleQTE.task_label(BattleQTE.TaskType.EXECUTION),
				BattleQTE.grade_label(qte_grade),
			]
		)
	return true


func modify_outgoing_damage(amount: float, _target: BattleUnit, tags: Array) -> float:
	if sword_domain_active and tags.has("flying_sword"):
		return amount * 1.2
	return amount


func modify_incoming_damage(amount: float, _source: BattleUnit, _tags: Array) -> float:
	if selfless_guard_active and amount >= float(owner.hp):
		_trigger_selfless()
		return 0.0
	return amount


func on_take_damage(amount: int, _source: BattleUnit) -> void:
	if amount > 0:
		_add_sword_intent(1)


func can_be_healed() -> bool:
	return not selfless


func get_status_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append("神识 %d" % spiritual_sense)
	lines.append("剑势 %d / %d%s" % [sword_force, sword_force_limit, "（无我，按5档结算）" if selfless else ""])
	lines.append("剑意 %d / 40" % sword_intent)
	lines.append("留痕 %d" % sword_mark)
	if sword_domain_active:
		lines.append("无极剑域生效")
	if selfless_guard_active:
		lines.append("剑心无我待触发")
	return lines


func _make_command(
	id: StringName,
	display_name: String,
	description: String,
	group: int
) -> BattleCommand:
	var command := BattleCommand.new(
		id,
		display_name,
		description,
		get_ap_cost(id),
		get_uses_action(id),
		group
	)
	command.available = can_use(id)
	command.disabled_reason = _requirement_error(id)
	return command


func _requirement_error(command_id: StringName) -> String:
	if owner == null:
		return "单位尚未初始化"
	if owner.ap < get_ap_cost(command_id):
		return BattleAttribute.label(BattleAttribute.Type.AP) + "不足"

	match command_id:
		CONDENSE_SWORD:
			if selfless:
				return "无我状态下凝剑失效"
		SWORD_DOMAIN:
			if _effective_sword_force() < 5:
				return "需要剑势5"
		SELFLESS_SWORD:
			if _effective_sword_force() < 5:
				return "需要剑势5"
			if selfless_used:
				return "剑心无我每场仅可使用一次"
		RAINBOW, COSMIC_BLADE, SWORD_CONTROL:
			if _effective_sword_force() < 3:
				return "需要剑势至少3"
		HEAVEN_OPENING:
			if heaven_opening_used:
				return "开天每场仅可使用一次"
			if sword_intent < 20:
				return "需要剑意至少20"
	return ""


func _base_ap_cost(command_id: StringName) -> int:
	match command_id:
		BASIC_ATTACK:
			return 0
		COLD_LIGHT:
			return 1
		CONDENSE_SWORD, SWORD_CONTROL:
			return 2
		CRUSH, SWORD_QI:
			return 3
		RAINBOW:
			return 4
		SWORD_DOMAIN:
			return 5
		COSMIC_BLADE, SELFLESS_SWORD:
			return 6
		INFINITE_SLASH:
			return 7
		HEAVEN_OPENING:
			return 9
		COUNTER_STRIKE:
			return 0
	return 0


func _reset_battle_state() -> void:
	sword_force_limit = clampi(ceili(float(spiritual_sense) / 5.0), 1, 5)
	sword_force = 1
	sword_intent = 0
	sword_mark = 0
	selfless = false
	selfless_used = false
	selfless_guard_active = false
	sword_domain_active = false
	heaven_opening_used = false


func _effective_sword_force() -> int:
	return 5 if selfless else clampi(sword_force, 1, 5)


func _sword_force_multiplier() -> float:
	var force := _effective_sword_force()
	match force:
		1:
			return 1.0
		2:
			return 1.15
		3:
			return 1.3
		4:
			return 1.5
		5:
			return 2.0
	return 1.0


func _trace_value() -> int:
	var force := _effective_sword_force()
	match force:
		1:
			return 25
		2:
			return 100
		3:
			return 500
		4:
			return 2500
		5:
			return 10000
	return 0


func _sword_intent_multiplier() -> float:
	return 1.0 + 0.025 * float(mini(sword_intent, 40))


func _revelation_multiplier() -> float:
	if sword_intent >= 40:
		return 2.0
	if sword_intent >= 30:
		return 1.5
	if sword_intent >= 25:
		return 1.25
	return 1.0


func _deal_sword_damage(
	engine: BattleEngine,
	coefficient: float,
	tags: Array,
	extra_multiplier: float = 1.0,
	qte_grade: int = BattleQTE.Grade.SUCCESS
) -> bool:
	var targets := engine.get_opponents(owner)
	if targets.is_empty():
		return false
	var amount := float(owner.attack) * coefficient * _sword_force_multiplier()
	amount *= _sword_intent_multiplier() * extra_multiplier
	amount *= BattleQTE.player_effect_multiplier(qte_grade)
	engine.deal_damage(owner, targets[0], amount, tags)
	return true


func _resolve_basic_attack(engine: BattleEngine, qte_grade: int) -> void:
	_deal_sword_damage(engine, 1.0, ["sword_skill"], 1.0, qte_grade)
	_add_sword_intent(_qte_amount(1, qte_grade))
	engine.gain_ap(owner, 1)


func _resolve_cold_light(engine: BattleEngine, qte_grade: int) -> void:
	_deal_sword_damage(engine, 1.0, ["sword_skill"], 1.0, qte_grade)
	_add_sword_intent(_qte_amount(1, qte_grade))
	engine.gain_ap(owner, 3)


func _resolve_crush(engine: BattleEngine, qte_grade: int) -> void:
	_deal_sword_damage(engine, 1.4, ["sword_skill"], 1.0, qte_grade)
	_raise_sword_force(_qte_amount(1, qte_grade))
	_add_sword_intent(_qte_amount(1, qte_grade))


func _resolve_infinite_slash(engine: BattleEngine, qte_grade: int) -> void:
	_deal_sword_damage(engine, 2.4, ["sword_skill"], 1.0, qte_grade)
	_raise_sword_force(_qte_amount(2, qte_grade))
	_add_sword_intent(_qte_amount(1, qte_grade))


func _resolve_condense_sword(engine: BattleEngine, qte_grade: int) -> void:
	if selfless:
		return
	var force_gain := _qte_amount(1, qte_grade)
	if force_gain <= 0:
		engine.push_log("%s的凝剑受QTE失败影响，未能聚势。" % owner.unit_name)
		return
	_raise_sword_force(force_gain)
	engine.push_log("%s凝剑聚势。" % owner.unit_name)


func _resolve_sword_domain(engine: BattleEngine, qte_grade: int) -> void:
	if qte_grade == BattleQTE.Grade.FAILURE:
		engine.push_log("%s的剑域因QTE失败未能展开。" % owner.unit_name)
		return
	sword_domain_active = true
	engine.push_log("%s展开无极剑域。" % owner.unit_name)


func _resolve_selfless_sword(engine: BattleEngine, qte_grade: int) -> void:
	if qte_grade == BattleQTE.Grade.FAILURE:
		engine.push_log("%s的剑心无我因QTE失败未能成形。" % owner.unit_name)
		return
	selfless_used = true
	selfless_guard_active = true
	engine.push_log("%s进入剑心无我待发状态。" % owner.unit_name)


func _resolve_rainbow(engine: BattleEngine, qte_grade: int) -> void:
	_deal_sword_damage(
		engine,
		2.0,
		["flying_sword"],
		_rainbow_extra_multiplier(),
		qte_grade
	)
	_add_sword_mark()
	_consume_sword_force()


func _resolve_cosmic_blade(engine: BattleEngine, qte_grade: int) -> void:
	_deal_sword_damage(engine, 3.0, ["flying_sword"], 1.0, qte_grade)
	_add_sword_mark()
	_consume_sword_force()


func _resolve_sword_control(engine: BattleEngine, qte_grade: int) -> void:
	_deal_sword_damage(engine, 1.6, ["flying_sword"], 1.0, qte_grade)
	_add_sword_mark()
	_consume_sword_force()


func _resolve_sword_qi(engine: BattleEngine, qte_grade: int) -> void:
	_deal_sword_damage(engine, 1.2, ["sword_skill"], 1.0, qte_grade)
	_add_sword_intent(_qte_amount(1, qte_grade))


func _resolve_counter_strike(engine: BattleEngine) -> void:
	_deal_sword_damage(
		engine,
		1.4,
		["counter", "sword_skill"],
		1.0,
		BattleQTE.Grade.SUCCESS
	)
	engine.push_log("%s发动反击。" % owner.unit_name)


func _resolve_heaven_opening(engine: BattleEngine, qte_grade: int) -> void:
	heaven_opening_used = true
	_deal_sword_damage(
		engine,
		10.0,
		["ultimate"],
		_revelation_multiplier(),
		qte_grade
	)
	sword_mark = 0
	engine.push_log("%s释放开天，清空留痕。" % owner.unit_name)


func _raise_sword_force(amount: int) -> void:
	if selfless:
		return
	if sword_force < 3:
		sword_force = 3
	else:
		sword_force = mini(sword_force_limit, sword_force + amount)


func _consume_sword_force() -> void:
	if selfless or sword_domain_active:
		return
	sword_force = maxi(1, sword_force - 1)


func _add_sword_mark() -> void:
	sword_mark += _trace_value()


func _add_sword_intent(amount: int) -> void:
	sword_intent = mini(40, sword_intent + amount)


func _qte_amount(base_amount: int, qte_grade: int) -> int:
	match qte_grade:
		BattleQTE.Grade.FAILURE:
			return maxi(0, base_amount - 1)
		BattleQTE.Grade.PERFECT:
			return base_amount + 1
	return base_amount


func _rainbow_extra_multiplier() -> float:
	var ratio: float = owner.hp_ratio()
	if ratio <= 0.3:
		return 1.5
	return 1.0 + 0.5 * (1.0 - ratio) / 0.7


func _trigger_selfless() -> void:
	selfless = true
	selfless_guard_active = false
	owner.hp = 1
	owner.ap = owner.max_ap
