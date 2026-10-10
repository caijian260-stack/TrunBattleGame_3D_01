# 通用回合制战斗、固定视角 2D RPG 与副本秘境

这是一个 Godot 4 项目，包含三套可互相衔接的系统：

- 由 `BattleEngine` 状态机驱动的回合制战斗与 QTE 判定系统。
- 由 `RPGScene` 父类驱动的固定视角 2D 背景场景、NPC 对话、点击互动与遭遇系统。
- 由 `DungeonScene` 编排的六边形战棋副本秘境，支持掷骰移动力、随机事件、
  炼器 / 炼丹材料、法宝机缘、任务线索与战斗快照恢复。

主场景 `res://scenes/main.tscn` 是剑宗山门 RPG 场景。玩家可以调查场景对象、
与 NPC 对话、通过传送门前往云台、从对话进入战斗，或点击秘境入口进入
`res://scenes/mystic_realm.tscn`。秘境中的战斗结束后会恢复原层进度。

## 场景基类体系

所有玩法场景共用 `BaseGameScene`：

```text
BaseGameScene
├── RPGScene
│   ├── JianzongScene
│   └── CloudTerraceScene
└── DungeonScene
```

`BaseGameScene` 负责场景 ID、命名出生点、`SceneFlow` 跨场景上下文、场景切换、
进入战斗和通用提示 HUD。具体玩法只需覆写 `_configure_scene()`、
`_build_scene_ui()`、`_build_concrete_scene()` 与 `on_scene_ready()` 等模板钩子。

## RPG 场景系统

场景系统采用继承式面向对象设计：

```text
RPGScene
├── JianzongScene
└── CloudTerraceScene

SceneInteractable
├── SceneNPC
├── ScenePortal
└── SceneInspectable
```

- `RPGScene`：所有地图的父类。统一负责 2D 背景绘制、互动物注册、对话 UI、提示信息、出生点和场景切换。
- 具体场景覆写 `_configure_scene()`、`_draw_scene_background()` 与 `_build_concrete_scene()`。前者声明场景 ID、出生点和氛围，中者用相对坐标绘制程序化背景，后者布置贴图、建模节点与互动物。
- `SceneInteractable`：所有互动物父类，基于 `Control` 使用锚点定位，提供统一的启用状态、可点击区域、悬停高亮、名称标签和 `interact()` 接口。
- `SceneNPC`：持有 `DialogueData`，互动时由所在 `RPGScene` 打开对话面板。
- `ScenePortal`：保存目标场景与出生点 ID，通过 `change_to_scene()` 完成地图切换。
- `SceneInspectable`：显示调查文本，也可挂载自己的 `DialogueData`。

### 场景操作

场景为固定视角，没有任何可操控角色，也没有移动或转视角输入。

- 鼠标移动：悬停到互动物上时高亮并显示互动提示。
- 鼠标左键：点击 NPC 打开对话，点击调查物查看说明，点击传送门切换地图。
- `Esc`：关闭当前对话。

### 场景构建 API

具体场景继承 `RPGScene` 后，可在 `_build_concrete_scene()` 中使用父类 API：

- `add_scene_texture()`：按相对矩形放入场景贴图、壁画、告示等 `Texture2D`。
- `place_scene_node()`：把 `Node2D` / `Polygon2D` / `Sprite2D` 等 2D 建模节点放到相对锚点上。
- `place_scene_control()`：按相对矩形放置任意 `Control`。
- `draw_relative_rect()`、`draw_relative_circle()`、`draw_relative_ellipse()`、`draw_relative_polygon()`、`draw_relative_line()`：在 `_draw_scene_background()` 中用 0~1 归一化坐标绘制程序化背景。
- `add_child()`：直接挂载 NPC、传送门、调查物等互动物子类。
- `register_spawn_point()`：注册命名出生点，供传送门和战斗返回使用。

新增地图时继承 `RPGScene`，实现两个场景钩子，再创建对应的 `.tscn` 根节点绑定脚本即可。新增互动物类型时继承 `SceneInteractable`，覆写 `_configure_interactable()`、`_build_visual()` 和 `interact()`。

### 场景与战斗流程

`SceneFlow` 是 `project.godot` 中注册的自动加载节点，用于保存跨场景临时状态：

1. `RPGScene.enter_battle()` 保存当前场景与遭遇数据（2D 场景不含玩家坐标）。
2. `battle_ui.gd` 读取 `SceneFlow.encounter_data` 中的遭遇信息。
3. 战斗结束或逃走后显示“返回场景”按钮。
4. 返回时通过 `SceneFlow.take_battle_return()` 回到原地图。
5. 传送门通过 `change_to_scene(path, spawn_id)` 进入目标场景的命名出生点。
6. 秘境遭遇战斗前通过 `set_dungeon_state()` 保存 `DungeonMaze.snapshot()`；
   战斗返回 `mystic_battle_return` 出生点时恢复同一层迷宫、位置和移动力。

