# 分区画风 3D 资产计划（C0 屠宰场写实 + C1-C4 各区风格）

> 事实源：`docs/COURSE_REDESIGN.md` §4.4 分区画风 + AGENTS.md §5 分区画风制。
> 本文档定义五个关卡各自的 3D 模型与渲染风格目标、资产清单与生产管线。
> 生产脚本：`scripts/art/produce_zone_assets.py`（提交/收集 Lux3D 任务）→ `scripts/art/process_zone_models.py`（Blender 加工）→ `assets/models/aholo/runtime_catalog.json`（运行时清单）。

## 1. 目标与原则

1. **画风差异化**：玩家进入每个隐藏关卡时不应猜到下一个世界的画风。角色（猪/伙伴/恶犬）恒定大鹅平涂不换装（AGENTS.md §5），环境资产按区换风格。
2. **各区风格锚定**：
   | 关卡 | 参考游戏 | 资产画风 | Lux3D style 参数 |
   |---|---|---|---|
   | C0 噩梦屠宰场 | 写实屠宰厂/工厂 | photorealistic：磨损钢材、 stained 混凝土、工业管道 | `photorealistic` |
   | C1 牛耕地 | 《糖豆人》 | 荧光综艺+大鹅平涂（已完成 13 件 PROP_C1_*，作为完成度基准） | `cartoon`（已产） |
   | C2 溪流 | 《我的世界》 | 体素方块：整块立方、像素平色 | `cartoon` + 体素提示词 |
   | C3 林间 | 童话手绘 | 柔和手绘：圆润造型、绘本笔触 | `hand_painted` |
   | C4 大院 | 《马里奥赛车》×糖豆人综艺 | 霓虹街机：糖果色、发光霓虹、玩具感 | `cartoon` + 霓虹提示词 |
3. **原资产先行落盘**（用户硬性要求）：MCP 直出无法从后台找回，任务完成后**立即**把原始导出存入
   `assets/models/aholo/<ASSET_ID>/`（`<ASSET_ID>.glb` 原始模型 + `<ASSET_ID>.png` 官方预览图），
   并在 `zone_assets_production.json` 记录 `task_id` / `prompt` / `sha256`，之后才允许加工与入游戏。
4. **完成度对齐 C1**：C1 每个场地要素都有 Lux3D 模型（13 件，含地砖/墙/机关/装饰）。C0/C2/C3/C4 按同一标准补齐清单（见 §3）。
5. **碰撞与玩法不动**：所有模型只替换**视觉**（`FarmAssets.replace_visuals` 模式），碰撞体、机关参数、寻路与实走测试不受影响。

## 2. 渲染风格管线（引擎侧）

`runtime_catalog.json` 每条新增 `style` 字段，`asset_library.gd` 按风格分支：

- `flat`（默认，C1/C2/C3）：现有 `pastoral_surface.gdshader` 平涂着色器（含 albedo 贴图）。
- `pbr`（C0 写实）：跳过着色器覆写，保留 GLB 自带 StandardMaterial3D 与 PBR 贴图，响应区环境光照。
- `neon`（C4 霓虹）：平涂底 + 从贴图亮度提取发光（shader 新增 `emission_from_texture` 参数），霓虹部件自发光。

Blender 加工（`process_zone_models.py`）按风格区分材质处理：
- `flat`：同 C1（Roughness=1、金属度 0、断开法线贴图）。
- `pbr`：保留 Roughness/Metallic 贴图（写实质感），仅归一化变换与缩放。
- `neon`：Roughness=1、金属度 0，另把高饱和度主色烘焙进贴图亮度（发光在 shader 侧提取）。

## 3. 资产清单（各区）

> 尺寸为 Godot 世界尺度（米）。`target_*` 见 `produce_zone_assets.py` 的 SPECS。
> 提示词模板沿用 course_production.json 已验证格式：单体、无地面、无背景、无投影、完整基座。

