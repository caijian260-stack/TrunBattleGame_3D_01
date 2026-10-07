class_name BattleCommand
extends RefCounted

## 一条战斗指令的静态描述。是否可用由所属职业在构建菜单时计算并填入。
## 引擎只读取 ap_cost 与 uses_action 做通用结算，不理解任何职业技能细节。

enum Group {
	BASIC,
	SKILL,
	ULTIMATE,
	SPECIAL,
}

var id: StringName = &""
var display_name: String = ""
var description: String = ""
var ap_cost: int = 0
var uses_action: bool = true
var group: int = Group.SKILL
var available: bool = true
var disabled_reason: String = ""


func _init(
	p_id: StringName = &"",
	p_name: String = "",
	p_desc: String = "",
	p_ap: int = 0,
	p_uses_action: bool = true,
	p_group: int = Group.SKILL
) -> void:
	id = p_id
	display_name = p_name
	description = p_desc
	ap_cost = p_ap
	uses_action = p_uses_action
	group = p_group
