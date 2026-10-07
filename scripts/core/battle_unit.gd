class_name BattleUnit
extends RefCounted

## 通用战斗单位，只承载引擎关心的通用资源，不含任何职业技能细节。
## 职业特有资源与行为统一放在 battle_class（CharacterClass 子类）中。

var unit_name: String = ""
var max_hp: int = 100
var hp: int = 100
var attack: int = 10
var ap: int = 0
var max_ap: int = 9
var at: int = 1
var max_at: int = 1
var ap_gain: int = 1
var is_player: bool = false
var battle_class: CharacterClass = null


func setup(
	p_name: String,
	p_max_hp: int,
	p_attack: int,
	p_is_player: bool,
	p_class: CharacterClass
) -> void:
	unit_name = p_name
	max_hp = p_max_hp
	hp = p_max_hp
	attack = p_attack
	is_player = p_is_player
	battle_class = p_class
	battle_class.owner = self
	battle_class.setup()


func hp_ratio() -> float:
	return float(hp) / float(max_hp)


func modify_hp(delta: int) -> int:
	var before := hp
	hp = clampi(hp + delta, 0, max_hp)
	return hp - before


func add_ap(delta: int) -> void:
	ap = clampi(ap + delta, 0, max_ap)
