# 农牧场环境重构

2026-11-02。以 ENV_01 悬崖猪圈原画为近景造型和色彩依据，以《Untitled Goose Game》为克制、清晰的游戏画面方向。

渲染风格由五项共同决定：环境轮廓与结构、材质色板、光照与阴影、镜头构图、场景物件的密度及用途。仅把材质设为 Toon 无法让矩形地台和球形树冠成为农场。

本轮范围：重建猪圈、耕地、剪毛棚、马场、作业院、铁门和索道周边；改造连接道路、树篱、石墙、水沟、植被、悬崖和远景。既有 Lux3D 角色、道具及故事交互继续使用。新增环境为按概念图手工编写的模块化几何，不冒充云端生成模型。

视觉约束：哑光纯色、无写实纹理、无泛光、低饱和草绿/灰蓝石/暖木/深土、区域地标清晰。石墙有砌块、棚屋有木板梁柱和屋顶、田地有垄沟、赛道有环形路面与起终点。镜头保留正交视角并降低俯角，角色与可交互处不能被屋顶遮住。

## 实现

| 环节 | 事实源 | 本轮实现 |
| --- | --- | --- |
| 场景结构 | `scripts/levels/farm_layout.gd` + `scripts/art/mountain_environment.gd` | 共用道路/碰撞顶点；台地与下山路；建筑来自 `pastoral_environment.gd`；按 20 米分批，烘焙为 `assets/environments/pastoral_farm.scn` |
| 纯色与光影 | `scripts/art/pastoral_surface.gdshader` | 无纹理、无高光；限定亮部与阴影明度，阴影带冷色；低于地表的山谷有淡灰紫空气色 |
| 角色一致性 | `scripts/art/asset_library.gd` | 保留原模型的材质颜色，以共享 ShaderMaterial 接入相同着色；不修改 GLB 原件 |
| 主光与阴影方向 | `scenes/levels/office_level_1.tscn` | 单一方向光；近景阴影距离 65 米；修正阴影偏移避免条纹 |
| 构图 | `scripts/core/isometric_camera.gd` | 默认正交 size=8，偏移 (5, 5.25, 7)，高度与视野各减半；Esc 设置可暂时启用旧 size=16 / (10,10.5,14) 测试镜头 |
| 边缘 | `project.godot` | Compatibility 渲染，4× MSAA |

固定美术主光下，shader 自行限定明暗幅度；太阳旋转控制投影方向。`illumination` 的两个值、冷暖 `tint`、环境源文件的颜色常量分别控制对比度、阴影色和物体配色。没有用噪声贴图、全屏滤镜或写实 PBR 增加细节。

环境轮廓、土路、砌块墙、棚屋木板和梁柱、田垄、水渠、桥板、喂食架、提桶、围栏、马厩、起跑线、农机棚、树篱、麦田与崖下远景均为实几何。水面和薄雾采用纯色平面，薄雾只在谷底；当前没有体积雾或动态水面模拟。

`farm_grounds.gd` 保留故事状态接口，旧直线地图、巨型平地和旧环境碰撞均已移除；已有 Lux3D 模型保留。新增棚墙、柱子、马厩、长椅、食架和围栏有独立碰撞。屋顶剖开是明确的游戏镜头设计，保证羊棚内的交互可见。场景不是原画整图转换的模型。

## 当前山地版本

详细地图规格及本轮验收见 [MOUNTAIN_MAP.md](MOUNTAIN_MAP.md)。早期平面地图的截图保留在 `environment_v2/` 作为历史参考，当前截图为 `mountain_farm/`。

八张 `normal` 截图使用真实默认 size=8；两张 `test` 总览显式扩大视野，只供看地图结构。树冠共享主光，但在前景遮挡猪时挖开一个小范围视线窗口，既保留树林遮挡，也能辨认主角。角色和土路不会被此规则剔除。

本机存在根证书读取、GLES shader cache 权限日志和 headless dummy renderer 释放网格时的 `Parameter m is null`；实机渲染和通关另行验证。

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
