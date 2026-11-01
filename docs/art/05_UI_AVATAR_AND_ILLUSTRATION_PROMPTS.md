# 《一口猪在金牌农场》UI 视觉、对话头像与任务清单提示词库 (Untitled Goose Game 风格版)

> **视觉风格基准**：**《无题大鹅模拟》(Untitled Goose Game)**  
> **核心特征**：极简平涂头像 (Flat-Shaded Avatars)、手写代办笔记本 UI 规范 (To-Do List Aesthetics)、清爽扁平徽章 (Clean Flat Emblems)。

---

## 一、对话头像切片提示词 (Dialogue Avatar Bible)

### 1.1 头像设计规格
- **画幅与构图**：`1:1` 正方形，纯净无杂质的低多边形 3D 头部半身切片，搭配柔和纯色圆形衬底。
- **神态核心**：黑色极简黑圆点双眼（Bead eyes），依靠微倾斜的头部、耳朵摆动、口衔物件传达强烈情绪。

### 1.2 全角色头像提示词集

| 角色与表情状态 | 2D 提示词 (Midjourney / Flux / SDXL) |
| :--- | :--- |
| **猪“包子”·机敏中立态 (默认)** | `Clean circular game dialogue avatar icon of a pale-pink pig, in the art style of Untitled Goose Game. Flat-shaded low-poly 3D bust, cute black bead dot eyes, smooth pastel pink snout, bright flat-yellow tag '047' on ear, neutral clever gaze. Solid soft cream background, clean outline, flat shading, House House game UI icon --ar 1:1 --v 6.0` |
| **猪“包子”·口衔红铜插销态 (出逃)** | `Circular game dialogue avatar icon of a determined pale-pink pig firmly clamping a chunky green-patina bronze latch pin in its snout, bright yellow tag '047' on ear, resolute expression. Untitled Goose Game art style, flat-shaded 3D model, soft pastel blue background, clean vector-like outline --ar 1:1 --v 6.0` |
| **老岩羊·深邃嘲弄态** | `Circular game avatar icon of an old bighorn mountain goat, in the art style of Untitled Goose Game. Shaggy low-poly light-grey wool, chunky spiral horns in solid dark slate, subtle knowing smirk with bead eyes. Flat-shaded 3D bust on soft sage-green background, House House UI style --ar 1:1 --v 6.0` |
| **老黄牛·疲惫紧绷态** | `Circular game avatar icon of a massive brown ox, in the art style of Untitled Goose Game. Chunky blocky dark-brown head, tired drooping eyes, simple pale wooden harness collar around neck. Flat-shaded low-poly 3D on muted beige background, clean indie game UI icon --ar 1:1 --v 6.0` |
| **老黄牛·痛饮释怀态** | `Circular game avatar icon of a gentle brown ox with a peaceful relaxed gaze, droplets of clear water around its muzzle, unhooked wooden collar. Untitled Goose Game art style, flat-shaded 3D model, warm sunny yellow background, heartwarming UI icon --ar 1:1 --v 6.0` |
| **小绵羊·自卑委屈态** | `Circular game avatar icon of an adorable tiny white fluffy sheep, in the art style of Untitled Goose Game. Puffy cloud-like low-poly fleece, flat pink face with sad dot eyes, a wooden tag reading '三等残次'. Flat-shaded 3D bust on pale grey background --ar 1:1 --v 6.0` |
| **小绵羊·沐光自洽态** | `Circular game avatar icon of a happy little cloud sheep, eyes contentedly closed in pure bliss, bathed in warm yellow light. Untitled Goose Game art style, flat-shaded 3D bust on bright golden background, cozy and adorable UI icon --ar 1:1 --v 6.0` |
| **烈马“追风”·焦虑狂躁态** | `Circular game avatar icon of a dark chestnut racehorse, in the art style of Untitled Goose Game. Sleek low-poly brown head, flaring nostrils, wide alert bead eyes, red ribbon medal reading '41s'. Flat-shaded 3D bust on dusty orange background --ar 1:1 --v 6.0` |
| **烈马“追风”·嚼草从容态** | `Circular game avatar icon of a handsome chestnut horse chewing on a bright yellow dandelion flower, soft calm eyes. Untitled Goose Game art style, flat-shaded 3D model on soft meadow-green background, peaceful and humorous --ar 1:1 --v 6.0` |
| **农场主·手持电棍威慑态** | `Circular game avatar icon of a human farmer, in the art style of Untitled Goose Game. Simple low-poly stylized face with bushy brows, flat tweed cap, holding a black-and-yellow stun baton. Flat-shaded 3D character bust on dark industrial grey background --ar 1:1 --v 6.0` |
| **农场主·现实主义认栽态** | `Circular game avatar icon of a disheveled farmer in dungarees scratching his head in comical disbelief and realistic resignation. Untitled Goose Game art style, flat-shaded 3D character icon on soft sunset-orange background --ar 1:1 --v 6.0` |