场景 `.tscn` 的关系：

- `scenes/main.tscn`：剑宗山门，入口场景。
- `scenes/cloud_terrace.tscn`：云台，可从剑宗传送进入。
- `scenes/mystic_realm.tscn`：副本秘境，可从剑宗秘境入口进入。
- `scenes/battle.tscn`：复用原战斗 UI，可被任意 RPG 场景启动并返回来源场景。
- `scenes/battle_2d.tscn`：纯 Control 2D 战斗场景，使用 `BattleScene2D` 父类。

`tests/test_scene.gd` 覆盖场景父类、具体场景、互动物继承、对话动作和跨场景上下文。

## 副本秘境系统

秘境采用六边形战棋移动迷宫。每层生成 19 格轴向六边形网格，并用深度优先算法
生成连通迷宫；未打通的相邻格不可跨越。

```text
DungeonScene（场景编排）
├── DungeonMaze（规则与状态）
├── DungeonBoardView（六边形棋盘表现与鼠标输入）
├── HexGrid（轴向坐标、方向与寻路基础）
└── DungeonDice（骰子表达式、投掷与快照）
```

- `HexGrid.Direction`：六边形方向枚举，统一 NE / E / SE / SW / W / NW 偏移。
- `DungeonDice.Face`：D4 / D6 / D8 / D10 / D12 / D20 骰面枚举，默认移动骰为 1D6。
- `DungeonMaze.EventType`：入口、出口、战斗、炼器材料、炼丹材料、法宝机缘、
  任务线索、陷阱和灵泉。
- `DungeonMaze.RewardType`：炼器材料、炼丹材料、法宝、任务线索、灵石的统一奖励记录。
- `DungeonMaze`：负责随机事件布置、移动合法性、移动力消耗、事件首次结算、
  奖励汇总、敌人属性成长和快照序列化，不依赖任何 UI。
- `DungeonBoardView`：只负责绘制六边形、通道、事件图标、可达格高亮和点击转换。
- `DungeonScene`：只负责按钮、状态栏、事件日志、奖励汇总、战斗跳转和返回恢复。

每层保底生成炼器材料、炼丹材料和法宝机缘事件，其余格子从随机事件池中抽取。
点击高亮格会沿唯一通道路径移动；遭遇战斗时先保存快照，再进入既有 3D 战斗。
抵达出口后可深入下一层，层数提高会提升秘境敌人生命与攻击。

## QTE 系统

玩家使用技能或神通时进入 `State.QTE`，由 UI 采集判定档位后再进入 `State.RESOLVING` 结算。普通攻击和职业特殊行动不触发玩家行动 QTE。敌人攻击则会按技能类型下发应对 QTE。

- `BattleQTE.TaskType`：玩家行动与敌人攻击共用的任务类型枚举。当前敌人只使用闪避 A、闪避 B 和格挡反击三类，行为名称全部通过枚举与标签表提供。
- `BattleQTE.Grade`：完成度三档 `FAILURE`(1) / `SUCCESS`(2) / `PERFECT`(3)。
- `BattleQTE.Source`：区分 `PLAYER_ACTION`（玩家行动判定）与 `ENEMY_ATTACK`（敌人攻击下发）。
- `BattleQTE.TASK_PROFILES`：集中配置每种任务的时长、完美窗口与成功窗口，UI 判定条按同一份配置绘制。

反馈规则：

- 玩家行动：`player_effect_multiplier()` 给失败、成功、完美三档不同倍率，技能结算统一接收 `qte_grade` 参数并按结果取不同效果。
- 闪避 A / 闪避 B：失败承受伤害，成功完全免伤，完美完全免伤并恢复 1 点 AP。
- 格挡反击：失败承受伤害，成功完全免伤，完美完全免伤、触发职业隐藏反击技并恢复 1 点 AP。
- QTE 支持鼠标点击与空格键触发。

## 属性枚举

`BattleAttribute.Type` 统一表示 `HP` / `AP` / `AT` / `ATTACK`，界面与提示文案都通过 `BattleAttribute.label()` 取显示名。后续要把“AP”“行动力”等改成别的叫法，只改 `BattleAttribute.DEFAULT_LABELS` 即可，战斗逻辑不受影响。

## 运行

用 Godot 4.7 打开本项目并运行主场景 `res://scenes/main.tscn`。项目采用 GL Compatibility 渲染方式。

场景系统与战斗系统可分别运行无界面测试：