### C0 噩梦屠宰场（写实，14 件）
| 资产 ID | 用途 | 目标尺寸 (X,Y,Z) | 数量/落位 |
|---|---|---|---|
| ENV_C0_FLOOR | 混凝土地砖（污渍、伸缩缝） | 4×0.2×4 铺装 5 块地坪 | ~90 片 |
| ENV_C0_WALL | 工业墙板（钢材+混凝土、踢脚线） | 4×4.2×0.4 沿墙线布置 | ~60 段 |
| PROP_C0_CAGE | 牲畜笼架（竖杆钢笼） | 5×1.6×2.4 | 圈栏 4 座 |
| PROP_C0_CONVEYOR | 皮带输送机段（机架+滚筒） | 与 belt_size 匹配 | 4 条带 |
| PROP_C0_MEATHOOK | 吊钩链条（摆锤端） | 高 1.7 | 4 处 MeatHook |
| PROP_C0_STEAM_VENT | 地面蒸汽格栅 | 1.6×0.3×1.6 | 4 处 SteamVent |
| PROP_C0_STUN_PROD | 电击立柱（黄黑警示） | 1.2×1.5×1.2 | 2 处 StunProd |
| PROP_C0_CRATE | 出货木箱 | 2×1.6×2 | 月台 4 箱 |
| PROP_C0_ROLLER_DOOR | 卷帘铁门（出口） | 10×4.2×0.5 | 出口 1 |
| PROP_C0_PAINTED_DOOR | 画着太阳的假门（褪色油彩） | 2.4×3.2×0.4 | L3 尽头 1 |
| ENV_C0_MACHINERY | 墙面机械组（管道/电箱/阀门） | 3×3×0.8 | 氛围件 ×8 |
| PROP_C0_HAZARD_SIGN | 悬挂警示牌 | 1.6×1.2×0.1 | 氛围件 ×6 |
| PROP_C0_PEN_FENCE | 圈栏铁门柱+横梁 | 0.5×4.2×0.5 / 梁一体 | 门框 2 竖 1 横 |
| PROP_C0_HURDLE | 低跳栏（教学跨栏） | 11.2×0.55×0.5 | 2 处 |

### C2 溪流（体素，13 件）
| 资产 ID | 用途 | 目标尺寸 | 落位 |
|---|---|---|---|
| ENV_C2_GRASS_BLOCK | 草方块（顶绿侧土） | 4×1×4 | 3 块草地平台铺装 |
| ENV_C2_STONE_BLOCK | 圆石方块 | 4×1×4 | 悬崖/峡谷地坪铺装 |
| ENV_C2_CANYON_WALL | 峡谷岩壁 | 4×6×2 | 峡谷两侧 + 咽喉岩肩 |
| PROP_C2_MOSSY_STONE | 苔石墩 | 1.6×0.7×1.3 | 3 处跳墩 |
| ENV_C2_OAK_TREE | 体素橡树（干+叶立方） | 3.2×7×3.2 | ×6 |
| PROP_C2_NETHER_PORTAL | 黑曜石门框+紫色漩涡门芯 | 6×7.2×1.2 | 出口 1 |
| PROP_C2_TNT | TNT 方块 | 1.8³ | 推箱谜题 |
| PROP_C2_DIRT_BLOCK | 泥土方块（可推） | 1.8³ | 推箱谜题 ×2 |
| PROP_C2_SAND_BLOCK | 重力沙方块 | 1.8³ | 埋狗谜题 |
| PROP_C2_SLIME_BLOCK | 黏液弹方块 | 1.8³ | ×2 |
| PROP_C2_PRESSURE_PLATE | 石质压力板 | 1.8×0.2×1.8 | ×1 |
| PROP_C2_SWEET_POTATO | 像素红薯拾取物 | 0.5³ | 台阶 ×3 |
| PROP_C2_OBSIDIAN_WALL | 黑曜石墙块 | 10×4×1.2 | ×1 |

### C3 林间（童话手绘，13 件）
| 资产 ID | 用途 | 目标尺寸 | 落位 |
|---|---|---|---|
| ENV_C3_MEADOW_TILE | 草地花径地砖（手绘草花） | 4×1×4 | 4 块平台铺装 |
| ENV_C3_GOLD_TILE | 金色花圃地砖 | 4×1×4 | 宝箱广场 |
| ENV_C3_PURPLE_TILE | 紫藤秘径地砖 | 4×1×4 | 幻墙后秘径 |
| ENV_C3_TREE | 童话大树（圆润树冠） | 4×9×4 | ×10 |
| PROP_C3_TOADSTOOL | 波点红蘑菇 | 1.8×1.4×1.8 | 装饰 ×4 + 弹力蘑菇 ×1 |
| PROP_C3_CHEST | 宝箱（绘本描金木箱） | 1.4×1.1×1.0 | 宝箱怪 ×4 |
| PROP_C3_MAZE_WALL | 苔藓石墙（爬藤） | 6×2.4×0.8 | 迷宫墙 A-F |
| PROP_C3_HOLLOW_TREE | 空心神木门（出口） | 6.6×7.3×1.4 | 出口 1 |
| PROP_C3_CARDBOARD_BOX | 纸箱（可穿） | 1.6×1.6×1.6 | 潜行道具 |
| PROP_C3_GOLDEN_PINECONE | 金松果 | 0.5³ | 投掷道具 |
| PROP_C3_ILLUSORY_WALL | 幻影石壁（微光） | 10×4.5×0.8 | ×2 |
| PROP_C3_BOUNCY_MUSHROOM | 巨型弹力蘑菇 | 2.4×2.2×2.4 | 广场 ×1 |
| ENV_C3_BUSH | 灌木丛 | 1.6×1.2×1.6 | 氛围 ×8 |