---

## 二、大鹅式手写代办清单 UI 规范 (To-Do List UI System)

借鉴《无题大鹅模拟》中最具标志性的**手写横线稿纸代办清单 (Ruled Paper To-Do List)**，本作的任务追踪采用同款设计语言：
- **背景底纸**：略带微黄做旧质感的英式横格信纸（Cream Ruled Notebook Paper）。
- **字体规范**：手写钢笔/圆珠笔风格英文与圆润手写中文字体，完成的任务划上一道深红色的删除横线（Strike-through）。

```text
┌───────────────────────────────────────────────┐
│              一口猪的旷野突围计划             │
│                                               │
│  [─] 衔起老岩羊踢出的生锈铜插销               │
│  [─] 撞断猪圈木门栓，踏入农场大院             │
│  [ ] 帮老黄牛挑出黑土垄下的花岗岩大石块       │
│  [ ] 踢飞小绵羊身上的“三等残次”木牌           │
│  [ ] 让烈马看到路边35秒的新纪录看板           │
│  [ ] 穿过大院草垛，甩开追击的护院犬队         │
│  [ ] 在后山大铁门前撞碎铁锁，突破农场主拦截   │
│  [ ] 将铜插销插入滑轮卡槽，乘木吊厢飞向旷野   │
└───────────────────────────────────────────────┘
```

---

## 三、成就徽章与能力图标提示词 (Badges & Perks)

### 3.1 成就徽章图标 (Achievement Badges)
```text
-- 通用前缀：
Clean flat-shaded 3D game achievement badge, in the art style of Untitled Goose Game, simple bold vector-like low-poly relief emblem, isolated on pure white background, solid color blocking, zero texture noise:
```

- 🏆 **【温热的泥浆】(A Warm Wallower - 蓝线结局)**:
  > `...A cute smooth pale-pink pig curled peacefully inside a warm chocolate-brown mud circle, with a single bright yellow corn kernel emblem above it. House House game style, cozy warm colors --ar 1:1 --v 6.0`

- 🏆 **【红色的生锈插销】(The Rusty Bronze Latch Pin - 破门启程)**:
  > `...A chunky low-poly bronze latch pin with green patina accents, crossed over a simple splintered wooden beam, framed in a bold crimson red circular border. Minimalist flat-shaded indie game emblem --ar 1:1 --v 6.0`

- 🏆 **【特立独行的先驱】(The Maverick Pioneer - 红线终局)**:
  > `...A charming wooden cable car gondola silhouette soaring across a bright golden-yellow sunburst emblem over rolling low-poly green hills. House House game style, triumphant and cheerful --ar 1:1 --v 6.0`

---

### 3.2 伙伴领悟能力图标 (Perk Icons)

- 🛡️ **【坚忍之骨】(Bone of Resilience - 来自老黄牛)**:
  > `A clean flat-shaded 3D skill icon of a chunky low-poly ox horn and a grey granite stone, in the art style of Untitled Goose Game. Solid earthy brown and stone grey colors, clean circular icon on white background --ar 1:1 --v 6.0`

- 👁️ **【洞察之眸】(Eye of Insight - 来自小绵羊)**:
  > `A clean flat-shaded 3D skill icon of a simple golden eye emblem surrounded by puffy white cloud-like sheep wool. Untitled Goose Game art style, clean vector-like low-poly forms, pastel yellow and white on soft grey background --ar 1:1 --v 6.0`

- ⚡ **【疾风之步】(Stride of Gale - 来自烈马)**:
  > `A clean flat-shaded 3D skill icon of a dark iron horseshoe with two curved white wind-trail curves, in the art style of Untitled Goose Game. High contrast, dynamic, clean solid color blocks --ar 1:1 --v 6.0`
