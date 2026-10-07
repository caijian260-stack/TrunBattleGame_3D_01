class_name DungeonBoardView
extends Control

## 六边形秘境棋盘视图。
##
## 本类只负责把 DungeonMaze 的数据绘制成可点击棋盘，并把鼠标位置转换成
## 轴向坐标。生成、寻路、移动力和事件结算全部留在数据模型中，保证规则可
## 在无界面测试中独立验证。

signal cell_clicked(cell: Vector2i)
signal cell_hovered(cell: Vector2i)

const HexGridScript := preload("res://scripts/dungeon/hex_grid.gd")
const DungeonMazeScript := preload("res://scripts/dungeon/dungeon_maze.gd")
const INVALID_CELL := Vector2i(9999, 9999)
const BOARD_PADDING := 28.0
const MIN_HEX_SIZE := 34.0
const MAX_HEX_SIZE := 72.0

const EVENT_MARKERS: Dictionary = {
	DungeonMazeScript.EventType.ENTRY: "入",
	DungeonMazeScript.EventType.EXIT: "阵",
	DungeonMazeScript.EventType.BATTLE: "战",
	DungeonMazeScript.EventType.FORGE_MATERIAL: "器",
	DungeonMazeScript.EventType.ALCHEMY_MATERIAL: "丹",
	DungeonMazeScript.EventType.ARTIFACT: "宝",
	DungeonMazeScript.EventType.QUEST_CLUE: "讯",
	DungeonMazeScript.EventType.TRAP: "陷",
	DungeonMazeScript.EventType.SPIRIT_SPRING: "泉",
}

const EVENT_COLORS: Dictionary = {
	DungeonMazeScript.EventType.ENTRY: Color(0.34, 0.76, 0.88),
	DungeonMazeScript.EventType.EXIT: Color(0.94, 0.74, 0.28),
	DungeonMazeScript.EventType.BATTLE: Color(0.86, 0.28, 0.22),
	DungeonMazeScript.EventType.FORGE_MATERIAL: Color(0.78, 0.54, 0.28),
	DungeonMazeScript.EventType.ALCHEMY_MATERIAL: Color(0.38, 0.78, 0.48),
	DungeonMazeScript.EventType.ARTIFACT: Color(0.74, 0.46, 0.92),
	DungeonMazeScript.EventType.QUEST_CLUE: Color(0.32, 0.68, 0.94),
	DungeonMazeScript.EventType.TRAP: Color(0.88, 0.38, 0.24),
	DungeonMazeScript.EventType.SPIRIT_SPRING: Color(0.30, 0.82, 0.78),
}

var maze: DungeonMaze = null
var _reachable_cells: Dictionary = {}
var _hovered_cell := INVALID_CELL


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	resized.connect(queue_redraw)


func set_maze(value: DungeonMaze) -> void:
	maze = value
	_hovered_cell = INVALID_CELL
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func set_reachable_cells(cells: Dictionary) -> void:
	_reachable_cells = cells.duplicate()
	queue_redraw()


func clear_reachable_cells() -> void:
	_reachable_cells.clear()
	queue_redraw()


func cell_at_local_position(point: Vector2) -> Vector2i:
	if maze == null:
		return INVALID_CELL
	var layout := _get_layout()
	var hex_size := float(layout.get("hex_size", MIN_HEX_SIZE))
	var origin := layout.get("origin", Vector2.ZERO) as Vector2
	var cell := HexGridScript.pixel_to_hex((point - origin) / hex_size, 1.0)
	if not maze.has_cell(cell):
		return INVALID_CELL
	return cell


func _gui_input(event: InputEvent) -> void:
	if maze == null:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var hovered := cell_at_local_position(motion.position)
		if hovered != _hovered_cell:
			_hovered_cell = hovered
			cell_hovered.emit(hovered)
			mouse_default_cursor_shape = (
				Control.CURSOR_POINTING_HAND
				if hovered != INVALID_CELL
				else Control.CURSOR_ARROW
			)
			queue_redraw()
		return
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		var clicked := cell_at_local_position(event.position)
		if clicked != INVALID_CELL:
			accept_event()
			cell_clicked.emit(clicked)


func _draw() -> void:
	if maze == null:
		return
	_draw_backdrop()
	var layout := _get_layout()
	var hex_size := float(layout.get("hex_size", MIN_HEX_SIZE))
	var origin := layout.get("origin", Vector2.ZERO) as Vector2
	_draw_connections(origin, hex_size)
	for key in maze.cells.keys():
		var data: Dictionary = maze.cells[key]
		_draw_cell(data["coord"], data, origin, hex_size)


