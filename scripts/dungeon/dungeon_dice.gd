class_name DungeonDice
extends RefCounted

## 秘境掷骰。
##
## 骰子以「颗数 × 面数 + 加值」描述，统一用于生成移动力，也可以复用到
## 其它需要随机点数的环节。投掷时随机数发生器由外部注入，方便测试复现
## 与存档还原。

enum Face {
	D4 = 4,
	D6 = 6,
	D8 = 8,
	D10 = 10,
	D12 = 12,
	D20 = 20,
}

const FACE_LABELS: Dictionary = {
	Face.D4: "D4",
	Face.D6: "D6",
	Face.D8: "D8",
	Face.D10: "D10",
	Face.D12: "D12",
	Face.D20: "D20",
}

## 骰子颗数，至少 1 颗。
var dice_count: int = 1
## 骰子面数，取值来自 Face 枚举。
var face: int = Face.D6
## 固定加值，可为负数。
var bonus: int = 0
## 最近一次投掷的明细分值，供 UI 展示与存档使用。
var last_rolls: Array[int] = []


func _init(
	count: int = 1,
	dice_face: int = Face.D6,
	modifier: int = 0
) -> void:
	dice_count = maxi(count, 1)
	face = maxi(dice_face, 2)
	bonus = modifier


## 秘境默认使用的移动力骰子：1D6。
static func movement_dice() -> DungeonDice:
	return DungeonDice.new(1, Face.D6, 0)


func min_total() -> int:
	return dice_count + bonus


func max_total() -> int:
	return dice_count * face + bonus


## 投掷一次，返回总点数，并在 last_rolls 中记录每一颗骰子的明细。
func roll(rng: RandomNumberGenerator = null) -> int:
	var generator := rng
	if generator == null:
		generator = RandomNumberGenerator.new()
		generator.randomize()
	last_rolls.clear()
	var total := bonus
	for _index in range(dice_count):
		var value := generator.randi_range(1, face)
		last_rolls.append(value)
		total += value
	return total


## 形如 "1D6" / "2D6+1" 的骰子表达式。
func label() -> String:
	var text := "%d%s" % [
		dice_count,
		str(FACE_LABELS.get(face, "D%d" % face)),
	]
	if bonus != 0:
		text += "%s%d" % ["+" if bonus > 0 else "-", absi(bonus)]
	return text


## 形如 "1D6 = 4" 的最近一次投掷说明。
func describe_roll() -> String:
	if last_rolls.is_empty():
		return label()
	var parts := PackedStringArray()
	for value in last_rolls:
		parts.append(str(value))
	var text := "%s = %s" % [label(), " + ".join(parts)]
	if bonus != 0:
		text += "%s%d" % ["+" if bonus > 0 else "-", absi(bonus)]
	return text


func snapshot() -> Dictionary:
	return {
		"dice_count": dice_count,
		"face": face,
		"bonus": bonus,
		"last_rolls": last_rolls.duplicate(),
	}


static func from_snapshot(data: Dictionary) -> DungeonDice:
	var dice := DungeonDice.new(
		int(data.get("dice_count", 1)),
		int(data.get("face", Face.D6)),
		int(data.get("bonus", 0))
	)
	var rolls: Variant = data.get("last_rolls", [])
	if rolls is Array:
		dice.last_rolls.assign(rolls)
	return dice
