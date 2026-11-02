# 农牧场环境重构

2026-11-02。以 ENV_01 悬崖猪圈原画为近景造型和色彩依据，以《Untitled Goose Game》为克制、清晰的游戏画面方向。

渲染风格由五项共同决定：环境轮廓与结构、材质色板、光照与阴影、镜头构图、场景物件的密度及用途。仅把材质设为 Toon 无法让矩形地台和球形树冠成为农场。

本轮范围：重建猪圈、耕地、剪毛棚、马场、作业院、铁门和索道周边；改造连接道路、树篱、石墙、水沟、植被、悬崖和远景。既有 Lux3D 角色、道具及故事交互继续使用。新增环境为按概念图手工编写的模块化几何，不冒充云端生成模型。

视觉约束：哑光纯色、无写实纹理、无泛光、低饱和草绿/灰蓝石/暖木/深土、区域地标清晰。石墙有砌块、棚屋有木板梁柱和屋顶、田地有垄沟、赛道有环形路面与起终点。镜头保留正交视角并降低俯角，角色与可交互处不能被屋顶遮住。

## 实现

| 环节 | 事实源 | 本轮实现 |
| --- | --- | --- |
| 场景结构 | `scripts/art/pastoral_environment.gd` | 分区手工几何；按 20 米空间格分批；烘焙为 `assets/environments/pastoral_farm.scn` |
| 纯色与光影 | `scripts/art/pastoral_surface.gdshader` | 无纹理、无高光；限定亮部与阴影明度，阴影带冷色；低于地表的山谷有淡灰紫空气色 |
| 角色一致性 | `scripts/art/asset_library.gd` | 保留原模型的材质颜色，以共享 ShaderMaterial 接入相同着色；不修改 GLB 原件 |
| 主光与阴影方向 | `scenes/levels/office_level_1.tscn` | 单一方向光；近景阴影距离 65 米；修正阴影偏移避免条纹 |
| 构图 | `scripts/core/isometric_camera.gd` | 正交 size=16，偏移 (10, 10.5, 14)，比旧版降低俯视角，使墙、梁和悬崖侧面可见 |
| 边缘 | `project.godot` | Compatibility 渲染，4× MSAA |

固定美术主光下，shader 自行限定明暗幅度；太阳旋转控制投影方向。`illumination` 的两个值、冷暖 `tint`、环境源文件的颜色常量分别控制对比度、阴影色和物体配色。没有用噪声贴图、全屏滤镜或写实 PBR 增加细节。

环境轮廓、土路、砌块墙、棚屋木板和梁柱、田垄、水渠、桥板、喂食架、提桶、围栏、马厩、起跑线、农机棚、树篱、麦田与崖下远景均为实几何。水面和薄雾采用纯色平面，薄雾只在谷底；当前没有体积雾或动态水面模拟。

旧 `farm_grounds.gd` 继续提供故事碰撞和状态接口，其白模环境视觉隐藏；已有 Lux3D 模型保留。新增棚墙、柱子、马厩、长椅、食架和围栏有独立碰撞。屋顶剖开是明确的游戏镜头设计，保证羊棚内的交互可见。场景不是原画整图转换的模型。

## 验收结果

- 状态回归 168 项、农场回归 22 项、资产回归 462 项通过。
- 新增环境回归 32 项通过：烘焙场景加载、七个环境分区可见、建筑碰撞，以及正常键盘走访牛/羊/马并完成各自故事。
- 渲染实机完整主线 `FULL_JOURNEY failures=0`：蓝结局、重开、主路移动、零技能追逐、三轮对决、铁门和索道红结局。
- 独立目录中的导出 PCK 资源检查与渲染双结局完整路线均通过；包含烘焙环境、统一着色器、18 个既有运行时模型及头像/结局图；生成输入和密钥未打包。
- 九个区域预览和一张正常 HUD 画面在 `assets/art_references/environment_v2/`。区域总览为方便检查建筑使用不同正交缩放；`10_gameplay.png` 使用正常 size=16。
- 当前环境场景约 1.81 MiB，PCK 约 10.9 MiB。截图的引擎帧统计约 8.7–23.5 万三角面、169–354 次绘制，包含阴影和现有角色；不是跨设备帧率保证。

本机仍有已有的根证书/用户 shader 缓存权限日志；headless dummy renderer 在释放旧基础网格时产生 `Parameter m is null`，真实渲染与通关另行通过。

## 重建与运行

运行：`powershell -File scripts/art/run_demo.ps1`，或加 `-Packed` 运行已导出资源包。

修改环境源后重建：

```powershell
godot --headless --path . --log-file builds/pastoral_build.log --script scripts/art/build_environment.gd -- --rebuild-environment
```

日常运行加载已烘焙 `.scn`，不会重新生成几何。重建源文件、场景和着色器都必须一起保留。

```powershell
godot --path . --log-file builds/pastoral_capture.log --script tests/scene/capture_pastoral_environment.gd
godot --headless --path . --fixed-fps 60 --log-file builds/pastoral_test.log --script tests/scene/test_pastoral_environment.gd
godot --headless --path . --export-pack "Windows Art Demo" builds/windows/PigGoldenFarm.pck
```