### C4 大院（霓虹综艺，15 件）
| 资产 ID | 用途 | 目标尺寸 | 落位 |
|---|---|---|---|
| ENV_C4_ASPHALT | 柏油赛道砖（霓虹边线） | 10×1×10 | 赛道路面铺装 |
| ENV_C4_GRAVEL | 内场沙砾地砖 | 10×1×10 | 内场 ×2 |
| PROP_C4_GUARDRAIL | 霓虹护栏段 | 4×1.2×0.4 | 护栏 ~17 段 |
| PROP_C4_BOOST_PAD | 加速带（黄色箭头） | 3.5×0.1×3.0 | ×7 |
| PROP_C4_TIRE | 巨型滚胎 | 1.6×1.6×1.6 | ×1 |
| PROP_C4_TRAFFIC_CONE | 交通锥 | 0.5×0.7×0.5 | ×5 |
| PROP_C4_SWEEPER | 霓虹扫堂腿杆 | 7.6×0.36×0.36 | 氮气隧道 ×2 |
| PROP_C4_NEON_SIGN | 霓虹招牌摆锤 | 2.4×2×0.3 | ×1 |
| PROP_C4_ITEM_BOX | 问号道具箱 | 1.3³ | ×3 |
| PROP_C4_STUNT_RAMP | 特技大跳台 | 6×2.2×6 | ×1 |
| PROP_C4_BUMPER | 霓虹弹柱 | 1.6×1.5×1.6 | ×4 |
| PROP_C4_FINISH_GATE | 终点门（横幅） | 10×5.5×1 | ×1 |
| PROP_C4_START_GANTRY | 起点门架（信号灯） | 10×4.6×0.6 | ×1 |
| PROP_C4_STADIUM_LIGHT | 泛光灯塔 | 1.2×6.8×0.8 | ×9 |
| PROP_C4_TIRE_STACK | 轮胎堆 | 1.4×1.2×1.4 | ×6 |

### C1 牛耕地（基准，已达标）
13 件 PROP_C1_* 已覆盖全部场地要素（地砖/墙/弹柱/铁锤/摆锤/门/水管/弹板/扫杆/草垛/假桥/问号砖/终点门）。
本任务仅在接入测试中发现缺口时补件。

## 4. 生产流程（对齐既有 C1 管线）

1. `python scripts/art/produce_zone_assets.py submit [--zone C0]` — 走 `lux3d_client.mjs` → `lux3d_text_to_3d`（`G1-Turbo`, faceCount 10000–20000, `enablePbr=true`, zip+glb 双格式）。
2. `python scripts/art/produce_zone_assets.py collect [--zone C0]` — 轮询 `lux3d_get_task`，**完成后第一时间落盘原资产**（§1.3），记录 manifest。
3. `blender --background --python scripts/art/process_zone_models.py -- <ASSET_ID>...` — 归一化/缩放/减面/风格材质 → `<ID>_game.glb`。
4. `python scripts/art/produce_zone_assets.py catalog [--zone C0]` — 更新 `runtime_catalog.json`（含 `style`）。
5. Godot 无头渲染预览核对；关卡脚本接入模型（视觉替换、碰撞不动）。
6. `run_tests.bat` 全绿后按提交纪律分 commit。

## 5. 验收标准

- [x] 五个关卡每个场地要素有对应 3D 模型（C0 14 件 / C1 13 件基准 / C2 13 件 / C3 13 件 / C4 15 件，共 68 件）。
- [x] 原始资产已落盘 `assets/models/aholo/<ID>/` 且 manifest 可回溯（task_id/prompt/sha256，`zone_assets_production.json`）。
- [x] 渲染风格按区分化：实机截图核对（`builds/zone_screens/`，capture_zone_screens.gd 抓帧）——C0 写实锈蚀钢构 / C1 荧光平涂（基准）/ C2 体素方块 / C3 手绘童话 / C4 霓虹街机，同一口猪穿行其间。
- [x] `run_tests.bat` 全绿（含 5 关 traversal 实走 + journey）。
- [x] PackCheck 导出包校验通过（407 MB，55 个新 game GLB 已登记 export_files）。
