class_name DungeonMaze
extends RefCounted

## 副本秘境迷宫数据模型。
##
## 只负责一层秘境的生成、移动与事件结算，不持有任何 UI 节点，因此既能在
## 无界面测试里单独验证，也能被 SceneFlow 直接序列化后在跨场景流程中还原。
##
## 迷宫使用六边形网格 HexGrid 的轴向坐标，事件类型、奖励类型全部使用枚举
## 描述，具体文案通过枚举标签表读取，便于后期扩展与本地化。

const HexGridScript := preload("res://scripts/dungeon/hex_grid.gd")
const DungeonDiceScript := preload("res://scripts/dungeon/dungeon_dice.gd")

## 秘境事件类型。主线支线需求、炼器/炼丹材料、法宝机缘都在此枚举里表达。
enum EventType {
	NONE,
	ENTRY,
	EXIT,
	BATTLE,
	FORGE_MATERIAL,
	ALCHEMY_MATERIAL,
	ARTIFACT,
	QUEST_CLUE,
	TRAP,
	SPIRIT_SPRING,
}

## 结算后产出的奖励类型。战斗与任务需求可读取同一套奖励记录。
enum RewardType {
	NONE,
	FORGE_MATERIAL,
	ALCHEMY_MATERIAL,
	ARTIFACT,
	QUEST_CLUE,
	CURRENCY,
	HEAL,
}

const EVENT_LABELS: Dictionary = {
	EventType.NONE: "空境",
	EventType.ENTRY: "秘境入口",
	EventType.EXIT: "秘境出口",
	EventType.BATTLE: "妖物拦路",
	EventType.FORGE_MATERIAL: "炼器材料",
	EventType.ALCHEMY_MATERIAL: "炼丹材料",
	EventType.ARTIFACT: "法宝机缘",
	EventType.QUEST_CLUE: "任务线索",
	EventType.TRAP: "禁制陷阱",
	EventType.SPIRIT_SPRING: "灵泉",
}

const REWARD_LABELS: Dictionary = {
	RewardType.NONE: "无",
	RewardType.FORGE_MATERIAL: "炼器材料",
	RewardType.ALCHEMY_MATERIAL: "炼丹材料",
	RewardType.ARTIFACT: "法宝",
	RewardType.QUEST_CLUE: "任务线索",
	RewardType.CURRENCY: "灵石",
	RewardType.HEAL: "气血回复",
}

const FORGE_MATERIAL_NAMES: Array[String] = [
	"玄铁精",
	"赤炎砂",
	"寒星铁",
	"雷纹钢",
]
const ALCHEMY_MATERIAL_NAMES: Array[String] = [
	"三叶灵草",
	"赤参",
	"碧血藤",
	"紫芝",
]
const ARTIFACT_NAMES: Array[String] = [
	"聚灵剑穗",
	"太虚符箓",
	"凝神玉简",
	"五行阵盘",
]
const QUEST_CLUE_NAMES: Array[String] = [
	"残破的任务玉简",
	"密室机关图",
	"前人洞府坐标",
]
const ENEMY_NAMES: Array[String] = [
	"秘境妖藤",
	"化形石傀",
	"噬灵藤妖",
	"古阵剑灵",
	"秘境魔修",
]

## 单个秘境标识，战斗遭遇用它与其它来源区分。
const SOURCE_ID := "mystic_realm"
const DEFAULT_RADIUS := 2
const VISION_RADIUS := 1
const MAX_LOG_ENTRIES := 40
const TRAP_MOVEMENT_LOSS := 2
const BASE_ENEMY_HP := 180
const ENEMY_HP_PER_FLOOR := 60
const BASE_ENEMY_ATTACK := 10
const ENEMY_ATTACK_PER_FLOOR := 3

## 随机事件权重池，数值越大出现概率越高。
const RANDOM_EVENT_POOL: Array[int] = [
	EventType.NONE,
	EventType.NONE,
	EventType.BATTLE,
	EventType.BATTLE,
	EventType.QUEST_CLUE,
	EventType.TRAP,
	EventType.SPIRIT_SPRING,
]

var floor_index: int = 1
var radius: int = DEFAULT_RADIUS
var movement_dice: DungeonDice = null
var rng := RandomNumberGenerator.new()

