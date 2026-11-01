# 《一口猪在金牌农场》美术总风格与提示词工程体系规范

> **版本**：v2.0.0 (《无题大鹅模拟》风格全面对标版)  
> **核心对标基准**：**《无题大鹅模拟》(Untitled Goose Game)** —— 极简低多边形、平涂色块、零高频噪点、生动肢体叙事。  
> **制定目的**：统一全项目 2D 概念图、立绘、UI 以及 **Aholo Lux3D** 3D 资产生成的提示词语法标准，确保全流程资产与《无题大鹅模拟》的视觉美学纯度 100% 保持一致。

---

## 一、对标《无题大鹅模拟》四大核心视觉支柱 (Visual Pillars)

### 支柱 1：极简低多边形与明快纯粹剪影 (Minimalist Low-Poly & Bold Silhouettes)
- **造型哲学**：大形至简。剥离所有繁琐细碎的结构，仅用最精准的大几何块面勾勒动物与物件的特征。
- **倒角与边缘**：多边形带有温和圆润的边缘过渡（Soft Low-Poly），杜绝生硬割裂的尖角；远看轮廓极其清晰、一目了然（Readable at a glance）。
- **动势优于细节**：正如《大鹅》中的那只大白鹅依靠“伸颈、展翅、小碎步、叼东西”传递出极度丰满的生命力，本作主角猪同样依靠“四蹄小跑、卷尾摇摆、低头拱土、坚定叼插销”等生动剪影传达情绪。

### 支柱 2：色块平涂与零材质噪点 (Flat-Shaded Color Blocking, Zero Texture Noise)
- **材质质感**：**完全剔除**高频写实贴图（无真实皮肤毛孔、无写实毛发噪点、无繁复凹凸法线贴图）。
- **纯色平涂 (Flat / Cel Shading)**：依靠大面积柔和纯色块（Solid Color Fills）塑造形态，材质表现为哑光、半哑光漆面、纯净素土、无杂质的木头色块与氧化金属纯色。
- **Godot 4 引擎极致性能优势**：
  - 在 Godot 4 Compatibility 渲染器中，全部材质使用极简 `StandardMaterial3D`；
  - `diffuse_mode = Toon` 或 `Lambert`，`specular_mode = Disabled` 或 `Toon`；
  - 超低 Draw Call，0 纹理显存压力，Web 端和低配设备均可满帧 60 FPS 丝滑运行。

### 支柱 3：极简传神五官与留白艺术 (Minimalist Facial Features & Subtlety)
- **五官极度克制**：
  - 动物面部避免复杂的写实肌肉与眼睑结构，采用极其传神的**极简黑圆点眼睛 (Bead-like dot eyes)** 或简约线条眼；
  - 猪的鼻孔为两个清晰圆润的深粉点，耳朵大形干净；
  - 人类（农场主）借鉴《大鹅》中园丁、农夫的人设风格：无过度刻画的写实面孔，甚至采用略带剪影化的面部、粗犷胡茬与扁平工装帽，依靠肢体动作（如跌坐抓狂、拍灰耸肩）传达戏剧感。

### 支柱 4：英伦田园清新色调与叙事冷暖对比 (Pastoral Palette with Narrative Drama)
全作以质朴、自然、高雅的低饱和田园色系（Pastoral Palette）为底色，辅以局部鲜明标志色：

```text
[悬崖冷蓝雾] ──────► [农场工作区 (暖土褐与田园绿)] ──────► [后山铁门锈黑] ──────► [终局万顷麦浪纯金]
Slate Grey / Mist        Loam Brown / Meadow Green / Straw Yellow    Dark Iron / Rust Red       Pure Golden Wheat / Sky Blue
```

