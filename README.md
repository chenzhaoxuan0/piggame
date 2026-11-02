# 一口猪在金牌农场

Godot 4.3，版本 `0.3.0-art`。14 件核心模型、4 类环境构件、七个角色骨骼动画、头像和结局插画已接入可玩流程。

## 运行

用 Godot 4.3 打开 `project.godot` 后运行，或在仓库根目录执行：

```powershell
powershell -File scripts/art/run_demo.ps1
```

WASD / 方向键移动，鼠标点击地面移动，E 交互，Shift 冲刺，Esc 暂停。跟随序幕选择进入蓝结局或沿农场前往铁门与索道。

本机的 `builds/windows/PigGoldenFarm.pck` 是经过验证的运行资源包，可用 `powershell -File scripts/art/run_demo.ps1 -Packed` 运行。它需要项目自带 Godot 引擎，不是独立安装包。`builds/` 不入库，可通过导出配置重建：

```powershell
godot --headless --path . --export-pack "Windows Art Demo" builds/windows/PigGoldenFarm.pck
```

## 资产与验证

- [完整交付清单](docs/art/ASSET_MANIFEST.md)：任务号、尺寸、面数、动画和人工修复说明。
- `assets/models/aholo/`：原始模型、运行时模型、预览、输入和 Blender 源文件。
- `assets/art_references/delivery/`：实机与角色验收图。
- `tests/scene/test_art_assets.gd`：18 件资产、骨骼运动、道具和门的状态回归。
- `tests/scene/test_full_journey.gd`：真实渲染、正常移动、追逐、对决与双结局回归。
- `tests/scene/test_export_pack.gd`：独立运行包的资源完整性检查。

`.env` 只供本地生成管线使用，不参与游戏运行或导出。
