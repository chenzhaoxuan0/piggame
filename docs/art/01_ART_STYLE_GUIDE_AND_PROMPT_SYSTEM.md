# 《一口猪在金牌农场》美术总风格与提示词工程体系规范

> **版本**：v1.0.0 (生产定稿版)  
> **制定目的**：统一本项目所有 2D 概念图、立绘、UI 以及 **Aholo Lux3D** 3D 资产生成的提示词语法标准与视觉调性，确保全流程资产风格高度统一，避免“各抽各卡、拼装割裂”。

---

## 一、美术三大核心支柱 (Visual Pillars)

### 支柱 1：风格化粘土微缩模型 / 手绘手作质感 (Stylized Claymation & Hand-Crafted Low-Poly)
- **视觉参考**：《小羊肖恩》(Shaun the Sheep) 粘土质感 +《无题大鹅模拟》(Untitled Goose Game) 简约诙谐 +《小小大星球》微缩模型光影 + 吉卜力田园朴素调色。
- **几何特征**：边缘带有微弱倒角（Bevel/Soft Edges），绝无生硬的刀切锐角，具有温润的实体感；造型大形明确、轮廓剪影清晰利落（Silhouettes First）。
- **材质倾向**：哑光自然材质为主——略带手工指纹微痕的粉嫩粘土、风化开裂的原木、生锈铁皮、氧化带有绿斑的红铜、蓬松棉花般的羊毛、带有水汽的黑泥土。
- **渲染器匹配**：完美契合 Godot 4 **Compatibility** 渲染器，不依赖高功耗实时光线追踪，依靠清晰的漫反射贴图、温和的环境遮挡 (AO) 和主方向平行光即能呈现极高品质。

### 支柱 2：叙事化光影与情绪光谱 (Narrative Lighting & Color Script)
游戏场景自山顶绝壁一路向下至后山索道，光影色调伴随戏剧冲突递进：

```text
[山顶悬崖猪圈] ─────► [农场工作区 (牛/羊/马)] ─────► [后山铁门对决] ─────► [索道突围·旷野]
  冷冽晨雾/青灰石壁        泥泞黑土/漏光木棚/尘土赛道         冷酷生铁/电棍蓝弧/压迫逆光       暖金麦浪/朝阳破晓/无垠碧空
  (压抑、命悬一线)          (麻木日常下的温存与荒诞)            (冲突高潮、生死一击)             (自由、广阔、生命力觉醒)
```

| 场景阶段 | 主色系与色值参考 | 光影氛围 | 情绪意图 |
| :--- | :--- | :--- | :--- |
| **序幕·山顶悬崖** | 冷青灰 `#5C6B73`、雾白 `#E0E1DD`、锈红 `#9E2A2B` | 晨曦薄雾穿透冷石墙，微弱冷色天光，高对比悬崖深渊 | 孤绝、冰冷、红蓝抉择的生死关头 |
| **老黄牛·黑土垄** | 深黑土 `#2B2118`、湿水渠 `#4A6B6C`、花岗岩灰 `#787878` | 低角度晨光斜射湿润泥垄，犁沟反光，水渠清冽 | 沉重负累、筋骨酸痛与一捧凉水的释怀 |
| **小绵羊·剪毛矮棚** | 稻草米黄 `#DDA15E`、柔白 `#F8F9FA`、阴影深褐 `#3D312A` | 破漏屋顶洒落的倾斜丁达尔光束（Godot雾片），阴暗角落与温暖光斑对比 | 错判的自卑与沐浴阳光时的自洽 |
| **烈马·泥圈赛道** | 扬尘黄褐 `#BC6C25`、朽木灰 `#6C584C`、荒草绿 `#606C38` | 扬起沙尘的干热逆光，斑驳的赛道木栏，杂乱无章的荒草 | 盲目狂奔的焦虑与探头嚼野草的初醒 |
| **终局·后山铁门** | 工业深铸铁 `#1B1B1E`、挂锁锈橙 `#A44A3F`、电弧电光蓝 `#00F0FF` | 压迫感强的顶光与轮廓逆光，电棍火花冷光撕裂昏暗 | 现实主义权威的压迫与决死撞击 |
| **结局·万顷旷野** | 金黄麦浪 `#EE9B00`、秋草金 `#CA6702`、苍穹天蓝 `#90E0EF` | 漫天金色夕阳与朝晖交融，风吹麦浪的流动高光，天高地阔 | 挣脱一切规训后的纯粹自由 |

### 支柱 3：去符号化的真实克制 (Restrained Satirical Realism)
- **拒绝过度拟人化**：猪保持四蹄着地的真实肉猪体态（健硕、圆润、灵活），绝不画成穿裤子直立行走的滑稽卡通猪；牛羊马均保留动物原本的骨骼与生态。
- **身份标识克制植入**：
  - 猪耳上的黄色工程塑料耳标【047】、臀部淡红色的“准予出栏”检疫滚轮印戳；
  - 羊颈上的粗劣手写木牌“三等残次”；
  - 烈马胸前破旧褪色的“41秒”缎带铜牌；
  - 嘴里叼着的重型生锈红铜插销（作为红丸信物与索道物理钥匙）。

---

## 二、提示词工程结构化公式体系 (Master Formulas)

为保证全团队输出的一致性，本项目定义两种专用提示词公式：

### 公式 A：2D 概念图 / 角色立绘 / 场景原画 (Midjourney v6 / SDXL / Flux)