```powershell
& 'D:\Godot\editor\Godot.exe' --headless --path 'D:\codex\Godot\TrunBattleGame_3D_01' --script 'D:\codex\Godot\TrunBattleGame_3D_01\tests\test_scene.gd' --log-file 'D:\codex\Godot\TrunBattleGame_3D_01\.godot\test_scene.log'

& 'D:\Godot\editor\Godot.exe' --headless --path 'D:\codex\Godot\TrunBattleGame_3D_01' --script 'D:\codex\Godot\TrunBattleGame_3D_01\tests\test_battle.gd' --log-file 'D:\codex\Godot\TrunBattleGame_3D_01\.godot\test.log'

& 'D:\Godot\editor\Godot.exe' --headless --path 'D:\codex\Godot\TrunBattleGame_3D_01' --script 'D:\codex\Godot\TrunBattleGame_3D_01\tests\test_dungeon.gd' --log-file 'D:\codex\Godot\TrunBattleGame_3D_01\.godot\test_dungeon.log'
```

## 目录

- `scripts/core/battle_engine.gd`：通用状态机与战斗结算。
- `scripts/core/battle_unit.gd`：通用战斗单位，只持有通用资源。
- `scripts/core/battle_attribute.gd`：战斗属性枚举与统一显示名。
- `scripts/core/battle_qte.gd`：QTE 任务类型 / 结果档位 / 时序窗口与通用倍率。
- `scripts/core/battle_command.gd`：指令描述，供 UI 和引擎读取。
- `scripts/core/battle_menu.gd`：主行动菜单与视图的枚举、默认中文标签。
- `scripts/core/scene_flow.gd`：跨场景入口与战斗返回上下文。
- `scripts/core/scene_interactable.gd`：所有场景互动物的父类。
- `scripts/core/dialogue_data.gd`：与具体 NPC 解耦的对话节点和选项数据。
- `scripts/scenes/base_game_scene.gd`：所有 RPG、战斗入口和秘境场景的公共父类。
- `scripts/classes/character_class.gd`：职业层基类与引擎契约。
- `scripts/classes/enemy_class.gd`：敌人基类，负责下发 QTE 任务并应用判定结果。
- `scripts/classes/sword_cultivator.gd`：剑修职业实现。
- `scripts/classes/training_dummy.gd`：训练假人，按下发类型应用敌人攻击 QTE。
- `scripts/scenes/rpg_scene.gd`：所有 RPG 地图的父类。
- `scripts/scenes/jianzong_scene.gd`：剑宗山门具体场景。
- `scripts/scenes/cloud_terrace_scene.gd`：云台具体场景。
- `scripts/scenes/interactables/scene_npc.gd`：对话 NPC 子类。
- `scripts/scenes/interactables/scene_portal.gd`：场景传送门子类。
- `scripts/scenes/interactables/scene_inspectable.gd`：调查物子类。
- `scripts/dungeon/hex_grid.gd`：六边形轴向坐标、方向枚举与几何工具。
- `scripts/dungeon/dungeon_dice.gd`：秘境骰子枚举、投掷与快照。
- `scripts/dungeon/dungeon_maze.gd`：秘境生成、移动、事件、奖励和快照规则。
- `scripts/dungeon/dungeon_board_view.gd`：六边形棋盘绘制与鼠标输入。
- `scripts/dungeon/dungeon_scene.gd`：秘境 UI 编排、战斗跳转与返回恢复。
- `scripts/ui/battle_ui.gd`：3D 战斗场景控制、HUD 与引擎信号连接。
- `scripts/ui/battle_scene_2d.gd`：2D 战斗场景父类，负责战场绘制、按钮菜单、QTE 和战斗流程。
- `scripts/ui/battle_2d_scene.gd`：默认 2D 战斗子类，绑定 `scenes/battle_2d.tscn`。
- `scripts/ui/battle_unit_visual_3d.gd`：可复用的 3D 单位表现层，只读取通用战斗数据。
- `scripts/ui/battle_radial_menu.gd`：圆盘行动菜单，负责展示条目并回传稳定 ID。
- `scripts/ui/dialogue_panel.gd`：通用对话 UI，只读取 `DialogueData` 并回传选项动作。
- `tests/test_scene.gd`：RPG 场景与互动物继承体系的无界面自动化测试。
- `tests/test_battle.gd`：无界面自动化测试。
- `tests/test_dungeon.gd`：六边形网格、骰子、秘境规则、棋盘与场景流程测试。

## 扩展职业

新增职业只需继承 `CharacterClass`，分别实现 `build_attack_command()`、`build_skill_commands()`、`build_class_action_commands()`、`build_ultimate_command()` 与 `resolve_command()`。职业独立菜单名通过 `get_class_action_menu_name()` 提供，神通按钮名通过 `get_ultimate_menu_name()` 提供；未装配神通时 UI 自动回退到 `BattleMenu` 中的默认“神通”标签。引擎不读取任何职业技能私有字段，因此不会绑定剑修。

新增敌人只需继承 `EnemyClass`，覆写 `get_qte_task_type()` 描述每条攻击下发的 QTE 类型，并在 `resolve_enemy_attack()` 里调用 `perform_enemy_attack()` 完成结算即可自动获得伤害倍率、完美反击与 AP 奖励。玩家职业若要自定义行动 QTE，覆写 `build_qte_task()`，技能效果通过 `resolve_command(..., qte_grade)` 读取档位即可。