## key(String) -> { coord, event, detail, revealed, visited, resolved }
var cells: Dictionary = {}
## key(String) -> Array[String]，记录迷宫打通的通道（生成树）。
var connections: Dictionary = {}
var current_cell := Vector2i.ZERO
var remaining_movement: int = 0
var turn_count: int = 0

var collected_rewards: Dictionary = {}
var collected_artifacts: Array[String] = []
var quest_clues: Array[String] = []
var event_log: Array[String] = []


func _init() -> void:
	movement_dice = DungeonDiceScript.movement_dice()


static func event_label(event_type: int) -> String:
	return str(EVENT_LABELS.get(event_type, "未知事件"))


static func reward_label(reward_type: int) -> String:
	return str(REWARD_LABELS.get(reward_type, "未知奖励"))


# ---------------------------------------------------------------------------
# 生成
# ---------------------------------------------------------------------------


## 生成一层新秘境。seed_value 为 0 时使用随机种子；reset_progress 为 false
## 时保留已收集的奖励与线索，用于「深入下一层」。
func generate(
	seed_value: int = 0,
	floor_number: int = 1,
	grid_radius: int = DEFAULT_RADIUS,
	reset_progress: bool = true
) -> void:
	floor_index = maxi(floor_number, 1)
	radius = maxi(grid_radius, 1)
	rng = RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value

	if reset_progress:
		collected_rewards.clear()
		collected_artifacts.clear()
		quest_clues.clear()
		event_log.clear()

	cells.clear()
	connections.clear()
	remaining_movement = 0
	turn_count = 0

	_build_cells()
	_carve_maze()
	_place_events()

	current_cell = _entry_cell()
	_mark_visited(current_cell)
	_reveal_around(current_cell)
	_log("踏入第 %d 层秘境，掷骰决定移动力。" % floor_index)


## 通往下一层，保留已获得的奖励与线索。
func descend() -> void:
	var next_floor := floor_index + 1
	var next_seed := rng.randi()
	generate(next_seed, next_floor, radius, false)


func _build_cells() -> void:
	for coord in HexGridScript.spiral(Vector2i.ZERO, radius):
		var key := HexGridScript.key(coord)
		cells[key] = {
			"coord": coord,
			"event": EventType.NONE,
			"detail": "",
			"revealed": false,
			"visited": false,
			"resolved": false,
		}
		connections[key] = [] as Array[String]


