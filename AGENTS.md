# AGENTS.md —《一口猪在金牌农场》美术资产工作区

> 所有 AI Agent（Codex / Cursor / Claude Code / OpenCode / MCode 等）进入本仓库的第一入口。
> `docs/art/` 负责定义「要什么」（风格与提示词），本文件负责定义「怎么干、产物放哪、哪些不能做」。

## 1. 仓库定位

- 分支 `art-concept`，独立 Git worktree（目录 `piggame-art`）。
- 职责：美术风格定义、原画/概念图提示词工程、2D 立绘与 UI 设计、以及面向 **Aholo Lux3D** 的核心 3D 资产生成与监督。
- 玩法逻辑与 Godot 白模在另一个 worktree `piggame`（master）。两条线完全解耦并行，
  经双门槛合流：**S0**（美术风格门槛）+ **G0**（白模实机门槛）同时通过，才放行正式 3D 制作。

## 2. 目录地图

```text
piggame-art/
├── docs/art/          # 美术提示词体系（事实源）：01 风格规范 / 02 角色 / 03 道具与3D / 04 场景 / 05 UI头像 / 06 Lux3D实操
├── assets/
│   ├── 2d/             # 2D 概念图与对话头像，文件名即资产编号
│   ├── art_references/# 概念图 / 提示词试验产物 / 风格参考（characters|props|environments|ui）
│   └── models/aholo/  # Lux3D 导出的 3D 资产（glb / zip / 预览图）
├── scenes/             # Godot 场景
├── scripts/mcp/        # 本项目 MCP 启动器
├── .agent/skill/       # 本项目技能（多 Agent 通用）
└── .mcp.json           # 项目级 MCP 配置
```

## 3. 硬性要求

### 3.1 图像转 3D 之前，必须先把主体单独取出来

**当你要把一张 2D 图转成 3D 模型时，必须先把这张图里的主体本身抠出来（去背景），再用主体图去做图生 3D，不能把带背景的原图直接喂给转 3D 的工具。**

原因很实在：图生 3D 会把画面里能看到的几何体一并建模。背景、地面、投影、环境色混进去以后，模型会多出一圈地板/墙/雾，拓扑变脏、体积暴涨，跟本项目的低多边形平涂风格也对不上，在 Godot 里基本没法用，重做的成本远高于抠图这一步。

落地要求：

- 主体图标准：纯色或透明背景、主体完整居中、无投影、无环境色污染、单一物体、正方形 1:1。
- `assets/2d/` 里存的是**带场景的全景概念图**（文件名形如 `PROP_01_后山悬崖木质索道站与吊厢_2D概念图.png`），它们是风格基准，不是可直接转 3D 的输入 —— 先按资产编号裁出主体再转。
- 需要多视角时走 `lux3d_image_to_four_view`，输入同样只能是主体图。
- 抠主体属于「出图前」的修正，务必在调用转 3D 之前完成，不要生成完才发现模型脏了。

### 3.2 2D 资产的命名必须能回溯到提示词条目

`assets/2d/` 的文件名格式固定为 `{资产ID}_{文档资产名}_{图别}.png`，资产ID（`CHAR_01` / `PROP_01` / `ENV_01`…）与 `docs/art/` 的条目一一对应。改图或加图时保持这个规则，否则资产与提示词就断链了。

### 3.3 提交纪律

- 一次改动一个 commit；只 `git add` 自己动过的文件，不要夹带别的会话的改动。
- `.env` 含真实 API Key，已被 `.gitignore` 排除，**任何时候都不要提交**；需要共享配置时改 `.env.example`。
- 本地 commit 即可，推送由用户明确要求时再做。

## 4. 3D 资产生成：MCP + Skill

### 4.1 组成

- **MCP Server**：`aholo-sdk-mcp`（官方包 `@manycore/aholo-sdk-mcp@1.9.0`，stdio 传输，共 26 个工具）。
  由 `scripts/mcp/aholo-mcp.mjs` 拉起：它读项目根 `.env` 拿 `AHOLO_API_KEY` / `AHOLO_REGION`
  （cn，直连国内网关 `api.aholo3d.cn`，默认不走代理；仅当 `.env` 配了 `AHOLO_PROXY_URL` 时才注入代理），
  再把 stdio 原样转交给官方包。
- **Skill**：`.agent/skill/aholo-lux3d/SKILL.md`（工作流与项目约束），
  配套 `references/lux3d-tools.md`（26 个工具速查）。
  **任何 Agent 接手 3D 资产任务前先读它**：里面写了抠主体规则、参数取值、产物落盘路径与排错方式。

### 4.2 密钥与代理从哪来

- 真实密钥只存在项目根 `.env`，已被 `.gitignore` 排除；**进版本库的配置里一律不含密钥**。
- 默认不走代理：cn 区域 API 直连 `api.aholo3d.cn`。仅当本机到该域名网络不通时，
  才在 `.env` 配 `AHOLO_PROXY_URL` 兜底（代理地址只配这一处，换端口只改这一行）。
