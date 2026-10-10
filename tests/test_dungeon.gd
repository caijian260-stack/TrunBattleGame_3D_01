extends SceneTree

## 无界面自动化测试：验证副本秘境的数据模型、六边形棋盘与场景编排。
##
## 迷宫规则与表现层分开测试，便于后续新增事件、奖励或棋盘皮肤时快速定位
## 问题。进入真实战斗后的 3D 表现不在本测试覆盖范围内。

const HexGridScript := preload("res://scripts/dungeon/hex_grid.gd")
const DungeonDiceScript := preload("res://scripts/dungeon/dungeon_dice.gd")
const DungeonMazeScript := preload("res://scripts/dungeon/dungeon_maze.gd")
const DungeonBoardViewScript := preload(
	"res://scripts/dungeon/dungeon_board_view.gd"
)
const DungeonSceneScript := preload("res://scripts/dungeon/dungeon_scene.gd")
const SceneFlowScript := preload("res://scripts/core/scene_flow.gd")
const INVALID_CELL := Vector2i(9999, 9999)

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_test_hex_grid()
	_test_dungeon_dice()
	_test_dungeon_maze_generation()
	_test_dungeon_maze_event_and_movement()
	_test_dungeon_maze_rewards_and_snapshot()
	_test_scene_flow_dungeon_state()
	await _test_dungeon_board_view()
	await _test_dungeon_scene()

	if failures == 0:
		print("DUNGEON TESTS PASSED")
		quit(0)
	else:
		print("DUNGEON TESTS FAILED: %d" % failures)
		quit(1)


func _test_hex_grid() -> void:
	var origin := Vector2i.ZERO
	var east := HexGridScript.neighbor(origin, HexGridScript.Direction.E)
	_check(east == Vector2i(1, 0), "Direction.E 应使用稳定的轴向偏移")
	_check(
		HexGridScript.distance(origin, east) == 1,
		"相邻六边形距离应为 1"
	)
	_check(
		HexGridScript.direction_label(HexGridScript.Direction.NE) == "东北",
		"方向显示名应通过 Direction 枚举读取"
	)

	var ring := HexGridScript.ring(origin, 1)
	_check(ring.size() == 6, "半径 1 的六边形环应包含 6 格")
	for cell in ring:
		_check(
			HexGridScript.distance(origin, cell) == 1,
			"环上的每一格都应与中心相邻"
		)

	var spiral := HexGridScript.spiral(origin, 2)
	_check(spiral.size() == 19, "半径 2 的六边形螺旋应包含 19 格")

	var line := HexGridScript.line(origin, Vector2i(2, -1))
	_check(line.size() == 3, "六边形直线应包含起点、中间点和终点")
	_check(line[0] == origin and line[-1] == Vector2i(2, -1), "直线端点应保持")

	for cell in spiral:
		var pixel := HexGridScript.hex_to_pixel(cell, 48.0)
		_check(
			HexGridScript.pixel_to_hex(pixel, 48.0) == cell,
			"轴向坐标与像素坐标应能互相还原"
		)

	var key := HexGridScript.key(Vector2i(-2, 3))
	_check(
		HexGridScript.parse_key(key) == Vector2i(-2, 3),
		"网格 key 应能稳定序列化与还原轴向坐标"
	)


func _test_dungeon_dice() -> void:
	var dice := DungeonDiceScript.new(2, DungeonDiceScript.Face.D6, 1)
	_check(dice.min_total() == 3, "2D6+1 的最小值应为 3")
	_check(dice.max_total() == 13, "2D6+1 的最大值应为 13")
	_check(dice.label() == "2D6+1", "骰子表达式应使用标准化名称")

	var rng := RandomNumberGenerator.new()
	rng.seed = 20261007
	var total := dice.roll(rng)
	_check(total >= dice.min_total() and total <= dice.max_total(), "掷骰结果应在范围内")
	_check(dice.last_rolls.size() == 2, "投掷明细应记录每一颗骰子")
	_check(dice.describe_roll().contains("2D6+1"), "投掷说明应包含骰子表达式")

	var restored := DungeonDiceScript.from_snapshot(dice.snapshot())
	_check(restored.dice_count == 2, "骰子快照应还原颗数")
	_check(restored.face == DungeonDiceScript.Face.D6, "骰子快照应还原面数")
	_check(restored.bonus == 1, "骰子快照应还原加值")
	_check(
		restored.last_rolls == dice.last_rolls,
		"骰子快照应还原最近一次投掷明细"
	)


