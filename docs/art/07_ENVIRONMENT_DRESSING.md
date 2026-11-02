# 山地农场地编资产 · 0.6.0 / ENV_09

2026-11-02。在既有 18 件验收模型之上新增 18 件 Lux3D 单体，完成连续山坡、植被、道路边界和农务道具布置。当前目录共 36 件运行模型，新增模型共 35,965 三角面；全部模型各计一次为 117,286 三角面、11,884,836 字节。场景有 1,684 个批量地编实例，包含新模型及复用木箱、草捆；实例数不等于独立资产数或每帧绘制量。

## 地形与分区

- 连续山体使用 3 米网格，覆盖 x=-190…188、z=-380…178，远端裙边闭合至 y=-90。路肩贴近道路和台地底面，再向外缓降，遮住悬空路基；相邻高低路线设高度上限，断桥下保留溪沟。
- 植物根部按可见地形的实际三角面插值放置。山顶下山路末段略向南移，修复近景中上层道路横穿画面的问题；当前连接路线合计约 794 米。
- 山顶猪圈：破旧木料、散落石板、旧树桩、储水桶与独轮车。
- 牛耕地：果园、采收木箱、板车、菜畦、水泵与灌溉岸线香蒲。
- 羊棚：三篮羊毛、运输板车、开敞牧栏、池塘香蒲和白桦湿地。
- 马场：椭圆内场训练跨栏、供水点、外缘牧栏；两条 50 米直道与伙伴入口保持畅通。
- 追逐农务院与索道：工作院物资、仓房、草捆、木箱与索道后勤角。仓房缩小并移开追逐视线。
- 山路：松树、橡树、白桦、山楂、蕨类、苔石与伐木点组合；边界交替使用木栏、石墙和间断灌木，替换重复的绿篱墙。

默认近景保持视野 8、偏移 (5, 5.25, 7)；高视角仍用于测试。树冠和前景仓房在遮挡主角时打开局部视线窗口。实体道具增加简化碰撞，路线净空、跳跃缺口、追逐检查点和铁门对决保留。外坡为视觉背景，行走区域仍由道路与台地碰撞确定，护栏和跌落恢复规则继续生效。

## 资产来源与加工

最终采用 16 件文生 3D 和 2 件主体图生 3D，均来自 Lux3D G1-Turbo。新增树种和器具没有既有独立主体原画，文生使用 cartoon、10,000 原始面目标。木桶、羊毛篮先后拒收 G1-Turbo 与 G1 文生结果；后续图像候选偏写实，也未直接用于转 3D。最终绘制并检查白底、无投影、1:1 的平涂主体修正图，再以 20,000 原始面目标进行图生 3D，没有上传整张场景概念图。

最终木桶为封口木桶，未采用最初提示中的敞口雨水桶造型。羊毛篮轮廓较棱角化，场景仅用三个实例。加工保留生成轮廓，修补法线、焊接、减面并统一米制尺寸、地面原点和纯色材质；树干/树冠、桶箍、羊毛和跨栏做分区赋色。木桶、跨栏用 12° 平面溶解减面，羊毛篮用 35°，避免普通塌缩减面撕裂网格；其他模型使用塌缩减面。运行时不带生成材质贴图。

### 最终资产

| 资产 ID | 名称 | 高度 / 米 | 最终三角面 | Lux3D 任务 |
| --- | --- | ---: | ---: | ---: |
| ENV_09_OAK | 山地阔冠橡树 | 6.2 | 2,199 | 4573899 |
| ENV_09_BIRCH | 白桦树 | 5.8 | 1,796 | 4573904 |
| ENV_09_PINE | 山路层叠松树 | 6.8 | 1,980 | 4573907 |
| ENV_09_APPLE | 牧场苹果树 | 4.2 | 1,993 | 4573912 |
| ENV_09_HAWTHORN | 开花山楂灌木 | 1.25 | 1,199 | 4573922 |
| ENV_09_FERN | 林下阔叶蕨 | 0.7 | 800 | 4573997 |
| ENV_09_REEDS | 溪岸香蒲丛 | 1.45 | 994 | 4574000 |
| ENV_09_ROCK | 苔石岩块 | 1.4 | 900 | 4574005 |
| ENV_09_STUMP | 伐木树桩 | 0.75 | 1,270 | 4574010 |
| ENV_09_WHEELBARROW | 农用独轮车 | 0.95 | 1,597 | 4574016 |
| ENV_09_CART | 木制运草板车 | 1.45 | 1,981 | 4574122 |
| ENV_09_BARREL | 木制储水桶 | 1.0 | 4,070 | 4575173 |
| ENV_09_PUMP | 绿色手压水泵 | 1.45 | 1,598 | 4574135 |
| ENV_09_WOOL | 剪毛棚羊毛篮 | 0.7 | 6,292 | 4575176 |
| ENV_09_HURDLE | 马场训练跨栏 | 1.6 | 3,700 | 4574145 |
| ENV_09_RAIL | 牧场交叉木栏模块 | 1.2 | 999 | 4574333 |
| ENV_09_WALL | 乡野干砌石墙模块 | 1.1 | 1,600 | 4574337 |
| ENV_09_SIGN | 山路木质路标 | 1.8 | 997 | 4574345 |

