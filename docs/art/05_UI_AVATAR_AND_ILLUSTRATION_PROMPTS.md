# 《一口猪在金牌农场》UI 视觉、对话头像与成就插画提示词库 (UI & Visual Identity)

> **文档定位**：为游戏 UI 交互体系提供统一规格的头像切片（Avatar Icons）、三大关键成就徽章（Achievement Badges）、三大伙伴觉醒能力图标（Skill Perks）、以及双结局全屏插画（Ending Storyboards）生成提示词。

---

## 一、对话头像框切片提示词 (Dialogue Avatar Bible)

### 1.1 头像设计规格
- **画幅与分辨率**：`1:1` 正方形，建议生成 `1024x1024`，裁切为带柔和圆角的 2.5D 粘土微缩半身像。
- **背景规范**：柔和纯色微模糊背景，带有微弱的环境顶光与轮廓光，边缘干净利落。

### 1.2 全角色头像提示词集

| 角色与表情状态 | 2D 提示词 (Midjourney / Flux / SDXL) |
| :--- | :--- |
| **猪“包子”·坚毅中立态 (默认)** | `Close-up bust portrait of a clever pale-pink farm pig, smart dark eyes looking forward with determination, bright yellow livestock ear tag with '047' on its left ear. Stylized 3D claymation aesthetic, soft matte skin, warm morning rim light, circular composition, clean warm grey blurred background, video game dialogue avatar icon --ar 1:1 --v 6.0` |
| **猪“包子”·口衔红铜插销态 (出逃)** | `Close-up bust portrait of a determined stylized pale-pink pig firmly clamping a heavy weathered green-patina bronze latch pin in its mouth, yellow ear tag '047', defiant rebellious expression. Stylized claymation 3D model, sharp rim light, game dialogue UI avatar --ar 1:1 --v 6.0` |
| **老岩羊·深邃嘲弄态** | `Close-up character portrait of a grizzled old mountain bighorn goat, magnificent spiraling ridge-textured horns, shaggy coarse grey wool, knowing smirk with rectangular pupils, cynical wise expression. Dramatic high-contrast mountain side lighting, stylized 3D claymation bust, game dialogue avatar --ar 1:1 --v 6.0` |
| **老黄牛·疲惫紧绷态** | `Close-up character portrait of a massive brown ox, strained tired eyes with heavy dark circles, furrowed brow, wearing a heavy cracked wooden harness collar. Stylized 3D claymation, dusty earth tones, empathetic weary expression, video game dialogue UI icon --ar 1:1 --v 6.0` |
| **老黄牛·痛饮释怀态** | `Close-up character portrait of a gentle brown ox, relaxed peaceful expression, water droplets dripping from its muzzle, soft warm morning lighting, released from tension. Stylized 3D claymation bust, heartwarming game avatar --ar 1:1 --v 6.0` |
| **小绵羊·自卑委屈态** | `Close-up portrait of a tiny, extremely fluffy white cloud-like sheep, drooping ears, big sad watery eyes, a crooked wooden tag around its neck reading '三等残次'. Stylized 3D claymation, soft fuzzy wool texture, emotional game dialogue avatar --ar 1:1 --v 6.0` |
| **小绵羊·沐光自洽态** | `Close-up portrait of an adorable fluffy white lamb bathed in a warm golden sunbeam, eyes gently closed in serene bliss, blissful happy smile, discarded wooden tag. Stylized 3D claymation, glowing warm halo, heartwarming game avatar icon --ar 1:1 --v 6.0` |
| **烈马“追风”·焦虑狂躁态** | `Close-up portrait of a dark chestnut racehorse, flaring nostrils, bulging veins, wide anxious bloodshot eyes, a faded dirty medal ribbon reading '41s'. Stylized 3D claymation, intense nervous energy, dynamic game dialogue avatar --ar 1:1 --v 6.0` |
| **烈马“追风”·嚼草从容态** | `Close-up portrait of a handsome dark chestnut horse with wild green dandelion grass in its mouth, soft bewildered yet relieved eyes, loosened jaw. Warm golden daylight, peaceful comedy, stylized claymation game avatar --ar 1:1 --v 6.0` |
| **农场主·手持电棍威慑态** | `Close-up bust portrait of a pragmatic middle-aged human farmer with a rough five-o'clock shadow, wearing a worn denim cap and canvas overalls, holding an electric baton casting faint blue spark light on his face, stern calculating gaze. Stylized 3D claymation, video game boss portrait --ar 1:1 --v 6.0` |
| **农场主·现实主义认栽态** | `Close-up bust portrait of a tired, disheveled middle-aged farmer wiping sweat and dirt from his cheek with his sleeve, indifferent realistic shrug, wry cynical smirk. Warm sunset dust light, stylized 3D claymation character icon --ar 1:1 --v 6.0` |

