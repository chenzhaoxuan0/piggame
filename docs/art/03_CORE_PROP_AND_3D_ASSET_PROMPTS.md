# 《一口猪在金牌农场》核心道具与 3D 资产提示词库 (Untitled Goose Game 风格版)

> **视觉风格基准**：**《无题大鹅模拟》(Untitled Goose Game)**  
> **核心特征**：极简多边形 (Clean Low-Poly)、纯色平涂 (Flat-Shaded Colors)、无杂质纹理 (Zero Texture Noise)、大形生动可读 (Bold Readable Silhouettes)。针对 **Aholo Lux3D** 几何生成具有天然极高的一致性与成功率。

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
| **PROP_07** | **农场主高压防暴电击棍** | P1 (对决资产) | `W: 0.12m, L: 0.75m, H: 0.12m` | 农场主的规训武器，带简约黄色小电弧 |

---

## 1. PROP_01：后山悬崖木质索道站与吊厢 (Cliff Cable Car Station & Gondola)

### 1.1 资产规格与设计规范
- **风格特征**：大鹅风格的质朴木质缆车。由厚实的低多边形原木木板拼合而成，四角有圆润小倒角；顶部是实心的深灰铸铁滑轮支架与双滑轮；设有一个专供红铜插销插入的极简插槽。
- **色彩色块**：风化木浅暖褐（`#8D7B68`）、铸铁深灰（`#374151`）、插槽纯黄铜色（`#D97706`）。

### 1.2 2D 概念图提示词 (Midjourney / Flux)
```text
A charming rustic wooden cable car gondola game asset, in the distinct art style of Untitled Goose Game. Built from clean, chunky low-poly pine wood planks with beveled edges, an open-topped box carriage with simple safety railings. Mounted on top is a solid dark-grey cast-iron arm with two clean circular pulley wheels gripped onto a thick overhead cable. Features a simple stylized brass slot on the mechanical brake. Flat-shaded low-poly 3D aesthetic, House House game style, solid color blocking, zero texture noise, soft warm diffuse lighting, pure solid white background, isometric 3/4 view --ar 1:1 --v 6.0
```

### 1.3 Aholo Lux3D 专用生成提示词 (Text-to-3D)
```text
Single isolated low-poly 3D model of a rustic wooden cable car gondola, in the art style of Untitled Goose Game. Simple box carriage made of chunky flat-shaded wooden planks, open top with clean wooden railings, topped with a solid dark grey iron pulley suspension arm. Minimalist indie game prop, clean watertight low-poly mesh, beveled polygon edges, pure flat-shaded solid color materials, zero texture noise. Solid pure white background, no floor, no shadows, isometric view.
```

---

## 2. PROP_02：后山重型大铁闸门与碎锁 (Heavy Iron Gate & Broken Padlock)

### 2.1 资产规格与设计规范
- **风格特征**：简洁有力的低多边形生铁大农场门。由平涂深灰方铁杆构成立体栅栏；双侧为几何多面体干垒石柱；中间附带断开成三块的黄色平涂破损挂锁与粗铁链。
- **色彩色块**：深黑铸铁（`#1F2937`）、石柱冷灰（`#9CA3AF`）、断锁明黄铜（`#F59E0B`）。

### 2.2 2D 概念图提示词 (Midjourney / Flux)
```text
A heavy double-door farm iron gate game asset, in the art style of Untitled Goose Game. Constructed from clean vertical square iron bars in solid dark charcoal-grey, flanked by two chunky faceted drystone pillars. In the center hangs a broken chunky yellow-brass padlock shattered into clean pieces with a short iron chain. Minimalist flat-shaded low-poly 3D style, House House aesthetic, bold clear silhouettes, solid color fills, zero texture noise, soft studio light on pure white background, isometric view --ar 1:1 --v 6.0
```

### 2.3 Aholo Lux3D 专用生成提示词 (Text-to-3D)
```text
Single isolated low-poly 3D model of a farm iron security gate, in the art style of Untitled Goose Game. Double gate doors with simple square vertical iron bars in flat dark grey, flanked by two faceted stone pillars, with a shattered chunky yellow brass padlock. Clean watertight low-poly polygon mesh, flat-shaded materials, zero texture noise. Pure solid white background, no ground, no shadows, isometric view.
```

---

## 3. PROP_03：生锈红铜插销 (The Rusty Bronze Latch Pin - 红丸信物)

