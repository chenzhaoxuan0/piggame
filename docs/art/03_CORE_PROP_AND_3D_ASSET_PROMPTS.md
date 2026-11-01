# 《一口猪在金牌农场》核心道具与 3D 资产提示词库 (Core Prop & Lux3D Prompts)

> **核心定位**：专为 **Aholo Lux3D** 3D 资产生成管线设计。本清单包含比赛必评的 P0 核心资产与场景叙事道具，每一件均提供详尽的物理尺寸包围盒规范、2D 概念图提示词、以及 **Aholo Lux3D 专用 Text-to-3D / Image-to-3D 提示词**。

---

## 资产优先级总览 (Asset Priority Matrix)

| 资产编号 | 资产名称 | 优先级 | 尺寸规格 (Godot 包围盒) | 核心叙事/玩法功能 |
| :--- | :--- | :---: | :---: | :--- |
| **PROP_01** | **后山悬崖木质索道站与吊厢** | **P0 (比赛核心)** | `W: 2.8m, L: 2.2m, H: 2.6m` | 游戏终章唯一逃生载具，插销触发滑翔动画 |
| **PROP_02** | **后山重型大铁闸门与碎锁** | **P0 (比赛核心)** | `W: 4.5m, L: 0.6m, H: 3.2m` | 终局人猪对决边界，阻挡/破门撞碎演出 |
| **PROP_03** | **生锈红铜插销 (红丸道具)** | **P0 (叙事核心)** | `W: 0.1m, L: 0.35m, H: 0.1m` | 贯穿全剧的红色抉择信物/索道启动钥匙 |
| **PROP_04** | **花岗岩顽石与卷刃深铁犁** | P1 (交互资产) | `W: 1.6m, L: 2.0m, H: 1.1m` | 老黄牛耕作区，阻碍老牛的执念顽石 |
| **PROP_05** | **“三等残次”木质评定吊牌** | P1 (交互资产) | `W: 0.25m, L: 0.05m, H: 0.35m` | 小绵羊身上悬挂的荒诞工业粗规训木牌 |
| **PROP_06** | **35秒春季新纪录看板** | P1 (调查资产) | `W: 1.8m, L: 0.4m, H: 2.2m` | 烈马跑道旁的新纪录板，打破41秒金牌执念 |
| **PROP_07** | **农场主高压防暴电击棍** | P1 (对决资产) | `W: 0.12m, L: 0.75m, H: 0.12m` | 农场主的规训武器，带冷蓝电弧火花 |

---

## 1. PROP_01：后山悬崖木质索道站与吊厢 (Cliff Cable Car Station & Gondola)

### 1.1 资产规格与设计规范
- **功能**：玩家叼着铜插销走到索道前，插入插槽，木吊厢滑轮释放，冲向万顷麦浪（终章通关标志）。
- **几何构成**：
  - **吊厢本体**：坚固松木板铆接的半开放木箱，带有木质安全扶手栏杆、底板有微小防滑木条。
  - **顶部滑轮机构**：重型铸铁双滑轮组、铁质弯钩悬臂吊架、粗钢缆穿行槽，包含一个明显的铜插销锁止插槽。
- **材质特点**：高山风化开裂的深色防腐松木、生锈铸铁机械件、铜绿滑道。

### 1.2 2D 概念图提示词 (Midjourney / Flux - 用于 Image-to-3D 参考)
```text
Detailed 3D game asset concept art of a rustic alpine wooden cable car gondola hanging from a heavy overhead iron pulley system. Constructed from weathered dark pine planks, sturdy iron rivets, an open-top wooden carriage with safety railings, sized for a pig or small animal. Above the carriage is a heavy forged-iron suspension arm with two large grooved cast-iron pulley wheels gripped onto a thick steel braided cable. Features an ancient bronze mechanical slot on the release brake. Stylized low-to-mid poly aesthetic, warm tactile clay and timber textures, Nintendo and Ghibli art style, clean isometric 3/4 view on pure white background, no scenery, studio lighting --ar 1:1 --v 6.0
```

