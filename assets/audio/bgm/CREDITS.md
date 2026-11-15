# BGM 来源与许可（Kevin MacLeod · CC BY 4.0）

游戏内背景音乐（`assets/audio/bgm/*.mp3`）全部来自 **Kevin MacLeod (incompetech.com)**，
以 **Creative Commons Attribution 4.0** 许可发布：**署名后可免费商用**。
署名义务落在两处，新增或更换曲目时**两处同步改**：

1. **游戏内**：主菜单 → 「📜 制作名单与致谢」面板（渲染 `scripts/core/music_manager.gd` 的 `CREDITS_DATA`）；
2. **本文件**：按下方表格登记。

逐曲署名格式（incompetech 官方指定，`Title` 换成实际曲名）：

```
"Title" Kevin MacLeod (incompetech.com)
Licensed under Creative Commons: By Attribution 4.0
https://creativecommons.org/licenses/by/4.0/
```

| 游戏内文件 | 曲名 | 播放 id | 用途 | 源 |
| :-- | :-- | :-- | :-- | :-- |
| `Carefree.mp3` | Carefree | menu / farm / ending | 主菜单、农场自由探索、结局 | [incompetech 搜索：Carefree](https://incompetech.com/music/royalty-free/index.html?Search=Carefree) |
| `Not As It Seems.mp3` | Not As It Seems | nightmare | 序章 · 噩梦屠宰场 | [incompetech 搜索：Not As It Seems](https://incompetech.com/music/royalty-free/index.html?Search=Not%20As%20It%20Seems) |
| `The Builder.mp3` | The Builder | ox_field | 第一章 · 牛耕地 | [incompetech 搜索：The Builder](https://incompetech.com/music/royalty-free/index.html?Search=The%20Builder) |
| `Itty Bitty 8 Bit.mp3` | Itty Bitty 8 Bit | creek | 第二章 · 溪谷（体素） | [incompetech 搜索：Itty Bitty 8 Bit](https://incompetech.com/music/royalty-free/index.html?Search=Itty%20Bitty%208%20Bit) |
| `Sneaky Snitch.mp3` | Sneaky Snitch | woodland | 第三章 · 林间（纸箱潜行） | [incompetech 搜索：Sneaky Snitch](https://incompetech.com/music/royalty-free/index.html?Search=Sneaky%20Snitch) |
| `Who Likes to Party.mp3` | Who Likes to Party | courtyard | 终章 · 大院金牌杯 | [incompetech 搜索：Who Likes to Party](https://incompetech.com/music/royalty-free/index.html?Search=Who%20Likes%20to%20Party) |
| `Run Amok.mp3` | Run Amok | chase | 追逐战 | [incompetech 搜索：Run Amok](https://incompetech.com/music/royalty-free/index.html?Search=Run%20Amok) |

许可原文：<https://creativecommons.org/licenses/by/4.0/>

## 备注

- 直链下载自 `incompetech.com/music/royalty-free/mp3-royaltyfree/{曲名}.mp3`（需浏览器 UA）。
  曾评估 `Cipher` 作序章曲但该直链 404，改选 `Not As It Seems`（诡异好奇感更贴"这里有什么不对劲"的发现节奏）。
- 全曲整段循环（`AudioStreamMP3.loop`），白盒阶段不切分 loop 点；后期如需无缝循环可换 incompetech 的 OGG/WAV 版本。
- 音量基线：BGM -11~-13 dB（`music_manager.gd` 的 `TRACKS` 每曲可调），对话 VO -3 dB、猪叫 -6 dB，三层互不压制。
- 不允许将音频文件原样作为独立音轨再分发；随游戏打包发行属于同步使用，属许可允许范围。
- 后续新增音频时沿用本文件格式登记：游戏内路径 → 曲名/作者 → 许可证 → 源链接。