### 3.1 资产规格与设计规范
- **风格特征**：极简厚重的低多边形圆柱插销。一端带有一个粗圆手柄环，表面由大块面的红铜底色与几片清爽的绿青色斑块构成，如同一件可爱的玩具拼图积木，辨识度极高。
- **色彩色块**：红铜底色（`#B85D3D`）+ 氧化铜绿块（`#52B788`）。

### 3.2 2D 概念图提示词 (Midjourney / Flux)
```text
A chunky antique bronze latch pin bolt prop, in the art style of Untitled Goose Game. Solid cylindrical low-poly metal body with a smooth ring handle on one end and a locking notch. Flat-shaded color blocking combining rich red-copper with clean patches of mint-green patina verdigris. Charming minimalist indie game inventory prop, House House aesthetic, smooth beveled edges, zero texture noise, soft studio lighting, pure solid white background, isometric 3D view --ar 1:1 --v 6.0
```

### 3.3 Aholo Lux3D 专用生成提示词 (Text-to-3D)
```text
Single isolated low-poly 3D model of a chunky bronze mechanical latch pin bolt, in the art style of Untitled Goose Game. Cylindrical copper bar with a loop handle, flat-shaded red-copper and teal-green color blocks. Clean watertight low-poly mesh, smooth beveled forms, untextured flat matte material. Pure solid white background, zero shadow, isometric view.
```

---

## 4. PROP_04：花岗岩顽石与卷刃深铁犁 (Granite Boulder & Chipped Plow)

### 4.1 资产规格与设计规范
- **风格特征**：由若干平滑多边形面构成的灰白色花岗岩大石块；旁边插着一把简单的深灰色生铁犁头，切角处有平整的缺口表示卷刃。
- **色彩色块**：岩石浅冷灰（`#E5E7EB`）、犁头铁灰（`#4B5563`）。

### 4.2 Aholo Lux3D 专用生成提示词 (Text-to-3D)
```text
Single isolated low-poly 3D model of a faceted granite rock and a chipped iron plow blade, in the art style of Untitled Goose Game. Simple polygonal grey boulder with clean beveled facets, wedged against a chunky dark-grey iron plow with a blunt chipped edge. Flat-shaded solid colors, zero texture noise, clean watertight low-poly mesh. Pure solid white background, no terrain, no shadow, isometric view.
```

---

## 5. PROP_05：“三等残次”木质评定吊牌 ("Grade 3 Defective" Wooden Sign)

### 5.1 资产规格与设计规范
- **风格特征**：一块极简长方形小木板，纯浅原木色，上方串着一根简约白绳，板上有简洁的三个黑色文字“三等残次”。

### 5.2 Aholo Lux3D 专用生成提示词 (Text-to-3D)
```text
Single isolated low-poly 3D model of a small wooden tag sign, in the art style of Untitled Goose Game. Flat rectangular pale wood board with a simple cord loop, painted with clean black markings reading '三等残次'. Clean low-poly geometry, flat-shaded solid colors, zero texture noise. Pure solid white background, isometric view.
```

---

## 6. PROP_06：35秒春季新纪录看板 (35s Farm Record Billboard)

### 6.1 资产规格与设计规范
- **风格特征**：双木立柱支撑的一块纯白长方形木板，四周有墨绿色纯色包边，正中工整印着黑色“35s”。

### 6.2 Aholo Lux3D 专用生成提示词 (Text-to-3D)
```text
Single isolated low-poly 3D model of a wooden farm record sign, in the art style of Untitled Goose Game. White rectangular wooden board with a dark-green border supported by two plain wooden posts, cleanly painted with bold black numbers '35s'. Flat-shaded indie game asset, clean low-poly mesh, zero texture noise. Pure solid white background, isometric view.
```

---

## 7. PROP_07：农场主高压防暴电击棍 (Electric Stun Baton)

### 7.1 资产规格与设计规范
- **风格特征**：黑色纯色手柄、亮黄色斜纹警示段、灰色平头顶端，顶端带有极简多边形亮黄色小电火花星标。

### 7.2 Aholo Lux3D 专用生成提示词 (Text-to-3D)
```text
Single isolated low-poly 3D model of an industrial electric stun baton, in the art style of Untitled Goose Game. Black cylindrical handle with bright hazard-yellow safety stripes, grey front tip, and a cute tiny stylized yellow spark polygon. Clean watertight low-poly mesh, flat-shaded solid colors, zero texture noise. Pure solid white background, isometric view.
```