原始 ZIP、GLB、最终运行 GLB、预览、Blender 源文件与加工报告保留在本机对应资产目录。新资产 ZIP 和拒收试验文件夹不进 Git；原始 GLB、最终运行文件、可编辑源文件、主体图和生产记录入库。任务参数、输入哈希、原件哈希及拒收历史见 `assets/models/aholo/dressing_production.json`。不要重新提交已完成任务。

## 场景源与复现

- `scripts/art/mountain_surface.gd`：连续山皮高度与三角面插值。
- `scripts/art/mountain_environment.gd`：地形、台地、桥、围栏、建筑和道路。
- `scripts/art/farm_dressing.gd`：各场地农务组合与确定性植被分布。
- `scripts/art/dressing_batches.gd`：每种资产合并为单个顶点色表面，按 24 米空间格组织 MultiMesh；实例共享网格和材质。
- `assets/environments/pastoral_farm.scn`：版本 4 烘焙场景。最终文件用实际渲染器保存；headless 重建还会把变换存入 `placements` 元数据，由 `farm_grounds.gd` 加载时恢复，避免 dummy renderer 丢失实例 GPU 缓冲。
- `scripts/art/produce_dressing.py`：最多五个在途任务的断点生产；`repair_dressing.py`、`paint_dressing_subjects.py` 保留主体修正流程。
- `scripts/art/process_dressing.py`：Blender 加工；`review_dressing.py`：预览与明确指定 ID 的验收入册。

```powershell
# 用实际渲染器重建，让独立场景预览也有完整实例变换
godot --path . --log-file builds/enrichment_build.log --script scripts/art/build_environment.gd -- --rebuild-environment
godot --path . --log-file builds/enrichment_instances.log --script tests/scene/test_dressing.gd
godot --path . --log-file builds/enrichment_capture.log --script tests/scene/capture_enriched_farm.gd
godot --headless --path . --export-pack "Windows Art Demo" builds/windows/PigGoldenFarm.pck
```

加工单件：`blender --background --python scripts/art/process_dressing.py -- ENV_09_OAK`；随后检查预览，用 `python scripts/art/review_dressing.py --accept ENV_09_OAK` 更新目录。本文档定义风格与提示词，`scripts/art/dressing_specs.json` 为机器可读镜像，包含尺寸、初始预算和色板。最终验收预算以 `runtime_catalog.json` 为准：常规模型不超过 2,600 面，桶和跨栏不超过 4,500，羊毛篮不超过 7,000。

## 验证与范围

- 资产回归 714 项通过；场地回归 203 项通过。
- 地编回归 4,399 项通过、1,684 个实例；覆盖材质、CPU 变换持久化、实际渲染变换恢复、网格和地形高度。
- 伙伴访问、50 米直道、跳跃、暂停、断桥跌落恢复、追逐捕获与重试通过。
- 源码和独立 PCK 均使用实际渲染、键盘移动和空格跳跃完成双结局，`FULL_JOURNEY failures=0`。没有用瞬移替代全程通关，犬队实际绕弯跟随约 157.1 米。
- 独立 PCK 资源检查通过：36 件模型、版本 4 环境与实例恢复齐全；原件、ZIP、Blender 文件、主体输入、生产清单和密钥未进入运行包。
- 已检查 54 张普通玩家视角截图：12 个场地/边缘点与 42 个道路中点。预览在 `assets/art_references/enriched_farm/`；`00_dressing_catalog.png` 为模型目录，其余为游戏实机。
- 采样绘制统计约 150–323 次调用、4.1–70.6 万图元（包含阴影）；不是 FPS 基准，不构成跨设备性能保证。