func _test_dungeon_maze_generation() -> void:
	var maze := DungeonMazeScript.new()
	maze.generate(12345, 1, 2, true)

	_check(maze.total_cell_count() == 19, "半径 2 的秘境应生成 19 格")
	_check(maze.event_at(Vector2i.ZERO) == DungeonMazeScript.EventType.ENTRY, "起点应为入口事件")
	_check(
		maze.find_cells_by_event(DungeonMazeScript.EventType.EXIT).size() == 1,
		"每层秘境应有且仅有一个出口"
	)
	_check(
		maze.find_cells_by_event(
			DungeonMazeScript.EventType.FORGE_MATERIAL
		).size() >= 1,
		"每层应保底生成炼器材料事件"
	)
	_check(
		maze.find_cells_by_event(
			DungeonMazeScript.EventType.ALCHEMY_MATERIAL
		).size() >= 1,
		"每层应保底生成炼丹材料事件"
	)
	_check(
		maze.find_cells_by_event(DungeonMazeScript.EventType.ARTIFACT).size() >= 1,
		"每层应保底生成法宝机缘事件"
	)

	var all_reachable := true
	for cell in maze.all_cells():
		if maze.find_path(cell).is_empty():
			all_reachable = false
			break
	_check(all_reachable, "生成树应保证所有格子都能从入口抵达")

	for key in maze.connections.keys():
		var from := HexGridScript.parse_key(str(key))
		var neighbor_keys: Array = maze.connections[key]
		for neighbor_key_value in neighbor_keys:
			var neighbor_key := str(neighbor_key_value)
			_check(
				maze.are_connected(HexGridScript.parse_key(neighbor_key), from),
				"迷宫通道应保持双向连接"
			)


func _test_dungeon_maze_event_and_movement() -> void:
	var maze := DungeonMazeScript.new()
	maze.generate(67890, 1, 2, true)

	var roll := maze.roll_movement()
	var granted := int(roll.get("granted", 0))
	_check(granted >= 1 and granted <= 6, "默认 1D6 应提供 1~6 点移动力")
	_check(maze.remaining_movement == granted, "掷骰后应写入剩余移动力")
	_check(
		int(maze.roll_movement().get("granted", -1)) == 0,
		"已有移动力时不应重复掷骰"
	)

	var target := _find_resolvable_event_cell(maze)
	_check(target != INVALID_CELL, "应能找到可结算事件格")
	if target == INVALID_CELL:
		return

	maze.remaining_movement = 999
	var path := maze.find_path(target)
	_check(path.size() >= 2, "事件格应能通过迷宫通道到达")
	for index in range(1, path.size() - 1):
		maze.step_to(path[index])

	var arrival := maze.step_to(path[-1])
	var arrival_event: Variant = arrival.get("event", {})
	_check(
		arrival_event is Dictionary and not (arrival_event as Dictionary).is_empty(),
		"首次抵达事件格应结算事件"
	)
	_check(maze.is_resolved(target), "非出口事件首次结算后应标记为已解决")

	maze.step_to(path[-2])
	var repeat := maze.step_to(path[-1])
	var repeat_event: Variant = repeat.get("event", {})
	_check(
		repeat_event is Dictionary and (repeat_event as Dictionary).is_empty(),
		"已解决事件再次进入时不应重复结算"
	)

	var reachable := maze.reachable_cells(1)
	for key in maze.connections[HexGridScript.key(maze.current_cell)]:
		_check(
			reachable.has(str(key)),
			"移动力为 1 时，直接连通的邻格应可达"
		)


