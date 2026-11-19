# 一口猪在金牌农场

Godot 4.3，版本 `0.6.2`（本轮新增：BGM / 对话配音分轨静音、二周目猪圈速通挑战——开赛即重置、任意路线抵达索道按 F 冲线、最佳纪录与最近 5 次存档）。49 件运行模型（36 件农牧场景 + 13 件牛耕地赛道道具）、七个角色骨骼动画、头像和结局插画已接入可玩流程。从海拔 32 米猪圈逐级下行，途经折返山路、断桥、耕地、羊棚、50 米直道马场、弯道追逐和索道路；另有四条隐藏赛道（水管进入）：糖豆人式牛耕地、《我的世界》体素溪流、潜行林间与马车竞速大院。本轮新增 18 件 Lux3D 植物与农牧器具，以 1,684 个批量实例丰富场地，并用连续山坡承接道路和台地边缘。2026-11-16 白模清扫：11 件新 ENV_10 模型（双扇木门/谷仓/筒仓/剪毛棚/索道站台/饲料架/长椅/石门柱/废棚/苹果/土豆）+ 8 处既有模型复用，最后一批白模方块占位几何全部换成 Lux3D 模型（运行模型目录 120 → 131，见 `docs/art/07_ENVIRONMENT_DRESSING.md` 白模清扫节）。

## 运行

用 Godot 4.3 打开 `project.godot` 后运行，或在仓库根目录执行 `run_demo.bat`（等价 `powershell -File scripts/art/run_demo.ps1`）：

```powershell
powershell -File scripts/art/run_demo.ps1
```

### 新克隆的最短跑通路径（Windows）

`run_demo.bat` 依赖两样本机环境：Godot 4.3 引擎（`.tools/godot-4.3/`）与首次资源导入缓存（`.godot/`）。两者都被 `.gitignore` 排除、不在仓库里，新克隆按下三步跑通：

```powershell
git clone https://github.com/chenzhaoxuan0/piggame.git
cd piggame

# 1) 下载 Godot 4.3 stable 标准版（约 55 MB），解压进 .tools\godot-4.3\
#    （GitHub 直连慢时可在 URL 前加镜像前缀，如 https://gh-proxy.com/）
Invoke-WebRequest "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_win64.exe.zip" -OutFile "$env:TEMP\godot.zip"
Expand-Archive "$env:TEMP\godot.zip" -DestinationPath ".tools\godot-4.3" -Force

# 2) 首次导入资源（几分钟，仅此一次；之后改动会自动增量导入）
.tools\godot-4.3\Godot_v4.3-stable_win64.exe --headless --path . --import

# 3) 运行
.\run_demo.bat
```

- 引擎必须为 **4.3**（项目按 4.3 标定）；若本机 `godot` 已在 PATH 且版本正确，可跳过第 1 步。
- macOS / Linux：`run_demo.bat` 为 Windows 脚本；下载对应平台的 Godot 4.3 打开 `project.godot`，完成首次导入后运行主场景即可。

WASD / 方向键移动，鼠标点击地面沿路前往，空格跳跃（猪会哼哼），Shift+空格 惨叫跳（直播效果拉满），F 交互，Shift 冲刺，Q 发射马桶搋子（林间关），Esc 暂停及设置。默认镜头高度和正交视野均为旧版一半；设置中的「测试用高视角」仅在本次运行启用。跟随序幕选择进入蓝结局或沿农场前往铁门与索道。

本机的 `builds/windows/PigGoldenFarm.pck` 是经过验证的运行资源包，可用 `powershell -File scripts/art/run_demo.ps1 -Packed` 运行。它需要项目自带 Godot 引擎，不是独立安装包。`builds/` 不入库，可重建并一并校验（导出 + 包内容扫描 + 空目录启动探测）：

```powershell
powershell -File scripts/art/run_demo.ps1 -PackCheck
```

跑全部回归测试用根目录 `run_tests.bat`（等价 `scripts/art/run_demo.ps1 -AllTests`，会自动枚举 `tests/` 下全部 `test_*.gd`，约 12 分钟）。

### 打包分发（Windows / macOS）

`export_presets.cfg` 提供两个导出预设：`Windows Art Demo`（产出 `builds/windows/PigGoldenFarm.exe` + `.pck`，两者须同目录分发）与 `macOS Demo`（产出 `builds/macos/` 下的 universal `.app` zip，Intel 与 Apple Silicon 通用）。首次导出前需安装 Godot 4.3 导出模板（编辑器「管理导出模板」下载，或手动装入 `.tools/godot-4.3/editor_data/export_templates/4.3.stable/`）；macOS universal 架构还要求开启 VRAM 压缩的 ETC2/ASTC 导入（`project.godot` 已配置，改动后需全量重导入）：