```text
[核心主体与角色特征] + [标志性道具与穿着细节] + [动态姿态与微表情] + [环境背景与空间构图] + [材质与工艺细节] + [光影与色彩剧本] + [艺术风格与媒介修饰词] + [画幅与渲染控制参数]
```

**示例解析（主角猪“包子” red choice 概念图）**：
> `A determined and sturdy pale-pink young farm pig, four legs grounded, holding a heavy weathered oxidized bronze latch pin firmly in its mouth. A bright yellow plastic livestock ear tag with black stamped text '047' clipped to its left ear, a faint circular red inspection stamp mark on its hindquarter. Standing defiantly before a broken wooden fence on a dramatic cliff edge. Atmospheric early morning mist, soft sunrise light breaking through cool fog, rim light on pig's back. Stylized 3D claymation aesthetic, handcrafted stop-motion feel, tactile clay and weathered wood textures, Nintendo and Pixar art style, isometric game art perspective, clean composition, warm yet restrained color palette, 8k resolution, Unreal Engine 5 render style --ar 16:9 --v 6.0 --style raw`

---

### 公式 B：Aholo Lux3D 3D 资产生成专用公式 (Text-to-3D Optimization)

Aholo Lux3D 等 3D 生成大模型对提示词的**空间拓扑、单体纯净度、无遮挡视角**有极高要求。提示词必须剔除所有场景干扰：

```text
[Single Isolated 3D Asset Name] + [Geometric Structure & Silhouette Description] + [Detailed Material Specs: PBR Matte/Metal/Roughness] + [Neutral Studio Lighting & Shadows] + [Style: Stylized 3D Game Asset, Low-to-Mid Poly, Clean Watertight Topology] + [Pure Solid White Background, No Floor Shadows, Orthographic/Isometric Angle]
```

#### Aholo Lux3D 生成四大黄金准则：
1. **必须声明单件孤立 (Single Isolated Object)**：避免模型生成时粘连地面、杂草、背板或多重碎片。
2. **纯色白底与无阴影 (Pure Solid White Background, No cast shadows)**：防止模型将投影当成几何体下沿生成多余面。
3. **结构部件必须物理合理 (Physically Plausible Construction)**：如索道必须说明“厚实原木支架、铸铁滑轮、钢缆插槽”，便于模型生成清晰的接缝。
4. **指定材质反光特性 (PBR Material Hints)**：明确 `matte painted clay`（哑光粘土）、`rough weathered timber`（粗糙风化木）、`tarnished bronze with green verdigris`（氧化铜绿）。

---

## 三、通用负向提示词词库 (Universal Negative Prompts)

在任何生成平台中，请始终附带以下负向过滤词组：

### 2D 概念图通用 Negative Prompt:
```text
(worst quality, low quality:1.4), photorealistic human face, pores, hyperrealistic fur noise, uncanny valley, mutated limbs, extra legs, extra ears, broken anatomy, modern technology, neon lights, cyberpunk, robotic parts, text watermark, signature, blurry, cropped, out of frame, oversaturated colors, flat 2D flash vector, Disney princess eyes, anthropomorphic clothing on animals (pants, shoes, suits).
```

### Aholo Lux3D 3D 生成专用 Negative Prompt:
```text
complex background, scenery, landscape, ground surface, terrain, shadows on floor, cast shadow, multiple objects, collage, overlapping duplicates, floating debris, non-manifold geometry, hollow interior, thin fragile wires, disconnected floating parts, blurry textures, text, watermark, high-frequency noisy hair particles, realistic human anatomy.
```

---

## 四、色彩系统与色值速查表 (Color Token Map)

```css
/* 《一口猪在金牌农场》全局色彩设计标准 */
:root {
  /* 叙事象征色 */
  --color-red-pill:       #B83A2C; /* 红色抉择 / 生锈红铜主色 */
  --color-blue-pill:      #4A6FA5; /* 蓝色宿命 / 冰冷泥坑与卡车阴影 */
  --color-freedom-gold:   #E0A938; /* 旷野麦浪 / 终极自由金 */
  --color-warning-tag:    #F7C844; /* 047黄耳标 / 秩序规训警示 */

  /* 自然环境基底色 */
  --color-cliff-stone:    #5A6570; /* 悬崖冷灰石壁 */
  --color-morning-mist:   #DCE4EC; /* 清晨冷雾 */
  --color-black-loam:     #2E231B; /* 黑土垄耕作土 */
  --color-weathered-wood: #7D6B58; /* 风化朽烂木桩与围栏 */
  --color-iron-rust:      #8F4F35; /* 铁门锈迹与犁头崩缺处 */
  --color-bronze-patina:  #5B8E7D; /* 铜插销氧化绿斑 */
  
  /* 角色专有主色 */
  --color-pig-pale-pink:  #F4C2C2; /* 肉猪白净微粉肤色 */
  --color-ox-dun-brown:   #5C4033; /* 老黄牛厚重深棕 */
  --color-sheep-cloud:    #FAF9F6; /* 小绵羊纯净云朵软毛 */
  --color-horse-bay:      #4A2E18; /* 烈马暗栗色皮毛 */
  --color-farmer-overalls:#354F52; /* 农场主洗褪色工装蓝绿 */
  --color-stun-spark:     #5BC0BE; /* 电击棍冷色电弧蓝 */
}
```
