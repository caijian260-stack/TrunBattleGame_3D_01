class_name BattleAttribute
extends RefCounted

## 通用战斗属性标识。显示名称统一从这里读取，后续改名不需要修改战斗逻辑。

enum Type {
	HP,
	AP,
	AT,
	ATTACK,
}

const DEFAULT_LABELS := {
	Type.HP: "HP",
	Type.AP: "AP",
	Type.AT: "行动力",
	Type.ATTACK: "攻击力",
}


static func label(attribute: int) -> String:
	return str(DEFAULT_LABELS.get(attribute, "属性"))
