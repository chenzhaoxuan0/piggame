# 资产合成与建模记录

更新：2026-11-02。当前完成 **1 / 14 件核心 Lux3D 模型**（PROP_01 吊厢），全量建模尚未完成。六个角色与电棍的主体图任务已经提交，后续读取被自动审批服务故障阻断；不要重复提交这些任务。

## 已交付

- PROP_01：概念图 → 无背景主体 → Lux3D G1-Turbo → Blender 清理 → Godot 场景，完整链路已实际执行。
- 原始模型 19,708 三角面；引擎模型 4,156 三角面、约 132 KiB；无纹理依赖，木色与铁色纯色材质。
- 生成器遗漏悬挂机构：保留生成的吊厢外壳，在 Blender 补建悬杆和两只滑轮，校正大小至约 3.2 × 4.12 × 2.6 米（Godot XYZ）。这部分是明确记录的后处理，不冒充模型原始生成结果。
- 模型挂在 `Farm/CableCarCabin`，跟随原有 Tween；钢缆方向与位移 `(0, 2, -22)` 对齐。
- 角色、道具可按同一资产库接入；白名单 `runtime_catalog.json` 未验收条目不会替换几何体。碰撞、交互根、追逐判定和状态机保持原契约。
- 七张对话头像、两张结局插画接入现有界面；结局界面移除开发进度文案。

## 核心资产与挂点

| ID | 名称 | 场景挂点/位置 | 当前状态 |
| --- | --- | --- | --- |
| CHAR_01 | 猪包子 | Pig/VisualMesh；口部独立插销 | 第二轮主体任务 4566410 待回收，尚无模型 |
| CHAR_02 | 老岩羊 | Farm/NPC_goat；(-3, 0, 83.5) | 第二轮主体任务 4566414 待回收，尚无模型 |
| CHAR_03 | 老黄牛 | Farm/NPC_ox；(-9, 0, 51) | 第二轮主体任务 4566418 待回收，尚无模型 |
| CHAR_04 | 小绵羊 | Farm/NPC_sheep；(-12, 0, 9.5) | 第二轮主体任务 4566424 待回收，尚无模型 |
| CHAR_05 | 追风 | Farm/NPC_horse；(16, 0, -28) | 主体 4566359 已验收；建模未提交 |
| CHAR_06 | 护院犬 | ChaseDog 的独立视觉根；动态生成 | 主体任务 4566438 待回收，尚无模型 |
| CHAR_07 | 农场主 | Farm/NPC_farmer；(5, 0, -87.5) | 主体任务 4566442 待回收，尚无模型 |
| PROP_01 | 木吊厢 | Farm/CableCarCabin；(0, 0, -104) | 已生成、后处理、导入并走通结局 |
| PROP_02 | 铁闸门 | Farm/Gate；(0, 0.9, -90) | 第一轮包含石柱/写实材质，拒收；修正未执行 |
| PROP_03 | 红铜插销 | Pig/VisualMesh；(0, 0.55, -0.9) | 第一轮纹理偏写实，拒收；修正未执行 |
| PROP_04 | 顽石与犁 | Farm；(-12, 0, 51.5) | 第一轮纹理偏写实，拒收；修正未执行 |
| PROP_05 | 评定吊牌 | NPC_sheep；任务完成隐藏、重置恢复 | 第一轮纹理偏写实，拒收；修正未执行 |
| PROP_06 | 纪录牌 | Farm/RecordBoard；(3, 1, -20) | 第一轮纹理偏写实，拒收；修正未执行 |
| PROP_07 | 电棍 | NPC_farmer；破门后隐藏 | 主体任务 4566449 待回收，尚无模型 |

正式生成任务编号：PROP_01 = **4566276**。所有提示词、源图路径、SHA-256 和生成参数见 `assets/models/aholo/production.json`。该文件不含密钥或短期签名 URL。

## 环境资产范围

现有农场程序几何继续承担场景组装，不能把环境原画整张交给图生 3D。以下环境尚未进行全量 Lux3D 构件制作：

| 原画 ID（以当前文件为准） | 场景用途 | 当前实现 |
| --- | --- | --- |
| ENV_01 | 悬崖猪圈 | 现有地形/栏杆/食槽几何 |
| ENV_02 | 蓝线泥窝结局 | 已接入结局插画；无新 3D 场景 |
| ENV_03 | 黑土垄 | 现有田垄、谷仓、水槽几何 |
| ENV_04 | 剪毛棚 | 现有木棚、羊毛堆几何 |
| ENV_05 | 泥圈赛道 | 现有围栏与椭圆赛道几何 |
| ENV_06 | 开阔地 | 现有障碍、追逐空间几何 |
| ENV_07 | 铁门与索道口 | 保留门碰撞与索道挂点；仅吊厢已替换 |
| ENV_08 | 金色麦浪与旷野 | 已接入结局插画；现有远山几何 |

