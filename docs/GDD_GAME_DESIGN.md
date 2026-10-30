# 《特立独行的猪：逃离牛马大厦》
# 核心游戏设计文档 (Game Design Document - GDD v0.1.0)

---

## 1. 游戏概述 (Executive Summary)

- **游戏名称**：《特立独行的猪：逃离牛马大厦》 (A Maverick Pig: Escape the Animal Office)
- **核心定位**：2.5D 职场反讽潜行搞事冒险游戏（Untitled Goose Game 视角与调性）。
- **技术驱动**：
  - **群核科技 AHOLO (Kujiale)**：高品质 3D 现代办公室室内空间生成与模型材质支持。
  - **GPT6 Astra**：智能化职场黑话梗生成与动态明暗双线叙事支撑。
  - **游戏引擎**：**Godot Engine 4.3 (GL Compatibility 渲染)**，优先确保 Web (HTML5/WebAssembly) 零门槛即开即玩，并平滑支持 Steam PC Demo 导出。
- **MVP 核心边界**：
  - 单角色聚焦：仅做 **“特立独行的猪”**。
  - 单场景关卡：仅做 **“办公室第3层：敏捷赋能试验区”**。
  - 故事终点：从打工人工位出发，拿到工牌引开视线，最终按亮电梯并成功踏入下行电梯。

---

## 2. 核心循环与玩法机制 (Core Loop & Gameplay)

```
[观察办公室巡视路线与障碍]
       │
       ▼
[使用技能制造骚乱 / 摸鱼互动] ── (猪叫惊扰 / 冲撞办公椅 / 叼走道具)
       │
       ▼
[触发明暗双线职场剧情对话] ── (大厂黑话公关 vs 打工人毒舌吐槽)
       │
       ▼
[解锁门禁 / 拿到通关关键物品] ── (获取P7架构师工牌)
       │
       ▼
[踏入电梯间，开启下一层逃亡]
```

### 基础操作映射
| 操作键位 | 动作名称 | 玩法效果 |
| :--- | :--- | :--- |
| **W / A / S / D** (方向键) | 2.5D 平滑跑动 | 45度斜向投影校正，萌趣小碎步奔跑 |
| **Space (空格键)** | 哼哧猪叫 (Oink) | 环形音波扩散，打断同事思考或使其掉落手头物品 |
| **Shift / J 键** | 职场冲撞 (Dash) | 瞬间加速冲撞，可推开人体工学椅、撞倒垃圾桶、按电梯按钮 |
| **E / K 键** | 拱探交互 (Interact) | 叼起地上的工牌、吃零食回体、触发对话 |

---

## 3. 角色矩阵规划 (The 4 Animal Personas)

1. **🐷 猪 (The Maverick Pig) - [MVP当前主打]**
   - 目标：逃离牛马大厦（当前做第3层下潜至电梯）。
   - 关键词：自由、反叛、打破规训、摸鱼成道。
2. **🐂 牛 (The Relentless Ox) - [后续章节]**
   - 目标：排除万难回到工位完成工作修完Bug。
   - 关键词：老黄牛、卷王、死磕周报、机械键盘。
3. **🐑 羊 (The PowerPoint Sheep) - [后续章节]**
   - 目标：一路向阳直通顶楼董事会汇报。
   - 关键词：领头羊、PPT战神、中英双语、向上管理。
4. **🐎 马 (The Enigmatic Horse) - [企划中]**
   - 提案：跑路猎头马 / 拍马屁之马 / 空降特洛伊木马。
   - 关键词：闪转腾挪、赛道冲刺、期权兑现。

---

## 4. Web 端与 Steam Demo 发布工程管线

1. **Web (HTML5 / Wasm) 优先支持**：
   - 使用 Godot 4 的 `gl_compatibility` 渲染器，具备极佳的 WebGL 兼容性与极快的加载速度。
   - 打包产物仅为轻量化的 `.html` + `.js` + `.wasm` + `.pck`，可直接部署在内网、Vercel、GitHub Pages 或群核 Web 展台。
2. **Steam Demo 导出**：
   - 切换导出预设为 Windows Desktop 64-bit (x86_64)。
   - 集成基础手柄振动与分辨率自适应。

---

## 5. 项目工程代码与场景目录索引
- `project.godot`：Godot 4 项目全局配置（已设好按键映射、GL Compatibility 渲染与分辨率）
- `scenes/ui/character_selection.tscn`：角色选择初始主界面（猪可选，牛马羊锁定，中英文切换）
- `scenes/characters/pig.tscn`：特立独行的猪 3D 控制器与原型网格
- `scenes/levels/office_level_1.tscn`：办公室第3层 3D 完整游玩关卡
- `scripts/core/game_manager.gd`：游戏全局单例
- `scripts/core/dialogue_manager.gd`：明暗双线对话与职场梗管理器
- `scripts/characters/pig_controller.gd`：猪主角控制脚本
- `scripts/core/isometric_camera.gd`：2.5D Isometric 平滑相机
- `docs/`：完整设计与技术文档

