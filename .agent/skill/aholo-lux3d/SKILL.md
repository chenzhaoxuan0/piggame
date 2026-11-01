---
name: aholo-lux3d
description: "用 Aholo Lux3D 把 2D 概念图或文本变成 3D 模型（GLB/glTF + PBR 贴图），并做材质迁移、多格式导出、部件拆分、关节化与动画。只要用户提到「图生 3D / 图片转 3D / 文生 3D / 把这张图做成模型 / 要个 3D 资产 / Lux3D / Aholo / 材质迁移 / 导出 OBJ FBX USDZ / 给模型加骨骼或动画」，就用本技能 —— 本项目《一口猪在金牌农场》的 3D 资产全部经由这条流程产出，即使对方没有点名 Lux3D。关键前提：图生 3D 前必须先把主体单独抠出来，背景会污染模型。"
---

# Aholo Lux3D · 本项目 3D 资产生成

本项目（《一口猪在金牌农场》）的 3D 资产统一走 Aholo Lux3D：2D 概念图 → 抠主体 → 图生 3D → GLB 入库。
本技能提供的是**工作流与项目约束**；真正的模型生成能力由 MCP Server `aholo-sdk-mcp` 提供，两者配合使用。

## 前置条件

1. MCP Server 已连上，工具名以 `lux3d_` 开头。若连接失败，先跑 `node scripts/mcp/aholo-mcp.mjs --doctor` 自检。
2. 项目根 `.env` 已配好 `AHOLO_API_KEY` 与 `AHOLO_REGION=cn`（`.env` 不进版本库，密钥只存在本地）。
3. Node.js ≥ 18（`npx` 要能拉到 `@manycore/aholo-sdk-mcp`）。API 走国内网关 `api.aholo3d.cn`，
   直连即可、无需代理；仅当本机到该域名网络不通时，才在 `.env` 配 `AHOLO_PROXY_URL` 兜底。

## 第 0 步：先抠主体，再转 3D（不要跳过）

图生 3D 会把画面里看到的一切都当成几何体。背景、地面、投影、环境色一旦跟主体一起进图，
产出的 GLB 就会多出一圈地板/墙/雾，拓扑变脏、体积暴涨、材质跟本项目对不上，在 Godot 里也用不了。

所以：**输入给 Lux3D 的必须是只有主体本身的图**。

- 主体图标准：纯色或透明背景、主体完整居中、无投影、无环境色污染、单一物体、正方形 1:1。
- 本项目已有 2D 概念图在 `assets/2d/`，文件名即资产编号（如 `PROP_01_后山悬崖木质索道站与吊厢_2D概念图.png`），
  这些是**带场景的全景概念图**，不能直接喂给 Lux3D，必须先按资产编号裁出主体。
- 需要多视角时，用 `lux3d_image_to_four_view` 生成四视图 —— 同样只针对主体图，别对带背景的图直接跑。
- 抠图这一步属于「出图前的修正」，改的是 `assets/2d/` 里的源图还是生成中间产物，由当前任务决定；
  无论哪种，都不要在生成阶段才想起这件事。

## 图生 3D（本项目主流程）

1. 准备主体图（见第 0 步），放到 `assets/models/aholo/_input/<ASSET_ID>/` 下。
2. 调用 `lux3d_img_to_3d_from_file`（本地文件）或 `lux3d_img_to_3d`（已有 URL）。必填参数：
   - `version`：`G1` 或 `G1-Turbo`。默认先用 `G1-Turbo` 快速迭代，定稿再跑 `G1`。
   - 单图输入与多视角输入**二选一**，不要同时给。
   - `faceCount`：10000–300000。低模道具取 2 万上下，角色取 8 万上下。
   - `outputFormat`：`zip`（默认，含 GLB + PBR 贴图）、`glb`、`ply`。
   - `aiPredictSize`：开启后由模型预测包围盒尺寸，Godot 导入时更省事。