func _test_dungeon_maze_rewards_and_snapshot() -> void:
	var maze := DungeonMazeScript.new()
	maze.generate(24680, 1, 2, true)

	var forge_cell := _first_event_cell(
		maze,
		DungeonMazeScript.EventType.FORGE_MATERIAL
	)
	var alchemy_cell := _first_event_cell(
		maze,
		DungeonMazeScript.EventType.ALCHEMY_MATERIAL
	)
	var artifact_cell := _first_event_cell(
		maze,
		DungeonMazeScript.EventType.ARTIFACT
	)
	_check(
		forge_cell != INVALID_CELL
		and alchemy_cell != INVALID_CELL
		and artifact_cell != INVALID_CELL,
		"奖励测试所需的保底事件应全部存在"
	)

	_walk_to(maze, forge_cell)
	_walk_to(maze, alchemy_cell)
	_walk_to(maze, artifact_cell)
	_check(
		int(maze.collected_rewards.get(
			DungeonMazeScript.RewardType.FORGE_MATERIAL,
			0
		)) >= 1,
		"炼器材料事件应写入奖励汇总"
	)
	_check(
		int(maze.collected_rewards.get(
			DungeonMazeScript.RewardType.ALCHEMY_MATERIAL,
			0
		)) >= 1,
		"炼丹材料事件应写入奖励汇总"
	)
	_check(maze.collected_artifacts.size() >= 1, "法宝机缘应写入收藏列表")

	var saved_floor := maze.floor_index
	var saved_cell := maze.current_cell
	var saved_movement := maze.remaining_movement
	var restored := DungeonMazeScript.new()
	restored.restore_snapshot(maze.snapshot())
	_check(restored.floor_index == saved_floor, "快照应还原层数")
	_check(restored.current_cell == saved_cell, "快照应还原当前位置")
	_check(restored.remaining_movement == saved_movement, "快照应还原移动力")
	_check(
		restored.collected_artifacts == maze.collected_artifacts,
		"快照应还原法宝收藏"
	)
	_check(
		restored.collected_rewards == maze.collected_rewards,
		"快照应还原奖励汇总"
	)

	var encounter := maze.build_encounter()
	_check(
		int(encounter.get("enemy_max_hp", 0)) == maze.scaled_enemy_max_hp(),
		"战斗遭遇应使用当前层数的敌人生命"
	)
	_check(
		int(encounter.get("enemy_attack", 0)) == maze.scaled_enemy_attack(),
		"战斗遭遇应使用当前层数的敌人攻击"
	)

	var previous_artifacts := maze.collected_artifacts.size()
	maze.descend()
	_check(maze.floor_index == 2, "深入下一层后层数应增加")
	_check(
		maze.collected_artifacts.size() == previous_artifacts,
		"深入下一层时应保留已获得法宝"
	)
	_check(
		maze.find_cells_by_event(
			DungeonMazeScript.EventType.FORGE_MATERIAL
		).size() >= 1,
		"新一层仍应生成炼器材料保底事件"
	)


func _test_scene_flow_dungeon_state() -> void:
	var flow := SceneFlowScript.new()
	var state := {
		"scene_path": "res://scenes/mystic_realm.tscn",
		"maze_state": {"floor_index": 2},
	}
	flow.set_dungeon_state(state)
	_check(flow.has_dungeon_state(), "SceneFlow 应保存秘境快照")
	_check(
		flow.peek_dungeon_state().get("maze_state", {}).get("floor_index", 0) == 2,
		"SceneFlow 读取快照时不应提前清除"
	)
	_check(flow.take_dungeon_state().size() == 2, "SceneFlow 应能取出秘境快照")
	_check(not flow.has_dungeon_state(), "取出秘境快照后应清除状态")
	flow.queue_scene_entry(
		"res://scenes/mystic_realm.tscn",
		&"mystic_arrival"
	)
	var entry := flow.consume_scene_entry("res://scenes/mystic_realm.tscn")
	_check(
		StringName(entry.get("spawn_id", &"")) == &"mystic_arrival",
		"SceneFlow 应保留秘境入口出生点"
	)
	flow.free()


func _test_dungeon_board_view() -> void:
	var maze := DungeonMazeScript.new()
	maze.generate(13579, 1, 2, true)

	var view := DungeonBoardViewScript.new()
	view.size = Vector2(800.0, 800.0)
	view.set_maze(maze)
	root.add_child(view)
	await process_frame

	var layout: Dictionary = view._get_layout()
	var origin := layout.get("origin", Vector2.ZERO) as Vector2
	var hex_size := float(layout.get("hex_size", 48.0))
	var sampled_cell := Vector2i(1, -1)
	var center := origin + HexGridScript.hex_to_pixel(sampled_cell, hex_size)
	_check(
		view.cell_at_local_position(center) == sampled_cell,
		"棋盘应把鼠标像素坐标正确转换为轴向坐标"
	)
	_check(
		view.cell_at_local_position(Vector2(-100.0, -100.0))
		== INVALID_CELL,
		"棋盘外的鼠标位置不应命中格子"
	)

	view.set_reachable_cells({HexGridScript.key(Vector2i.ZERO): 0})
	_check(
		view._reachable_cells.has(HexGridScript.key(Vector2i.ZERO)),
		"棋盘视图应保留可移动格高亮数据"
	)
	view.clear_reachable_cells()
	_check(view._reachable_cells.is_empty(), "棋盘视图应能清除可达格高亮")

	view.queue_free()
	await process_frame