注意旧 `docs/art/README.md` 只列了部分 ENV 项，且 ENV_02 曾指旷野；目前实际文件中 ENV_02 为蓝结局、ENV_08 为红结局，不要按旧清单误配。

## 验证

- 原白模实机回归：UI 选项走蓝结局；重开后使用模拟正常键盘输入穿过全部区域、零技能追逐、E 交互、三轮对决、索道红结局。未改游戏状态或瞬移完成此项。
- 吊厢替换后再次在实际渲染进程走通相同路线，所有检查通过。
- 状态回归 168 项通过；农场碰撞/交互回归 22 项通过；资产材质/挂点/白名单检查 29 项通过；追逐物理测试通过。
- Godot 4.3 的 headless dummy renderer 在释放旧几何时产生 `Parameter m is null`，基线也存在；本次实际渲染流程另行验证，不能将 headless 单独作为画面验收。
- 受限运行环境还报告系统根证书读取和 GLES3 shader cache 写入失败；渲染截图和完整路线仍完成，日志保留在 `builds/`。这些警告不等于模型验收失败，也未计为修复。
- 未验证：其他 13 件模型、角色骨骼动画、全环境正式模型、导出发行包、目标设备稳定 60fps。当前程序摇摆动画仍是程序动画。

## 续跑

先修复 Codex 自动审批服务。当前错误为两次审批超时，随后 `502 Bad Gateway / Upstream access forbidden`；失败的命令没有执行。这不是 Lux3D 密钥错误，也不是安全判定，不能换通道绕过审批。

1. 回收已经提交的主体任务：
   `python scripts/art/produce_assets.py collect-inputs CHAR_01 CHAR_02 CHAR_03 CHAR_04 CHAR_06 CHAR_07 PROP_07`
2. 逐张目检：单一物体、完整轮廓、白/透明背景、无投影、1:1、原有低模平涂风格。拒收记录不能通过 `approve-input`。
3. 对 PROP_02–06 各执行一次 `revise-input`；这五次修正此前未被执行。第二轮仍不合格时停止继续重抽，保留记录再调整方案。
4. 审核合格后 `approve-input ID`，再 `generate ID`。建议最多五个并发；并发上限报错后先回收，不重复已有任务。
5. `collect-models` 下载原件；任务已有 ID 时脚本不会重新生成。
6. Blender 后处理：
   `blender --background --factory-startup --python scripts/art/process_models.py -- ID`
   该脚本仅在 PROP_01 验证过；其他资产的正面、尺寸、眼睛、文字、细部须逐件校正。不把模板输出视为自动验收。
7. 铁门需要独立 `GateLeft` / `GateRight` 枢轴后才启用双扇旋转；未拆分时沿用消失开门。文字可由 Godot Label3D 保证可读。角色尚未绑骨。
8. 只有实机确认后，加入 `runtime_catalog.json` 的 `accepted: true`。`yaw_degrees` 统一角色面向 -Z；文件底部 y=0，1 单位=1 米。

复现测试（项目自带引擎在 `.tools/godot-4.3/`）：

```powershell
godot --headless --path . --editor --import --log-file builds/import.log
godot --headless --path . --script tests/state/test_demo_state.gd --log-file builds/state.log
godot --headless --path . --script tests/scene/test_farm_grounds.gd --log-file builds/farm.log
godot --headless --path . --script tests/scene/test_art_assets.gd --log-file builds/art.log
godot --headless --path . --script tests/chase/test_chase_physics.gd --log-file builds/chase.log
godot --path . --script tests/scene/test_full_journey.gd --log-file builds/journey.log
```

脚本默认不阻塞等待云端长任务；用 taskId 回收。请求结果先落 `builds/lux3d/`，防止进程中断后重复付费；生产清单使用原子写入与单进程锁。不要提交 `.env`。

## 本地交付与提交状态

当前改动保留在 `piggame` 工作区（基线提交 `9e4b1d0`）。`git add` 因无法创建 `.git/index.lock`（Permission denied）未执行成功，因此本轮**尚无本地 commit**，也没有推送。审批服务恢复后，只暂存本轮清单中的文件，再提交；不要夹带其他会话修改。

可查看 `assets/art_references/props/PROP_01_Godot.png`、`assets/art_references/ui/dialogue_portrait_in_game.png`、`assets/art_references/ui/ending_escape_in_game.png`。原始 ZIP/GLB、引擎 GLB 与预览图都保留在 `assets/models/aholo/PROP_01/`。