### 1.3 Aholo Lux3D 专用生成提示词 (Text-to-3D)
```text
Single isolated 3D model of a rustic wooden mountain cable car gondola, sturdy box carriage built of thick weathered timber planks with iron bolt reinforcements, open-air wooden safety railings. On top is a solid forged iron hanging arm with a pair of heavy grooved cast-iron pulleys and a mechanical bronze latch slot. Stylized 3D game prop, clean watertight geometry, beveled polygon edges, matte clay and weathered cedar wood PBR textures, game-ready low-to-mid poly mesh. Solid pure white background, zero floor contact, no cast shadows, neutral even studio lighting, 3/4 isometric perspective.
```

---

## 2. PROP_02：后山重型大铁闸门与碎锁 (Heavy Iron Gate & Rusted Padlock)

### 2.1 资产规格与设计规范
- **功能**：横跨后山主通路的重型铁门，两扇可向外撞开，中间带有铁链与被撞碎断裂的巨型铜挂锁。
- **几何构成**：粗壮的方铁框架、竖直铁栅栏（间距不可通过猪身）、顶部带有生锈防攀铁尖、双侧厚重铰链固定在风化石柱上。
- **材质特点**：斑驳暗红生铁锈蚀、底漆剥落、重金属碰撞划痕。

### 2.2 2D 概念图提示词 (Midjourney / Flux)
```text
Game asset concept art of a massive, heavy industrial farm iron security gate on a solid white background. Two swinging gate doors made of thick vertical rusted wrought iron bars and a heavy horizontal crossbeam, secured by a thick rusty steel chain and a shattered heavy brass padlock broken into three jagged pieces. Flanked by two weathered chiseled fieldstone gate pillars. Weathered rust patina, peeling dark grey industrial paint, tactile metallic surface. Stylized 3D game prop, clean silhouette, isometric view, warm neutral studio lighting --ar 1:1 --v 6.0
```

### 2.3 Aholo Lux3D 专用生成提示词 (Text-to-3D)
```text
Single isolated 3D model of a heavy double-door farm iron gate, thick vertical square iron bars, horizontal structural crossbars, rusted dark wrought iron with orange rust flecks, flanked by two sturdy weathered dry-stone square pillar posts. Includes a heavy broken metal padlock dangling from a wrapped iron chain. Stylized 3D game prop, clean manifold mesh, beveled iron edges, game-ready topology, PBR matte metal and stone textures. Pure solid white background, no ground plane, no cast shadows, studio lighting, front 3/4 isometric angle.
```

---

## 3. PROP_03：生锈红铜插销 (The Rusty Bronze Latch Pin - 红丸信物)

### 3.1 资产规格与设计规范
- **功能**：黑客帝国红丸的实体化象征。老岩羊在序幕踢出，小猪全程衔在嘴中，最终插入后山索道启动突围。
- **几何构成**：粗壮圆柱形古旧红铜螺栓插销，一端带有粗圆手柄环，另一端带有防滑定位凹槽。
- **材质特点**：本体为沉重暗红纯铜，表面有青绿色氧化铜锈斑（Verdigris）、多道历经撞击与风化的钝感划痕。

### 3.2 2D 概念图提示词 (Midjourney / Flux)
```text
Macro 3D game prop concept art of an ancient, heavy forged bronze mechanical latch pin bolt. Cylindrical solid copper body with a rounded ring pull handle on one end and a notched locking groove on the other. Beautiful rich red-bronze metallic surface covered in authentic teal-green verdigris patina and weathered scratch marks, tactile physical presence. Stylized claymation and stop-motion game prop, soft cinematic studio spotlight highlighting the metallic glint and verdigris, pure clean white background, isometric 3D view --ar 1:1 --v 6.0
```

### 3.3 Aholo Lux3D 专用生成提示词 (Text-to-3D)
```text
Single isolated 3D model of an antique heavy bronze latch pin bolt, solid cylindrical copper bar with a thick circular loop handle on one end and a latch slot at the tip. Rich red-copper metal surface with realistic green patina verdigris flecks and subtle weathered scratches. Stylized 3D game inventory prop, clean watertight polygon topology, smooth beveled silhouette, PBR semi-matte metallic shader. Pure solid white background, zero ground shadow, even 360 studio lighting, isometric 45 degree angle.
```