func _test_dungeon_scene() -> void:
	var flow := root.get_node_or_null("/root/SceneFlow")
	if flow != null:
		flow.clear_dungeon_state()

	var scene := DungeonSceneScript.new()
	root.add_child(scene)
	await process_frame

	_check(scene is Control, "秘境场景根节点应为 2D Control")
	_check(scene is BaseGameScene, "秘境场景应继承通用场景基类")
	_check(scene is DungeonScene, "秘境场景应属于 DungeonScene 类型")
	_check(scene.scene_id == &"mystic_realm", "秘境场景应提供稳定 scene_id")
	_check(
		scene.find_child("DungeonBoard", true, false) is DungeonBoardView,
		"秘境场景应创建六边形棋盘视图"
	)

	var roll_button := scene.find_child(
		"RollMovementButton",
		true,
		false
	) as Button
	var descend_button := scene.find_child(
		"DescendButton",
		true,
		false
	) as Button
	var leave_button := scene.find_child(
		"LeaveDungeonButton",
		true,
		false
	) as Button
	_check(roll_button != null, "秘境场景应提供掷骰按钮")
	_check(descend_button != null, "秘境场景应提供深入下一层按钮")
	_check(leave_button != null, "秘境场景应提供离开秘境按钮")
	_check(
		scene.find_child("EventLog", true, false) is RichTextLabel,
		"秘境场景应提供事件日志"
	)
	_check(
		scene.find_child("RewardSummary", true, false) is Label,
		"秘境场景应提供奖励汇总"
	)

	if roll_button != null:
		roll_button.pressed.emit()
		await process_frame
		_check(scene.maze.remaining_movement >= 1, "点击掷骰按钮应获得移动力")
		_check(
			not scene._board_view._reachable_cells.is_empty(),
			"获得移动力后棋盘应显示可达格"
		)

	var saved_cell := scene.maze.current_cell
	var saved_movement := scene.maze.remaining_movement
	var saved_scene_path := scene.source_scene_path
	scene._save_dungeon_state()
	scene.queue_free()
	await process_frame

	if flow != null:
		flow.queue_scene_entry(
			saved_scene_path,
			DungeonSceneScript.BATTLE_RETURN_SPAWN_ID
		)
		var restored := DungeonSceneScript.new()
		root.add_child(restored)
		await process_frame
		_check(
			restored.maze.current_cell == saved_cell,
			"从战斗返回时应恢复秘境当前位置"
		)
		_check(
			restored.maze.remaining_movement == saved_movement,
			"从战斗返回时应恢复剩余移动力"
		)
		_check(restored._restored_from_battle, "从快照恢复的秘境应标记战斗返回状态")
		restored.queue_free()
		await process_frame


func _find_resolvable_event_cell(maze: DungeonMaze) -> Vector2i:
	for key in maze.cells.keys():
		var data: Dictionary = maze.cells[key]
		var event_type := int(data.get("event", DungeonMazeScript.EventType.NONE))
		if (
			event_type != DungeonMazeScript.EventType.NONE
			and event_type != DungeonMazeScript.EventType.ENTRY
			and event_type != DungeonMazeScript.EventType.EXIT
		):
			return data.get("coord", Vector2i.ZERO)
	return INVALID_CELL


func _first_event_cell(maze: DungeonMaze, event_type: int) -> Vector2i:
	var cells := maze.find_cells_by_event(event_type)
	if cells.is_empty():
		return INVALID_CELL
	return cells[0]


func _walk_to(maze: DungeonMaze, target: Vector2i) -> void:
	if target == INVALID_CELL:
		return
	maze.remaining_movement = 999
	var path := maze.find_path(target)
	for index in range(1, path.size()):
		maze.step_to(path[index])


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)
