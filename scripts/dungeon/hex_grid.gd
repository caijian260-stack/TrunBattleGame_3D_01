class_name HexGrid
extends RefCounted

## 六边形战棋网格工具集。
##
## 坐标约定：
## - 使用轴向坐标（axial）Vector2i(q, r)，配合 pointy-top（尖角朝上）六边形布局。
## - 网格只提供纯几何与坐标运算，不保存任何迷宫状态，便于被数据模型与 UI 共用。
##
## 六个方向使用 Direction 枚举描述，任何地方都不再出现裸方向数字。

enum Direction {
	NE,
	E,
	SE,
	SW,
	W,
	NW,
}

## 与 Direction 一一对应的轴向邻居偏移。
const DIRECTION_OFFSETS: Array[Vector2i] = [
	Vector2i(1, -1),  # NE
	Vector2i(1, 0),   # E
	Vector2i(0, 1),   # SE
	Vector2i(-1, 1),  # SW
	Vector2i(-1, 0),  # W
	Vector2i(0, -1),  # NW
]

const DIRECTION_LABELS: Dictionary = {
	Direction.NE: "东北",
	Direction.E: "东",
	Direction.SE: "东南",
	Direction.SW: "西南",
	Direction.W: "西",
	Direction.NW: "西北",
}

## 环状取格时的行走顺序：从西南顶点出发，依次沿六条边前进。
const RING_WALK_DIRECTIONS: Array[int] = [
	Direction.E,
	Direction.NE,
	Direction.NW,
	Direction.W,
	Direction.SW,
	Direction.SE,
]


## 把轴向坐标序列化为稳定字符串键，用作字典索引。
static func key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


## 从 key() 生成的字符串还原轴向坐标。
static func parse_key(text: String) -> Vector2i:
	var parts := text.split(",", false)
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


static func direction_label(direction: int) -> String:
	return str(DIRECTION_LABELS.get(direction, "未知"))


static func direction_offset(direction: int) -> Vector2i:
	var index := clampi(direction, 0, DIRECTION_OFFSETS.size() - 1)
	return DIRECTION_OFFSETS[index]


## 沿指定方向取得邻居坐标（不判断该坐标是否真的存在于网格中）。
static func neighbor(cell: Vector2i, direction: int) -> Vector2i:
	return cell + direction_offset(direction)


## 返回六个邻居坐标，顺序与 Direction 枚举一致。
static func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in DIRECTION_OFFSETS:
		result.append(cell + offset)
	return result


## 两个格子之间的六边形距离（步数）。
static func distance(from: Vector2i, to: Vector2i) -> int:
	var delta := to - from
	return maxi(maxi(absi(delta.x), absi(delta.y)), absi(delta.x + delta.y))


## 以 center 为中心、半径 radius 的一圈格子（radius=0 时返回中心本身）。
static func ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	if radius <= 0:
		return [center] as Array[Vector2i]
	var results: Array[Vector2i] = []
	var current := center + direction_offset(Direction.SW) * radius
	for direction in RING_WALK_DIRECTIONS:
		for _step in range(radius):
			results.append(current)
			current = neighbor(current, direction)
	return results


## 以 center 为中心、半径 0..radius 的所有格子。
static func spiral(center: Vector2i, radius: int) -> Array[Vector2i]:
	var results: Array[Vector2i] = [center]
	for current_radius in range(1, maxi(radius, 0) + 1):
		results.append_array(ring(center, current_radius))
	return results


## 返回一条从 from 到 to 的直线格子序列（两端包含在结果中）。
static func line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	var steps := distance(from, to)
	if steps == 0:
		return [from] as Array[Vector2i]
	var start := _axial_to_cube(from)
	var end := _axial_to_cube(to)
	for index in range(steps + 1):
		var t := float(index) / float(steps)
		var cube := start.lerp(end, t)
		results.append(_cube_to_axial(_cube_round(cube)))
	return results


## 轴向坐标转屏幕像素（pointy-top）。
static func hex_to_pixel(cell: Vector2i, hex_size: float) -> Vector2:
	var x := hex_size * sqrt(3.0) * (float(cell.x) + float(cell.y) * 0.5)
	var y := hex_size * 1.5 * float(cell.y)
	return Vector2(x, y)


## 屏幕像素转轴向坐标（pointy-top），用于鼠标拾取。
static func pixel_to_hex(point: Vector2, hex_size: float) -> Vector2i:
	var safe_size := maxf(hex_size, 0.001)
	var q := (sqrt(3.0) / 3.0 * point.x - point.y / 3.0) / safe_size
	var r := (2.0 / 3.0 * point.y) / safe_size
	return _cube_to_axial(_cube_round(Vector3(q, -q - r, r)))


## 六边形的六个顶点，供 UI 绘制多边形。
static func hex_corners(center_pixel: Vector2, hex_size: float) -> PackedVector2Array:
	var corners := PackedVector2Array()
	for index in range(6):
		var angle := deg_to_rad(60.0 * float(index) - 30.0)
		corners.append(
			center_pixel + Vector2(cos(angle), sin(angle)) * hex_size
		)
	return corners


## 计算一组格子的像素包围盒，便于把棋盘居中。
static func pixel_bounds(
	cells: Array[Vector2i],
	hex_size: float
) -> Rect2:
	if cells.is_empty():
		return Rect2()
	var points := PackedVector2Array()
	for cell in cells:
		points.append_array(hex_corners(hex_to_pixel(cell, hex_size), hex_size))
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


static func _axial_to_cube(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x), -float(cell.x) - float(cell.y), float(cell.y))


static func _cube_to_axial(cube: Vector3) -> Vector2i:
	return Vector2i(int(round(cube.x)), int(round(cube.z)))


static func _cube_round(cube: Vector3) -> Vector3:
	var rounded_x: float = round(cube.x)
	var rounded_y: float = round(cube.y)
	var rounded_z: float = round(cube.z)
	var delta_x: float = absf(rounded_x - cube.x)
	var delta_y: float = absf(rounded_y - cube.y)
	var delta_z: float = absf(rounded_z - cube.z)
	if delta_x > delta_y and delta_x > delta_z:
		rounded_x = -rounded_y - rounded_z
	elif delta_y > delta_z:
		rounded_y = -rounded_x - rounded_z
	else:
		rounded_z = -rounded_x - rounded_y
	return Vector3(rounded_x, rounded_y, rounded_z)
