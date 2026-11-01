# 白模展示版：首轮集成契约

> 2026-11 更新：主场景已切换为美术一版 `scenes/levels/farm/farm_grounds.tscn`（scripts/levels/farm_grounds.gd）。
> 它保留本契约全部 API（get_spawn_position / set_gate_open / set_pigpen_open / set_npc_completed /
> get_cablecar / reset_world / chase_entered），新增常量 CHASE_EXIT_Z、RETRY_POSITION、CABLECAR_TRAVEL
> 供主控使用；旅程布局 x=-46..46、z=+102..-108：猪圈→路线→耕作区→路线→剪毛棚→路线→泥圈赛道→路线→
> 开阔地（追逐）→铁门→索道旷野，区域由带缺口分界栅栏分隔，路线为两侧围合走廊。
> 白模场景 farm_greybox 仅保留给 headless 测试使用。

本轮只做程序与几何白模，不创建正式美术或调用 Lux3D。主控管理根场景、项目配置、UI 与集成；worker 独占各自文件，不覆盖他人修改。所有路径为 res:// 相对路径。

## 地图与场景

- Y 向上，地面顶部 y=0；角色出生 (0,0.1,18)，向 -Z 推进。
- 可行走范围 x=-10..10，z=-37..23；探索区 z=23..-5，追逐区 z=-5..-23，门 z=-25，索道 z=-33。
- NPC/交互体为 StaticBody3D，加入 interactable 组，元数据 interaction_id：goat / ox / sheep / horse / record_board / farmer / cablecar。
- 世界静态碰撞 layer=1，玩家 layer=2 mask=1，犬 layer=4 mask=1（不挤压玩家，以距离捕获）。交互可放在世界层，点击排除自身。
- 三位 NPC 及纪录牌位于追逐入口之前；外边界封闭，门锁横跨完整通路，不能绕过。
- 白模子场景根脚本公开：get_spawn_position() -> Vector3；set_gate_open(bool)；set_pigpen_open(bool)；set_npc_completed(id:String)；get_cablecar() -> Node3D；reset_world()。
- 白模发出 chase_entered 信号（body player 进入追逐开始区）；主控只在 EXPLORING 状态响应。
- 白模根名 Greybox，主控挂到根场景；无环境灯/相机/UI 依赖；不修改主控根场景。

## GameManager（Agent A）

- stage: String = prologue / exploring / chase / showdown / cablecar_ready / ending。
- has_pin: bool；npc_completed: Dictionary；npc_met: Dictionary；has_read_record: bool；ending: String。
- signal state_changed；reset_run()；choose_red()->bool；choose_blue()->bool；complete_npc(id:String)->bool；read_record()；start_chase()->bool；retry_chase()->bool（chase -> exploring）；complete_chase()->bool；complete_showdown()->bool；can_launch_cablecar()->bool；finish_escape()->bool。
- 所有操作校验阶段，结算幂等；技能在 NPC 完成事件后才获取。无存档/平台成就需求。

## DialogueManager（Agent A）

- get_dialogue_node(key:String)->Dictionary；get_entry_for(interaction_id:String)->String。
- 字段 speaker/title/content/avatar（可为空）；options 数组，元素 text/next/event（event 可省略）。事件由主控在玩家选中该选项时处理，然后跳 next，空 next 关闭。不要在打开节点时奖励。
- 主控事件白名单：choose_red / choose_blue / complete_ox / complete_sheep / complete_horse / read_record / complete_showdown / launch_cablecar。
- 节点 ID 允许自定；入口 prologue 为 cliff_goat_intro；三回合从 ordeal_encounter；收尾回探索，不能直接跳索道。NPC 离开/重访/事后入口按状态选择。
- Main 在首次打开 NPC 后标 npc_met[id]=true。避免 get_entry_for 隐含写状态。

## PigController（Agent B）

- 保留 moved_to_target(Vector3)、reached_interactable(Node3D) 信号，后者由 E 或接近点击目标发出。
- set_control_mode(mode:String)：explore/chase 可移动，dialogue/cinematic/ending/paused 锁移动并清旧目标/速度。
- reset_at(pos:Vector3)；set_dash_enabled(bool)；get_nearest_interactable()->Node3D（供主控提示）。
- WASD 使用相机平面坐标；主控已配置 move_* / action_interact / action_dash。点击功能有防卡滞处理，无需本轮建设 NavMesh。
- 仅马完成启用 Shift；没有技能也可通过追逐。

## SimpleChase（Agent B）

- 新增 scripts/chase/simple_chase.gd，extends Node3D，class_name SimpleChase。
- signal finished(success:bool)；signal pressure_changed(distance:float)（可选）。
- start_chase(player:Node3D,spawn_positions:Array[Vector3],exit_z:float=-23.0)；stop_chase()；set_active(bool)。
- 1–2 犬几何体，跑到 exit_z 成功，被捕失败；只发一次 finished 并停止。主控处理重试 UI 与状态。犬清理使用 queue_free，不依赖正式资产。

## 所有权

- A：scripts/core/game_manager.gd、scripts/core/dialogue_manager.gd、tests/state/。
- B：scripts/characters/pig_controller.gd、scenes/characters/pig.tscn、scripts/chase/、scenes/tests/chase_test.tscn、tests/chase/。
- C：scenes/levels/greybox/、scripts/greybox/、scripts/core/isometric_camera.gd。
- 主控：其余根场景、关卡脚本、UI、project.godot、文档、打包与集成测试。

交付需包含修改文件、实际检查结果/未测项；Godot/Blender/浏览器公共 GUI 同一时刻一个操作者。主控拥有实机运行会话，workers 优先编写独立脚本与子场景。