---

## 二、成就徽章与技能图标提示词 (Badges & Perks)

### 2.1 成就徽章图标 (Achievement Badges)
生成要求：3D 质感徽章、浮雕、纯黑或纯透明底、边缘发光、微缩模型风格。

```text
-- 通用前缀：
3D game achievement badge icon, isolated on black background, stylized tactile claymation and metallic relief, clean circular heraldic emblem, bevel edges, studio lighting:
```

- 🏆 **【温热的泥浆】(A Warm Wallower - 蓝线结局)**:
  > `...A glossy stylized pink pig peacefully curled inside a round wooden bowl filled with rich steaming chocolate-colored mud, surrounded by a subtle ring of golden fermented sweet corn kernels. Warm cozy amber glow, soothing and satirical tone --ar 1:1 --v 6.0`

- 🏆 **【红色的生锈插销】(The Rusty Bronze Latch Pin - 破门启程)**:
  > `...A heavy, ancient forged bronze latch pin bolt with authentic green verdigris patina, crossed over a splintered wooden farm latch beam. Brilliant dramatic red pill-like crimson rim light radiating from behind the bronze metal, sharp high-contrast cinematic lighting --ar 1:1 --v 6.0`

- 🏆 **【特立独行的先驱】(The Maverick Pioneer - 红线终局)**:
  > `...A soaring wooden cable car gondola silhouette flying downwards across a glorious blazing golden sunrise over rolling mountain ridges, accompanied by a soaring eagle crest. Brilliant golden-orange volumetric light, epic sense of unchained freedom, premium game trophy badge --ar 1:1 --v 6.0`

---

### 2.2 伙伴领悟能力图标 (Perk Icons)

- 🛡️ **【坚忍之骨】(Bone of Resilience - 来自老黄牛)**:
  > `A clean stylized 3D skill icon of an ancient sturdy ox horn crossed with a chipped granite stone, wrapped in heavy hemp rope, radiating a solid earthy brown and granite-grey protective aura shield. Tactile claymation game UI icon on solid dark background, isometric bevel --ar 1:1 --v 6.0`

- 👁️ **【洞察之眸】(Eye of Insight - 来自小绵羊)**:
  > `A clean stylized 3D skill icon of a wise luminous golden animal eye framed by soft, swirling white cloud-like sheep wool, parting dark grey storm clouds. Piercing warm golden light rays cutting through fog, stylized claymation UI perk button on dark background --ar 1:1 --v 6.0`

- ⚡ **【疾风之步】(Stride of Gale - 来自烈马)**:
  > `A clean stylized 3D skill icon of a polished iron horseshoe accelerating forward, trailing dynamic swirling green grass blades and white wind gust motion lines. High speed burst effect, stylized claymation game UI ability icon, vibrant and energetic --ar 1:1 --v 6.0`

---

## 三、双结局结算全屏插画 (Ending Storyboards)

### 3.1 蓝色结局：安稳的肉馅 (The Complacent Meatball)
```text
Bittersweet narrative ending screen illustration for a satirical indie video game. In a dimly lit, cozy rustic sty, a plump pink pig sleeps peacefully nestled deep in warm steaming mud with its chin resting on an empty feed trough, snoring soft bubbles. In the doorway, the cold blue shadow of dawn approaches with the silhouette of a steel transport truck hook outside. The title text space is clear. Handcrafted claymation aesthetic, tragicomedy, warm mud tones contrasted with icy dawn mist, emotionally resonant --ar 16:9 --v 6.0
```

### 3.2 红色结局：旷野的呼唤 (The Maverick's Flight)
```text
Triumphant cinematic game ending splash art. A rugged open-air wooden cable car gondola glides freely along a steep steel mountain cable, leaving the oppressive dark farm behind on the distant cliffs. The lone pink pig stands at the prow like a ship captain, wind ruffling its ears, ear tag '047' catching the morning sun. Ahead opens an immense, sun-drenched valley of undulating golden wheat fields, wild rivers, and untamed mountain horizons. Masterpiece, painterly Studio Ghibli meets Pixar stop-motion, overwhelming joy of liberation, 8k --ar 16:9 --v 6.0
```