func _draw_backdrop() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.018, 0.028, 0.045, 0.96), true)
	for index in range(12):
		var y := size.y * float(index + 1) / 13.0
		draw_line(
			Vector2(0.0, y),
			Vector2(size.x, y + 18.0),
			Color(0.18, 0.36, 0.42, 0.045),
			1.0
		)


func _draw_connections(origin: Vector2, hex_size: float) -> void:
	for from_key in maze.connections.keys():
		var from := HexGridScript.parse_key(str(from_key))
		var neighbors: Array = maze.connections[from_key]
		for to_key_value in neighbors:
			var to_key := str(to_key_value)
			if str(from_key) > to_key:
				continue
			var to := HexGridScript.parse_key(to_key)
			if not maze.is_revealed(from) and not maze.is_revealed(to):
				continue
			var accent := Color(0.22, 0.58, 0.65, 0.55)
			if maze.is_current(from) or maze.is_current(to):
				accent = Color(0.38, 0.88, 0.9, 0.82)
			draw_line(
				origin + HexGridScript.hex_to_pixel(from, hex_size),
				origin + HexGridScript.hex_to_pixel(to, hex_size),
				accent,
				maxf(3.0, hex_size * 0.08),
				true
			)


func _draw_cell(
	cell: Vector2i,
	data: Dictionary,
	origin: Vector2,
	hex_size: float
) -> void:
	var center := origin + HexGridScript.hex_to_pixel(cell, hex_size)
	var corners := HexGridScript.hex_corners(center, hex_size * 0.93)
	var revealed := bool(data.get("revealed", false))
	var visited := bool(data.get("visited", false))
	var is_current := maze.is_current(cell)
	var event_type := int(data.get("event", DungeonMazeScript.EventType.NONE))
	var cell_key := HexGridScript.key(cell)
	var reachable := _reachable_cells.has(cell_key)

	var fill := Color(0.035, 0.055, 0.075, 0.98)
	var border := Color(0.14, 0.20, 0.25, 0.72)
	if revealed:
		fill = Color(0.09, 0.135, 0.16, 0.98)
		border = Color(0.25, 0.42, 0.47, 0.8)
	if visited:
		fill = fill.lightened(0.045)
	if reachable and not is_current:
		fill = fill.lightened(0.10)
		border = Color(0.34, 0.86, 0.88, 0.95)
	if cell == _hovered_cell:
		fill = fill.lightened(0.14)
		border = Color(0.96, 0.92, 0.70, 1.0)
	if is_current:
		fill = Color(0.14, 0.45, 0.46, 0.98)
		border = Color(0.82, 0.98, 0.88, 1.0)

	draw_colored_polygon(corners, fill)
	var outline := corners.duplicate()
	outline.append(corners[0])
	draw_polyline(
		outline,
		border,
		3.0 if is_current or reachable or cell == _hovered_cell else 1.5,
		true
	)

	if not revealed:
		return

	if event_type != DungeonMazeScript.EventType.NONE:
		var marker := str(EVENT_MARKERS.get(event_type, "?"))
		var marker_color: Color = EVENT_COLORS.get(
			event_type,
			Color(0.78, 0.82, 0.86)
		)
		if bool(data.get("resolved", false)):
			marker_color = marker_color.darkened(0.32)
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-hex_size * 0.7, hex_size * 0.26),
			marker,
			HORIZONTAL_ALIGNMENT_CENTER,
			hex_size * 1.4,
			int(maxf(22.0, hex_size * 0.58)),
			marker_color
		)

	if reachable and not is_current:
		var cost := int(_reachable_cells.get(cell_key, 0))
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-hex_size * 0.45, hex_size * 0.78),
			str(cost),
			HORIZONTAL_ALIGNMENT_CENTER,
			hex_size * 0.9,
			int(maxf(12.0, hex_size * 0.25)),
			Color(0.82, 0.96, 1.0, 0.9)
		)


func _get_layout() -> Dictionary:
	var cells := maze.all_cells()
	var unit_bounds := HexGridScript.pixel_bounds(cells, 1.0)
	var available := Vector2(
		maxf(size.x - BOARD_PADDING * 2.0, 1.0),
		maxf(size.y - BOARD_PADDING * 2.0, 1.0)
	)
	var safe_size := Vector2(
		maxf(unit_bounds.size.x, 0.001),
		maxf(unit_bounds.size.y, 0.001)
	)
	var fit_scale := minf(
		available.x / safe_size.x,
		available.y / safe_size.y
	)
	var hex_size := clampf(fit_scale * 0.92, MIN_HEX_SIZE, MAX_HEX_SIZE)
	var origin := size * 0.5 - unit_bounds.get_center() * hex_size
	return {
		"hex_size": hex_size,
		"origin": origin,
	}