## 深度优先生成连通迷宫：每条边都是通道，未打通的邻居不可直接移动。
func _carve_maze() -> void:
	var start := _entry_cell()
	var visit_log := {HexGridScript.key(start): true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var current: Vector2i = stack[stack.size() - 1]
		var candidates: Array[Vector2i] = []
		for neighbor in HexGridScript.neighbors(current):
			var neighbor_key := HexGridScript.key(neighbor)
			if cells.has(neighbor_key) and not visit_log.has(neighbor_key):
				candidates.append(neighbor)
		if candidates.is_empty():
			stack.pop_back()
			continue
		var next: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		_connect(current, next)
		visit_log[HexGridScript.key(next)] = true
		stack.append(next)


func _connect(from: Vector2i, to: Vector2i) -> void:
	var from_key := HexGridScript.key(from)
	var to_key := HexGridScript.key(to)
	(connections[from_key] as Array[String]).append(to_key)
	(connections[to_key] as Array[String]).append(from_key)


## 布置事件：起点、最远点作为出口，并保底提供炼器材料、炼丹材料与法宝机缘。
func _place_events() -> void:
	var exit_cell := _farthest_cell_from(_entry_cell())
	_set_event(_entry_cell(), EventType.ENTRY, "阵纹入口")
	_set_event(exit_cell, EventType.EXIT, "秘境传送阵")

	var candidates: Array[Vector2i] = []
	for key in cells.keys():
		var coord: Vector2i = cells[key]["coord"]
		if coord == _entry_cell() or coord == exit_cell:
			continue
		candidates.append(coord)
	_shuffle(candidates)

	var ensured_events: Array[int] = [
		EventType.FORGE_MATERIAL,
		EventType.ALCHEMY_MATERIAL,
		EventType.ARTIFACT,
	]
	var index := 0
	for event_type in ensured_events:
		if index < candidates.size():
			_set_event(candidates[index], event_type)
			index += 1

	while index < candidates.size():
		var event_type: int = RANDOM_EVENT_POOL[
			rng.randi_range(0, RANDOM_EVENT_POOL.size() - 1)
		]
		_set_event(candidates[index], event_type)
		index += 1


func _set_event(
	coord: Vector2i,
	event_type: int,
	detail_override: String = ""
) -> void:
	var key := HexGridScript.key(coord)
	if not cells.has(key):
		return
	cells[key]["event"] = event_type
	cells[key]["detail"] = (
		detail_override
		if not detail_override.is_empty()
		else _random_detail(event_type)
	)


func _random_detail(event_type: int) -> String:
	match event_type:
		EventType.FORGE_MATERIAL:
			return _random_from(FORGE_MATERIAL_NAMES)
		EventType.ALCHEMY_MATERIAL:
			return _random_from(ALCHEMY_MATERIAL_NAMES)
		EventType.ARTIFACT:
			return _random_from(ARTIFACT_NAMES)
		EventType.QUEST_CLUE:
			return _random_from(QUEST_CLUE_NAMES)
		EventType.BATTLE:
			return enemy_name_for_floor()
		EventType.TRAP:
			return "禁制"
		EventType.SPIRIT_SPRING:
			return "灵泉"
		EventType.ENTRY:
			return "阵纹入口"
		EventType.EXIT:
			return "秘境传送阵"
	return ""


func _random_from(options: Array[String]) -> String:
	if options.is_empty():
		return ""
	return options[rng.randi_range(0, options.size() - 1)]


func _shuffle(list: Array[Vector2i]) -> void:
	for index in range(list.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temp := list[index]
		list[index] = list[swap_index]
		list[swap_index] = temp


func _farthest_cell_from(origin: Vector2i) -> Vector2i:
	var farthest := origin
	var farthest_distance := 0
	for key in cells.keys():
		var coord: Vector2i = cells[key]["coord"]
		var hex_distance := HexGridScript.distance(origin, coord)
		if hex_distance > farthest_distance:
			farthest_distance = hex_distance
			farthest = coord
	return farthest


func _entry_cell() -> Vector2i:
	return Vector2i.ZERO


# ---------------------------------------------------------------------------
# 查询
# ---------------------------------------------------------------------------


func all_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for key in cells.keys():
		result.append(cells[key]["coord"])
	return result


func total_cell_count() -> int:
	return cells.size()


func revealed_cell_count() -> int:
	var count := 0
	for key in cells.keys():
		if bool(cells[key]["revealed"]):
			count += 1
	return count


func cell_data(cell: Vector2i) -> Dictionary:
	return cells.get(HexGridScript.key(cell), {})


func has_cell(cell: Vector2i) -> bool:
	return cells.has(HexGridScript.key(cell))


func event_at(cell: Vector2i) -> int:
	var data := cell_data(cell)
	if data.is_empty():
		return EventType.NONE
	return int(data.get("event", EventType.NONE))


func event_detail_at(cell: Vector2i) -> String:
	var data := cell_data(cell)
	if data.is_empty():
		return ""
	return str(data.get("detail", ""))


func is_revealed(cell: Vector2i) -> bool:
	var data := cell_data(cell)
	return not data.is_empty() and bool(data.get("revealed", false))


func is_visited(cell: Vector2i) -> bool:
	var data := cell_data(cell)
	return not data.is_empty() and bool(data.get("visited", false))


func is_resolved(cell: Vector2i) -> bool:
	var data := cell_data(cell)
	return not data.is_empty() and bool(data.get("resolved", false))


func is_current(cell: Vector2i) -> bool:
	return cell == current_cell


func is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return HexGridScript.distance(a, b) == 1


## 两个格子之间是否已经打通通道。
func are_connected(a: Vector2i, b: Vector2i) -> bool:
	var neighbors: Array[String] = connections.get(
		HexGridScript.key(a),
		[] as Array[String]
	)
	return neighbors.has(HexGridScript.key(b))


## 单步移动是否合法：相邻、存在且已打通。
func is_step_valid(target: Vector2i) -> bool:
	return (
		has_cell(target)
		and is_adjacent(current_cell, target)
		and are_connected(current_cell, target)
	)


func find_cells_by_event(event_type: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for key in cells.keys():
		if int(cells[key]["event"]) == event_type:
			result.append(cells[key]["coord"])
	return result


func can_exit() -> bool:
	return event_at(current_cell) == EventType.EXIT


## 以当前移动力可抵达的格子，key -> 消耗步数（含当前格，消耗为 0）。
func reachable_cells(limit: int = -1) -> Dictionary:
	var budget := remaining_movement if limit < 0 else limit
	var result := {HexGridScript.key(current_cell): 0}
	var frontier: Array[Vector2i] = [current_cell]
	while not frontier.is_empty():
		var next_frontier: Array[Vector2i] = []
		for cell in frontier:
			var cell_cost := int(result[HexGridScript.key(cell)])
			if cell_cost >= budget:
				continue
			for neighbor_key in connections.get(HexGridScript.key(cell), []):
				if result.has(neighbor_key):
					continue
				result[neighbor_key] = cell_cost + 1
				next_frontier.append(HexGridScript.parse_key(neighbor_key))
		frontier = next_frontier
	return result


## 返回从当前格到目标格的唯一通道路径（含两端）；不可达时返回空数组。
func find_path(target: Vector2i) -> Array[Vector2i]:
	if not has_cell(target):
		return [] as Array[Vector2i]
	var start_key := HexGridScript.key(current_cell)
	var target_key := HexGridScript.key(target)
	if start_key == target_key:
		return [current_cell] as Array[Vector2i]
	var came_from := {start_key: ""}
	var queue: Array[String] = [start_key]
	while not queue.is_empty():
		var key: String = queue.pop_front()
		for neighbor_key in connections.get(key, []):
			if came_from.has(neighbor_key):
				continue
			came_from[neighbor_key] = key
			if neighbor_key == target_key:
				return _reconstruct_path(came_from, target_key)
			queue.append(neighbor_key)
	return [] as Array[Vector2i]


func _reconstruct_path(
	came_from: Dictionary,
	target_key: String
) -> Array[Vector2i]:
	var keys: Array[String] = [target_key]
	var cursor := target_key
	while true:
		var previous := str(came_from.get(cursor, ""))
		if previous.is_empty():
			break
		keys.append(previous)
		cursor = previous
	keys.reverse()
	var path: Array[Vector2i] = []
	for key in keys:
		path.append(HexGridScript.parse_key(key))
	return path


# ---------------------------------------------------------------------------
# 移动与事件
# ---------------------------------------------------------------------------


## 掷骰获得移动力。已有剩余移动力时不会重复投掷。
func roll_movement() -> Dictionary:
	if remaining_movement > 0:
		return {
			"granted": 0,
			"total": remaining_movement,
			"detail": "尚有移动力可用。",
		}
	turn_count += 1
	var granted := maxi(movement_dice.roll(rng), 1)
	remaining_movement = granted
	var detail := movement_dice.describe_roll()
	_log("第 %d 回合：%s，获得 %d 点移动力。" % [turn_count, detail, granted])
	return {
		"granted": granted,
		"total": remaining_movement,
		"detail": detail,
	}


## 单步移动并结算落点事件。返回 { ok, reason, event }。
func step_to(target: Vector2i) -> Dictionary:
	if not is_step_valid(target):
		return {"ok": false, "reason": "该方向没有通路。", "event": {}}
	if remaining_movement <= 0:
		return {"ok": false, "reason": "移动力不足。", "event": {}}
	remaining_movement -= 1
	current_cell = target
	_mark_visited(target)
	_reveal_around(target)
	var event := _resolve_event(target)
	return {"ok": true, "reason": "", "event": event}


## 沿通道自动行走到目标格，逐格结算事件。
## 返回 { moved, path, events, blocked }，blocked 表示移动力在途中耗尽。
func travel_to(target: Vector2i) -> Dictionary:
	var moved_path: Array[Vector2i] = []
	var events: Array[Dictionary] = []
	var blocked := false
	var path := find_path(target)
	if path.size() <= 1:
		return {
			"moved": 0,
			"path": moved_path,
			"events": events,
			"blocked": false,
		}
	for index in range(1, path.size()):
		var step := step_to(path[index])
		if not step.get("ok", false):
			blocked = remaining_movement <= 0
			break
		moved_path.append(path[index])
		var event: Dictionary = step.get("event", {})
		if not event.is_empty():
			events.append(event)
	return {
		"moved": moved_path.size(),
		"path": moved_path,
		"events": events,
		"blocked": blocked,
	}


func _mark_visited(cell: Vector2i) -> void:
	var key := HexGridScript.key(cell)
	if cells.has(key):
		cells[key]["visited"] = true
		cells[key]["revealed"] = true


func _reveal_around(cell: Vector2i) -> void:
	for coord in HexGridScript.spiral(cell, VISION_RADIUS):
		var key := HexGridScript.key(coord)
		if cells.has(key):
			cells[key]["revealed"] = true


func _resolve_event(cell: Vector2i) -> Dictionary:
	var key := HexGridScript.key(cell)
	if not cells.has(key):
		return {}
	var data: Dictionary = cells[key]
	var event_type := int(data.get("event", EventType.NONE))
	if event_type == EventType.NONE or event_type == EventType.ENTRY:
		return {}
	if event_type == EventType.EXIT:
		return {
			"type": event_type,
			"label": event_label(event_type),
			"message": "踏上传送阵，可深入或离开秘境。",
		}
	if bool(data.get("resolved", false)):
		return {}
	data["resolved"] = true
	var detail := str(data.get("detail", ""))
	match event_type:
		EventType.BATTLE:
			var message := "妖物拦路：%s" % detail
			_log(message)
			return {
				"type": event_type,
				"label": event_label(event_type),
				"message": message,
				"encounter": build_encounter(cell),
			}
		EventType.FORGE_MATERIAL:
			_grant_reward(RewardType.FORGE_MATERIAL, detail)
			var message := "拾得炼器材料：%s" % detail
			_log(message)
			return _reward_event(event_type, message, RewardType.FORGE_MATERIAL, detail)
		EventType.ALCHEMY_MATERIAL:
			_grant_reward(RewardType.ALCHEMY_MATERIAL, detail)
			var message := "采得炼丹材料：%s" % detail
			_log(message)
			return _reward_event(event_type, message, RewardType.ALCHEMY_MATERIAL, detail)
		EventType.ARTIFACT:
			_grant_reward(RewardType.ARTIFACT, detail)
			var message := "机缘所得法宝：%s" % detail
			_log(message)
			return _reward_event(event_type, message, RewardType.ARTIFACT, detail)
		EventType.QUEST_CLUE:
			_grant_reward(RewardType.QUEST_CLUE, detail)
			var message := "拾获任务线索：%s" % detail
			_log(message)
			return _reward_event(event_type, message, RewardType.QUEST_CLUE, detail)
		EventType.SPIRIT_SPRING:
			_grant_reward(RewardType.HEAL, detail)
			var message := "灵泉涌动，气血回复。"
			_log(message)
			return _reward_event(event_type, message, RewardType.HEAL, detail)
		EventType.TRAP:
			var lost := mini(remaining_movement, TRAP_MOVEMENT_LOSS)
			remaining_movement = maxi(remaining_movement - lost, 0)
			var message := "触发禁制陷阱，损失 %d 点移动力。" % lost
			_log(message)
			return {
				"type": event_type,
				"label": event_label(event_type),
				"message": message,
				"reward_type": RewardType.NONE,
			}
	return {}


func _reward_event(
	event_type: int,
	message: String,
	reward_type: int,
	detail: String
) -> Dictionary:
	return {
		"type": event_type,
		"label": event_label(event_type),
		"message": message,
		"reward_type": reward_type,
		"detail": detail,
	}


func _grant_reward(reward_type: int, detail: String) -> void:
	match reward_type:
		RewardType.ARTIFACT:
			if not collected_artifacts.has(detail):
				collected_artifacts.append(detail)
		RewardType.QUEST_CLUE:
			if not quest_clues.has(detail):
				quest_clues.append(detail)
		RewardType.FORGE_MATERIAL, RewardType.ALCHEMY_MATERIAL:
			collected_rewards[reward_type] = int(
				collected_rewards.get(reward_type, 0)
			) + 1
		RewardType.HEAL:
			collected_rewards[reward_type] = int(
				collected_rewards.get(reward_type, 0)
			) + 1


func _log(message: String) -> void:
	event_log.append(message)
	while event_log.size() > MAX_LOG_ENTRIES:
		event_log.pop_front()


# ---------------------------------------------------------------------------
# 战斗遭遇
# ---------------------------------------------------------------------------


func enemy_name_for_floor() -> String:
	var index := (floor_index - 1) % ENEMY_NAMES.size()
	return "%s（第%d层）" % [ENEMY_NAMES[index], floor_index]


func scaled_enemy_max_hp(floor_number: int = -1) -> int:
	var floor_value := floor_index if floor_number < 0 else floor_number
	return BASE_ENEMY_HP + ENEMY_HP_PER_FLOOR * maxi(floor_value, 1)


func scaled_enemy_attack(floor_number: int = -1) -> int:
	var floor_value := floor_index if floor_number < 0 else floor_number
	return BASE_ENEMY_ATTACK + ENEMY_ATTACK_PER_FLOOR * maxi(floor_value, 1)


## 构造交给战斗场景的遭遇数据，属性随层数成长。
func build_encounter(cell: Vector2i = current_cell) -> Dictionary:
	return {
		"source": SOURCE_ID,
		"scene_id": SOURCE_ID,
		"enemy_name": enemy_name_for_floor(),
		"enemy_max_hp": scaled_enemy_max_hp(),
		"enemy_attack": scaled_enemy_attack(),
		"dungeon_floor": floor_index,
		"dungeon_cell": HexGridScript.key(cell),
	}


## 当前所在格若为战斗事件，返回遭遇数据；否则返回空字典。
func current_encounter() -> Dictionary:
	if event_at(current_cell) != EventType.BATTLE:
		return {}
	return build_encounter(current_cell)


# ---------------------------------------------------------------------------
# 快照
# ---------------------------------------------------------------------------


func snapshot() -> Dictionary:
	return {
		"floor_index": floor_index,
		"radius": radius,
		"seed_state": rng.state,
		"current_cell": current_cell,
		"remaining_movement": remaining_movement,
		"turn_count": turn_count,
		"cells": cells.duplicate(true),
		"connections": connections.duplicate(true),
		"collected_rewards": collected_rewards.duplicate(true),
		"collected_artifacts": collected_artifacts.duplicate(),
		"quest_clues": quest_clues.duplicate(),
		"event_log": event_log.duplicate(),
		"movement_dice": movement_dice.snapshot(),
	}


func restore_snapshot(data: Dictionary) -> void:
	if data.is_empty():
		return
	floor_index = int(data.get("floor_index", 1))
	radius = int(data.get("radius", DEFAULT_RADIUS))
	remaining_movement = int(data.get("remaining_movement", 0))
	turn_count = int(data.get("turn_count", 0))

	var cell_value: Variant = data.get("current_cell", Vector2i.ZERO)
	if cell_value is Vector2i:
		current_cell = cell_value

	var stored_cells: Variant = data.get("cells", {})
	if stored_cells is Dictionary:
		cells = (stored_cells as Dictionary).duplicate(true)
	var stored_connections: Variant = data.get("connections", {})
	if stored_connections is Dictionary:
		connections = (stored_connections as Dictionary).duplicate(true)

	var stored_rewards: Variant = data.get("collected_rewards", {})
	if stored_rewards is Dictionary:
		collected_rewards = (stored_rewards as Dictionary).duplicate(true)
	var stored_artifacts: Variant = data.get("collected_artifacts", [])
	if stored_artifacts is Array:
		collected_artifacts.assign(stored_artifacts)
	var stored_clues: Variant = data.get("quest_clues", [])
	if stored_clues is Array:
		quest_clues.assign(stored_clues)
	var stored_log: Variant = data.get("event_log", [])
	if stored_log is Array:
		event_log.assign(stored_log)

	var dice_data: Variant = data.get("movement_dice", {})
	if dice_data is Dictionary and not (dice_data as Dictionary).is_empty():
		movement_dice = DungeonDiceScript.from_snapshot(dice_data)

	rng = RandomNumberGenerator.new()
	rng.state = int(data.get("seed_state", 0))