- 启动器从**脚本自身所在路径**反推仓库根去找 `.env`，所以无论从哪个工作目录拉起它都能读到密钥。
- 需要共享配置时改 `.env.example`，不要把真实值写进任何被跟踪的文件。

### 4.3 各客户端怎么接上

**读项目配置文件的客户端，打开本仓库即自动生效**，无需任何额外操作：

| 配置文件 | 客户端 | 路径写法 |
| :--- | :--- | :--- |
| `.mcp.json` | Claude Code（项目作用域）、Claude Desktop | `${CLAUDE_PROJECT_DIR:-.}/scripts/mcp/aholo-mcp.mjs` |
| `.cursor/mcp.json` | Cursor（项目级） | `scripts/mcp/aholo-mcp.mjs`（相对项目根） |
| `.vscode/mcp.json` | VS Code / Copilot | `${workspaceFolder}/scripts/mcp/aholo-mcp.mjs` |

**MCode 桌面端这类只读全局档案、不读项目配置的客户端，需要手动加一条记录。**
档案位置 `C:\Users\chenziyu\.minimax\mcp.json`，结构与 `.mcp.json` 相同（顶层 `mcpServers`），加下面这段：

```json
{
  "mcpServers": {
    "aholo-sdk-mcp": {
      "type": "stdio",
      "command": "node",
      "args": ["C:/Users/chenziyu/project/piggame-art/scripts/mcp/aholo-mcp.mjs"],
      "env": {}
    }
  }
}
```

> `args` 里的路径要换成**本仓库的实际绝对路径**；仓库换了位置才需要改。
> 加完重启客户端，让它重新握手。
> 这条记录虽然是全局的，但密钥仍然只存在项目 `.env` 里 —— 换项目不用动档案。

### 4.4 Skill 怎么被各 Agent 发现

- 仓库内的唯一事实源是 `.agent/skill/aholo-lux3d/`，改动只改这里。
- 只扫描自己 skills 目录的客户端（Claude Code 默认扫 `~/.claude/skills/`，MCode 扫 `~/.minimax/skills/`），
  在本机这两者最终都指向全局 hub `C:\Users\chenziyu\.agents\skills\`。
  把项目里的 skill 链过去，就能所有 Agent 共用同一份、且改了立即生效：

```powershell
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.agents\skills\aholo-lux3d" -Target "<本仓库绝对路径>\.agent\skill\aholo-lux3d"
```

- Windows 建符号链接需要管理员权限或开发者模式；没有权限就直接复制一份：
  `Copy-Item -Recurse "<本仓库绝对路径>\.agent\skill\aholo-lux3d" "$env:USERPROFILE\.agents\skills\aholo-lux3d"`
- 不想装到全局也行：**开工前读一遍 `.agent/skill/aholo-lux3d/SKILL.md`** 即可，规则一样生效。

### 4.5 自检

```powershell
node scripts/mcp/aholo-mcp.mjs --doctor
```

完成 MCP 握手并打印工具总数与清单，正常输出长这样：

```text
[aholo-mcp] 握手成功，region=cn，proxy=未启用（直连 api.aholo3d.cn）
[aholo-mcp] 工具总数: 26
```

拿不到 `AHOLO_API_KEY` 时会直接退出并提示 `.env` 的位置 —— 这是最常见的一类故障。

## 5. 风格底线（分区画风制）

> 2026-11-09 起，配合糖豆人式闯关 redesign（事实源 `docs/COURSE_REDESIGN.md`），全项目从"统一大鹅平涂"改为**分区画风制**。

- **角色恒定**：猪、伙伴、恶犬等角色资产永远保持《无题大鹅模拟》(Untitled Goose Game) 语言——极简低多边形、平涂纯色块、零高频噪点、极简黑圆点双眼。角色是"穿越进不同世界的游客"，不换风格，画风反差本身是喜剧。
- **分区画风**：每条赛道区域有独立画风——牛耕地 = 低多边形平涂田园（基准世界）；溪流 = 像素/体素；林间 = 童话手绘；大院 = 糖豆人荧光综艺。各区风格以 `docs/art/01_ART_STYLE_GUIDE_AND_PROMPT_SYSTEM.md` 的分区子规范为准。
- 新增区域资产必须回到**所属区域**的风格语言里，不得串区混用；画风突变是设计出来的笑点，不是事故。

## 6. 事实源

- 风格与提示词：`docs/art/`（唯一事实源，改风格从这里改起）。
- 资产编号与优先级：`docs/art/README.md` 的任务清单 + `docs/art/03_CORE_PROP_AND_3D_ASSET_PROMPTS.md` 的资产优先级总览。
- 3D 生成参数与工具：`.agent/skill/aholo-lux3d/references/lux3d-tools.md`。