---

## 4. PROP_04：花岗岩顽石与卷刃深铁犁 (Granite Boulder & Chipped Plow)

### 4.1 资产规格与设计规范
- **功能**：老黄牛耕作区域的核心障碍物，深埋在黑土中导致耕犁损坏卷刃，揭露“不是牛力不够，是地里有不可撼动的顽石”。
- **几何构成**：一块带有天然棱角的灰白色巨大花岗岩原石（上部露出，下部带有深土痕迹），旁边斜插着一具崩口卷刃的厚重古法铁犁铧头。

### 4.2 Aholo Lux3D 专用生成提示词 (Text-to-3D)
```text
Single isolated 3D model of an ancient chipped iron farm plow blade stuck wedged against a huge rough granite boulder. The rock is a weathered natural grey granite stone with angular facets. The plow blade is heavy forged cast iron, with a jagged blunt broken corner on the cutting edge. Stylized 3D environmental game prop, clean watertight low-poly topology, beveled stone planes, matte stone and rusted iron PBR textures. Pure solid white background, no terrain, no cast shadow, soft studio lighting, isometric view.
```

---

## 5. PROP_05：“三等残次”木质评定吊牌 ("Grade 3 Defective" Wooden Sign)

### 5.1 资产规格与设计规范
- **功能**：挂在小绵羊颈部、或插在剪毛矮棚栏杆上的规训标牌。
- **几何构成**：一块粗糙的破旧胶合板木牌，边缘有锯齿磨损，顶部有粗黄麻绳悬挂孔，牌面上用粗黑油漆写着手写汉字“三等残次”。

### 5.2 Aholo Lux3D 专用生成提示词 (Text-to-3D)
```text
Single isolated 3D model of a small rustic rectangular wooden penalty tag sign, made of coarse splintered plywood with beveled worn edges, tied with a loop of rough hemp rope at the top. On the face of the wooden board is weathered dark paint markings reading Chinese text '三等残次'. Stylized 3D narrative prop, clean polygon mesh, tactile wood grain and fiber texture, game-ready asset. Pure solid white background, no floor, no shadows, studio lighting, isometric view.
```

---

## 6. PROP_06：35秒春季新纪录看板 (35s Farm Record Billboard)

### 6.1 资产规格与设计规范
- **功能**：烈马赛道入口处的现代化公告木牌，标明“春季纯血马速记: 35秒”，打破烈马的41秒神话。
- **几何构成**：双木立柱支撑的一块白底绿边长方形告示板，干净规范，与农场其他破烂设施形成荒诞反差。

### 6.2 Aholo Lux3D 专用生成提示词 (Text-to-3D)
```text
Single isolated 3D model of a rustic farm race record billboard sign, mounted on two sturdy square wooden post legs. A clean painted cream-white rectangular sign board with a dark green border, displaying crisp bold numbers '35s' and clean farm lettering. Stylized 3D game prop, clean watertight low-poly mesh, beveled wooden edges, matte paint texture. Pure solid white background, no ground, no shadow, studio lighting, front isometric view.
```

---

## 7. PROP_07：农场主高压防暴电击棍 (Electric Stun Baton)

### 7.1 资产规格与设计规范
- **功能**：终局人猪对战中农场主手持的武器，象征现代技术规训。第三回合被小猪全力撞飞跌落。
- **几何构成**：圆柱形工业聚合物手柄，带黑黄相间警示条纹与防滑橡胶槽，前端为金属电击电极齿，伴有电火花效果槽。

### 7.2 Aholo Lux3D 专用生成提示词 (Text-to-3D)
```text
Single isolated 3D model of an industrial electric stun baton, black ribbed rubber grip handle with hazard yellow diagonal safety stripes, a safety switch button, and a durable grey metal front rod tipped with two dull electrical contact prongs. Stylized 3D weapon prop, clean low-poly watertight topology, beveled edges, matte polymer and brushed metal PBR textures. Pure solid white background, no ground, no shadow, neutral studio lighting, angled isometric view.
```