3. 提交类工具默认 `wait=false`，立刻返回 `taskId`。
4. 轮询：`lux3d_get_task` 看状态，或 `lux3d_wait_for_task` 阻塞等到完成。
5. 下载结果 ZIP（`upload_asset` 给的是 CDN URL，任务结果 URL 有效期约 2 小时，**先落盘再过期**）。

## 文生 3D（没有参考图时）

调用 `lux3d_text_to_3d`，必填 `prompt` 与 `style`，`style` 取值：
`photorealistic` / `cartoon` / `anime` / `hand_painted` / `cyberpunk` / `fantasy` / `glass`。

本项目风格统一是《无题大鹅模拟》式的极简低多边形平涂，最接近的是 `cartoon`；
但**首选还是图生 3D** —— 已有 2D 概念图做基准，风格一致性远高于纯文本生成。
可直接复用的文生 3D 提示词在 `docs/art/02_CHARACTER_PROMPTS.md`（各角色 §X.4）与
`docs/art/03_CORE_PROP_AND_3D_ASSET_PROMPTS.md`（各道具 §X.3）的「Aholo Lux3D 专用生成提示词」小节。

## 产物落盘规范

- 原始导出统一放 `assets/models/aholo/<ASSET_ID>/`，目录内保留：
  `<ASSET_ID>_lux3d.zip`（原始导出）、`<ASSET_ID>.glb`（解包后的模型）、`<ASSET_ID>.png`（预览图）。
- 命名沿用 `docs/art` 的资产编号：`CHAR_01` / `PROP_01` / `ENV_01`…… 与 `assets/2d/` 的文件名前缀一致，
  这样「2D 概念图 → 3D 模型」能一一对上。
- 预览图建议回写到 `assets/art_references/props/` 或 `characters/`，作为风格对照。

## 3D 出来之后的加工（按需）

- `lux3d_material_transfer`：给模型刷新材质（换贴图风格）。
- `lux3d_multi_format_export`：ZIP/GLB → USDZ / OBJ / FBX / STL / 3MF。
- `lux3d_part_split`：GLB 拆部件（做可动结构时用）。
- `lux3d_articulation_animation`：GLB + 提示词 → 关节化与动画。
- `lux3d_humanoid_auto_rig` / `lux3d_humanoid_animation_retarget`：数字人自动绑骨、动作重定向。

## 本项目风格约束（生成前先对齐）

Lux3D 出来的模型必须回到《无题大鹅模拟》的质感，否则合不进 Godot 主场景：

- 极简低多边形、平涂纯色块，零高频噪点贴图，圆润倒角，不要写实毛发/金属锈迹。
- 材质用纯色为主，引擎侧用 `StandardMaterial3D` + `diffuse_mode = Toon` 统一赋色。
- 主体配色以 `docs/art/01_ART_STYLE_GUIDE_AND_PROMPT_SYSTEM.md` 的色板为准
  （猪 `#F7C5C8`、耳标 `#FCD34D`、插销 `#52B788` + `#B85D3D`、黑土 `#3E2723`、草地 `#74A87C`、麦浪 `#F59E0B`）。
- 目标包围盒尺寸见 `docs/art/03_CORE_PROP_AND_3D_ASSET_PROMPTS.md` 的资产优先级总览表。

## 排错

- **连不上 / 立刻退出**：多半是 `AHOLO_API_KEY` 没读到。跑 `node scripts/mcp/aholo-mcp.mjs --doctor`，
  它会打印握手结果与工具清单。
- **拉包/请求超时**：cn 区域 API（`api.aholo3d.cn`）通常可直连；若确认本机到该域名不通，
  再在 `.env` 里配 `AHOLO_PROXY_URL` 走代理重试。
- **任务一直是 pending**：Lux3D 是异步长任务，用 `lux3d_wait_for_task` 阻塞等，别重复提交。
- **结果 URL 404**：任务结果 URL 约 2 小时过期，拿到就下载。
- **模型里带进了地板/雾**：回到第 0 步，主体没抠干净就转 3D 了。

完整工具清单与参数表见 `references/lux3d-tools.md`。
