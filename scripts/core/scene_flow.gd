extends Node

## 跨场景流程状态。场景节点被释放后，入口目标和战斗返回信息仍保留在这里。
## 具体场景仍只通过 RPGScene 的公开 API 发起切换，不直接依赖本节点的内部结构。

var encounter_data: Dictionary = {}

var _battle_return_scene_path := ""
var _battle_return_position: Variant = null
var _battle_return_yaw := 0.0
var _battle_return_spawn_id: StringName = &""
var _pending_scene_entry: Dictionary = {}
var _dungeon_state: Dictionary = {}


func begin_battle(
	return_scene_path: String,
	return_position: Variant = null,
	return_yaw: float = 0.0,
	data: Dictionary = {}
) -> void:
	_battle_return_scene_path = return_scene_path
	_battle_return_position = return_position
	_battle_return_yaw = return_yaw
	_battle_return_spawn_id = StringName(data.get("return_spawn_id", &""))
	encounter_data = data.duplicate(true)


func has_battle_return() -> bool:
	return not _battle_return_scene_path.is_empty()


func take_battle_return() -> Dictionary:
	var result := {
		"scene_path": _battle_return_scene_path,
		"position": _battle_return_position,
		"yaw": _battle_return_yaw,
		"spawn_id": _battle_return_spawn_id,
	}
	clear_battle_return()
	return result


func clear_battle_return() -> void:
	_battle_return_scene_path = ""
	_battle_return_position = null
	_battle_return_yaw = 0.0
	_battle_return_spawn_id = &""
	encounter_data.clear()


# ---------------------------------------------------------------------------
# 秘境快照
# ---------------------------------------------------------------------------


## 保存秘境迷宫快照。进入战斗前调用，返回秘境后由 DungeonScene 恢复。
func set_dungeon_state(data: Dictionary) -> void:
	_dungeon_state = data.duplicate(true)


func has_dungeon_state() -> bool:
	return not _dungeon_state.is_empty()


## 读取快照但保留，适合 UI 检查或调试。
func peek_dungeon_state() -> Dictionary:
	return _dungeon_state.duplicate(true)


## 读取并清除快照，防止旧迷宫状态污染下一次秘境进入。
func take_dungeon_state() -> Dictionary:
	var result := peek_dungeon_state()
	clear_dungeon_state()
	return result


func clear_dungeon_state() -> void:
	_dungeon_state.clear()


func queue_scene_entry(
	scene_path: String,
	spawn_id: StringName = &"",
	position_override: Variant = null,
	yaw_override: Variant = null
) -> void:
	if scene_path.is_empty():
		return
	_pending_scene_entry = {
		"scene_path": scene_path,
		"spawn_id": spawn_id,
		"position": position_override,
		"yaw": yaw_override,
	}


func consume_scene_entry(scene_path: String) -> Dictionary:
	if scene_path.is_empty() or _pending_scene_entry.is_empty():
		return {}
	if str(_pending_scene_entry.get("scene_path", "")) != scene_path:
		return {}
	var result := _pending_scene_entry.duplicate(true)
	_pending_scene_entry.clear()
	return result
