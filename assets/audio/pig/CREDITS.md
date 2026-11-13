# 猪叫音效来源与许可

游戏内猪叫 SFX（`pig_snort_*.wav` / `pig_squeal_*.wav`）全部来自 Freesound.org 的 **CC0（Creative Commons 0）** 素材，
作者 **JarredGibb**（《Pig — 96kHz》系列），可免署名商用，本仓库以本文件留档致谢。
源文件为 96kHz WAV 的低码率 OGG 预览（lq），经 ffmpeg 裁掉首尾静音、峰值归一化（目标 -3 dBFS）、
12 ms 淡入后转成 16-bit 44.1kHz 单声道 WAV。

| 游戏内文件 | 源（freesound.org） | 原名 | 原时长 | 用途 |
| :--- | :--- | :--- | :--- | :--- |
| `pig_snort_a.wav` | freesound.org/s/JarredGibb/sounds/233156 | Pig - Snort 2 - 96kHz.wav | 0.49s | 空格跳跃哼哼（变体轮换） |
| `pig_snort_b.wav` | freesound.org/s/JarredGibb/sounds/233147 | Pig - Snort 1 - 96kHz.wav | 0.66s | 空格跳跃哼哼（变体轮换） |
| `pig_snort_c.wav` | freesound.org/s/JarredGibb/sounds/233157 | Pig - Snort 3 - 96kHz.wav | 0.83s | 空格跳跃哼哼（变体轮换） |
| `pig_squeal_a.wav` | freesound.org/s/JarredGibb/sounds/233153 | Pig - Scream 3 - 96kHz.wav | 1.10s | Shift+空格 惨叫跳 |
| `pig_squeal_b.wav` | freesound.org/s/JarredGibb/sounds/233151 | Pig - Scream 5 - 96kHz.wav | 1.76s | Shift+空格 惨叫跳（变体轮换） |

许可原文：https://creativecommons.org/publicdomain/zero/1.0/

## 备注

- 项目曾评估 Wikimedia Commons 的 Mudchute pig 1-3（CC BY-SA 3.0，需署名且 ShareAlike）与
  BigSoundBank 的 pig 音（CC0，s1658/s1659/s1691-1693），最终选用 Freesound 96kHz 系列：
  短促单发声单元、音色卡通、适合游戏内高频触发。
- 后续新增音频时沿用本文件格式登记：游戏内路径 → 源 URL → 许可证。
