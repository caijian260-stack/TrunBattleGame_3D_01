class_name BattleMenu
extends RefCounted

## 行动菜单的选项与视图统一在此管理。
## UI 只引用这里的枚举和默认标签，不在界面脚本中硬编码中文菜单名。

enum Option {
	SKILLS,
	CLASS_SPECIAL,
	ATTACK,
	ULTIMATE,
	ESCAPE,
}

const DEFAULT_LABELS := {
	Option.SKILLS: "技能",
	Option.CLASS_SPECIAL: "职业特殊行动",
	Option.ATTACK: "攻击",
	Option.ULTIMATE: "神通",
	Option.ESCAPE: "逃走",
}

enum View {
	MAIN,
	SKILLS,
	CLASS_SPECIAL,
}

const MAIN_OPTION_ID_PREFIX := "main_option_"


static func option_label(option: int) -> String:
	return DEFAULT_LABELS.get(option, "")


## 主菜单枚举与 UI 控件之间使用稳定 ID 通信，避免 UI 依赖枚举数值。
static func main_option_id(option: int) -> StringName:
	return StringName(MAIN_OPTION_ID_PREFIX + str(option))