| 元素 | 色彩定位 | 16进制色值 | 视觉感知 |
| :--- | :--- | :--- | :--- |
| **主角猪“包子”** | 纯净粉肉色 | `#F7C5C8` | 干净温润，与大鹅的纯白有同等的视觉辨识度 |
| **【047】耳标** | 工业醒目柠檬黄 | `#FCD34D` | 全身最亮眼的人工规训色标 |
| **红铜插销 (红丸)** | 氧化铜绿 + 红铜本体 | `#52B788` + `#B85D3D` | 极简色块组合，古拙而神秘 |
| **农场黑土** | 浓郁深褐平涂 | `#3E2723` | 泥泞却质感纯净的大色块 |
| **农场草地/围栏** | 鼠尾草灰绿 / 风化原木 | `#74A87C` / `#8D7B68` | 经典《无题大鹅》田园标志背景色 |
| **小羊软毛** | 棉花纯白 | `#FAFAFA` | 蓬松大圆弧几何体 |
| **烈马暗栗** | 纯深栗色 | `#5D4037` | 矫健线条与极简黑鬃 |
| **旷野麦浪** | 暖金黄麦色 | `#F59E0B` | 终章自由的金色海洋 |

---

## 二、面向《无题大鹅模拟》风格的提示词工程公式体系

### 公式 A：2D 概念图 / 立绘 / 场景提示词公式 (Midjourney v6 / Flux / SDXL)

```text
[Subject & Characteristic Silhouette] + [Iconic Props in solid colors] + [Action & Expressive Posture] + [Environment with clean flat blocks] + [Art Style Modifier: "in the art style of Untitled Goose Game, House House game aesthetic, flat-shaded low-poly 3D, minimalist solid color blocks, smooth matte surfaces, no texture noise, simple bead eyes, charming English pastoral indie game"] + [Lighting: soft warm diffuse sunlight, clean directional contact shadows] + [--ar / control parameters]
```

**实操标准示例（主角猪 Red Choice 概念图）**：
> `A clean minimalist pale-pink farm pig, in the distinct art style of Untitled Goose Game. Simple elegant low-poly 3D geometry, smooth flat-shaded pastel pink body with no texture noise or skin pores, cute simple black dot eyes. A bright flat-yellow plastic tag stamped '047' clipped to its ear, and a subtle red circle stamp on its flank. The pig stands proudly, clamping a chunky, stylized low-poly oxidized green-bronze bolt in its snout. Standing on a low-poly grassy cliff edge with simple wooden rail fencing, overlooking soft morning mist. Flat shaded 3D game asset, House House art style, clean vector-like silhouette, charming indie game aesthetic, warm soft diffuse lighting, clean contact shadows, pastel pastoral color palette --ar 16:9 --v 6.0`

---

### 公式 B：Aholo Lux3D 3D 资产生成专用公式 (Text-to-3D / Image-to-3D)

《无题大鹅》风格对 Aholo Lux3D 生成是**绝对的重大利好**：模型没有复杂的毛发法线干扰，拓扑极其规整！

```text
[Single Isolated Low-Poly 3D Asset] + [Simplified Geometric Form with Beveled Edges] + [Material: Flat-shaded solid colors, smooth untextured matte finish, no bump map, zero texture noise] + [Style: in the art style of Untitled Goose Game, minimalist indie game prop, clean watertight low-poly mesh, House House aesthetic] + [Background: Pure solid white background, zero ground shadow, even studio lighting, orthographic/isometric 45 degree angle]
```

#### Aholo Lux3D 适配三大要诀：
1. **强制声明 `flat-shaded solid color blocks, no texture noise`**：阻止 3D 生成引擎自动添加肮脏杂乱的写实污渍或碎面。
2. **声明 `clean watertight low-poly geometry with soft beveled edges`**：确保网格面数克制，边缘圆润自然。
3. **坚持单色白底孤立**：生成结果便于一键入引擎赋色。

---

## 三、专用负向提示词词库 (Universal Negative Prompts)

```text
(worst quality, low quality:1.4), photorealistic, skin pores, hyperrealistic fur, hair noise, complex normal map, noisy textures, dirty grunge textures, micro-details, ultra-realistic, uncanny valley, cinematic film grain, neon cyberpunk, high-poly details, messy topology, human eyes on animals, clothing on animals (pants, shirts), flat 2D flash vector, blurry, text, watermark.
```