```powershell
# 导出并全面校验 Windows .pck（内容扫描 + 独立启动探测）
powershell -File scripts/art/run_demo.ps1 -PackCheck
# 双平台正式包
.tools\godot-4.3\Godot_v4.3-stable_win64.exe --headless --path . --export-release "Windows Art Demo"
.tools\godot-4.3\Godot_v4.3-stable_win64.exe --headless --path . --export-release "macOS Demo"
```

注意事项：导出清单为显式文件列表（`export_filter="resources"`），**新增场景/脚本/资源须同步加入两个预设的 `export_files`**，动态 `load()` 的文件尤其容易漏（主场景、配音、课程组件、音频目录均有通配或显式条目覆盖，见 `include_filter`）。无签名独立包的常见拦截：Windows 首次运行弹 SmartScreen（「更多信息 → 仍要运行」）；macOS 首次打开需在终端执行 `xattr -cr /path/to/一口猪在金牌农场.app` 后再双击。

## 资产与验证

- [当前地编交付](docs/art/07_ENVIRONMENT_DRESSING.md)：新增模型、分区布置、连续山坡、批量实例、生成来源与验收。
- [环境重构与渲染说明](docs/art/ENVIRONMENT_REBUILD.md)：场景分区、色板、着色、光照、镜头及复现命令。
- `assets/environments/pastoral_farm.scn`：可在 Godot 中打开的烘焙环境场景；地图事实源为 `scripts/levels/farm_layout.gd`，生成源为 `scripts/art/mountain_environment.gd`，建筑库为 `scripts/art/pastoral_environment.gd`。
- [完整交付清单](docs/art/ASSET_MANIFEST.md)：任务号、尺寸、面数、动画和人工修复说明。
- `assets/models/aholo/`：原始模型、运行时模型、预览、输入和 Blender 源文件。
- `assets/art_references/enriched_farm/`：当前 54 张默认近景截图和新增 18 件模型的预览目录。
- `assets/art_references/delivery/`：既有角色资产验收图。
- `tests/scene/test_art_assets.gd`：49 件资产、骨骼运动、道具和门的状态回归。
- `tests/scene/test_full_journey.gd`：真实渲染、正常移动、追逐、对决与双结局回归。
- `tests/scene/test_export_pack.gd`：独立运行包的资源完整性检查。
- `tests/scene/test_pastoral_environment.gd`：沿正常道路走访牛、羊、马并完成故事，验证新建筑碰撞与烘焙场景接入。
- `tests/scene/test_dressing.gd`：1,684 个地编实例、真实变换、材质与山体高度回归。
- `tests/scene/test_mountain_controls.gd`：跳跃、断桥跌落恢复、追逐暂停/失败/重试。
- [山地地图与操作规格](docs/art/MOUNTAIN_MAP.md)：路线尺度、地形高度、检查点和测试命令。

`.env` 只供本地生成管线使用，不参与游戏运行或导出。新 ENV_09 资产的原始 ZIP 和拒收试验保存在本机、不入 Git；原始 GLB、最终运行模型、Blender 源文件和任务溯源记录入库（这些大文件只进本地全量仓库；GitHub 镜像仅保留运行时资产，见下节）。

## GitHub 镜像说明

本仓库在 GitHub 有一份公开瘦身镜像：https://github.com/chenzhaoxuan0/piggame 。克隆镜像后按上节「新克隆的最短跑通路径」装好引擎并完成首次导入，即可运行游戏与全部测试（`run_tests.bat` / `-PackCheck` 均可用），与本地全量仓库的差异如下：

- **保留**：`master` 全部代码、场景、测试与文档的提交历史，以及运行时资产——106 件 `_game.glb` 模型、配套贴图与 `runtime_catalog.json`（以后续快照提交的形式内联，非逐版本历史）。
- **仅存本地**：原始高清 GLB、渲染验收图、`source/` Blender 源文件、Lux3D ZIP、`_input/` 再生成输入，以及上述二进制的历史版本。
- **无 Git LFS 依赖**：本地仓库用 LFS 管理 `*.glb` / `*.png` 等大文件；镜像已整体去 LFS 化为普通 git blob（约 0.9 GB），克隆方无需安装 LFS 客户端，也不占用 LFS 配额。
- **不要从本地直接 `git push` 镜像**：两边历史不同（本地全量、镜像瘦身），直接推送会被拒绝；更新镜像需重跑「临时克隆 → filter-repo 剔除 → 资产快照提交 → 强推」流水线。