本机日志仍有根证书读取、shader cache 写入权限及 headless dummy renderer 释放旧网格时的提示；实际 OpenGL 渲染和独立包测试另行通过。验收范围为默认近景采样与真实路线通关，不声称任意调试飞行镜头下都无穿帮。

## 文生提示词规范

以下为实际使用的公共前缀和各资产主体描述；木桶与羊毛篮对应初次文生尝试，最终采用上文白底主体图。公共前缀：

> A single isolated freestanding game asset in the visual style of Untitled Goose Game. Minimal low polygon pastoral British farm, matte solid broad color blocks, softly rounded edges. No photorealism, no detailed texture, no noise, no floor, no ground plane, no pedestal, no background, no cast shadow geometry, no extra objects, no text. Complete object with intact base.

### ENV_09_OAK · 山地阔冠橡树

One mature oak tree, thick branching brown trunk, asymmetrical broad crown made of five large rounded angular olive green foliage masses, visible lower trunk and compact roots. No individual leaves.

### ENV_09_BIRCH · 白桦树

One slender birch tree with two forked ivory trunks, sparse dark bark bands, airy oval sage green crown in three solid clumps. No individual leaves.

### ENV_09_PINE · 山路层叠松树

One mountain pine tree, visible brown trunk, irregular layered umbrella boughs of dark sage green solid foliage, bent silhouette. No needles or individual leaves.

### ENV_09_APPLE · 牧场苹果树

One short orchard apple tree, crooked forked brown trunk, broad low green solid crown with eight large muted red apples attached among the foliage. No individual leaves.

### ENV_09_HAWTHORN · 开花山楂灌木

One low asymmetrical hawthorn shrub, three connected rounded sage green foliage masses, a few simple large cream flower clusters, broad spreading silhouette. No pot.

### ENV_09_FERN · 林下阔叶蕨

One stylized fern plant with six broad solid curved fronds spreading from a central crown, very simplified large leaf silhouettes without tiny leaflets, moss green. No pot or base.

### ENV_09_REEDS · 溪岸香蒲丛

One compact clump of seven broad green reed leaves and three brown cattail seed heads, simple thick silhouettes suitable for a low polygon game, no water or ground.

### ENV_09_ROCK · 苔石岩块

One squat asymmetrical granite boulder with large broad smooth angular faces, blue grey stone, a single smooth olive green moss patch covering the top, no cracks texture.

### ENV_09_STUMP · 伐木树桩

One old tree stump, broad cut top in pale wood with one simple concentric ring, dark brown short bark cylinder, three chunky roots and a single broken branch, no ground.

### ENV_09_WHEELBARROW · 农用独轮车

One simple sage green metal farm wheelbarrow with empty deep tray, single dark wheel, two wooden handles and two support feet. Chunky legible proportions, no load.

### ENV_09_CART · 木制运草板车

One small empty rustic farm cart, two large solid wooden spoked wheels, open wooden rectangular plank bed, short side rails and long tow bar. Rounded chunky low polygon construction.

### ENV_09_BARREL · 木制储水桶

One upright open wooden rain barrel with two broad dark iron hoops, pale brown staves, visible dark interior, broad simple geometry, no wood grain texture.

### ENV_09_PUMP · 绿色手压水泵

One freestanding vintage cast iron hand water pump, muted sage green vertical column, curved spout, long arched pumping lever, small circular foot. Thick simple sturdy geometry, no basin.

### ENV_09_WOOL · 剪毛棚羊毛篮

One low oval wicker farm basket filled with three large cream wool bundles, two thick loop handles. Solid broad woven bands, soft simple lumps, no individual hair or fabric texture.

### ENV_09_HURDLE · 马场训练跨栏

One complete horse jumping hurdle, two thick upright timber standards, two horizontal poles, broad feet. Muted terracotta red and cream alternating broad color bands. Freestanding single assembly.

### ENV_09_RAIL · 牧场交叉木栏模块

One straight rustic split rail fence module, two square wooden posts, two horizontal rails and a single diagonal cross brace. Four metres wide compared with 1.2 metres tall, ends stop exactly at posts. Chunky plain wood.

### ENV_09_WALL · 乡野干砌石墙模块

One straight low dry stone wall module, three courses of large irregular rounded grey stones, broad flat coping stones, four metres wide compared with 1.1 metres tall. No arch, no ground or vegetation.

### ENV_09_SIGN · 山路木质路标

One rustic wooden trail signpost with two broad arrow shaped boards pointing in opposite directions, thick single vertical timber post. Blank boards without text, pale tan wood, simple dark end grain.
