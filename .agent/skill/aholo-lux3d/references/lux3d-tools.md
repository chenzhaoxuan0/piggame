# Lux3D / Aholo MCP 工具速查

## 目录

- [Lux3D 工具](#lux3d-工具)
- [World（3DGS 重建/生成）工具](#world3dgs-重建生成工具)
- [通用工具](#通用工具)
- [关键参数速记](#关键参数速记)
- [Python 版备用通道](#python-版备用通道)

## Lux3D 工具

| Tool | 用途 |
| :--- | :--- |
| `lux3d_multimodal_to_image` | 多模态生图：`prompt` 和/或图片（`img` URL / `localPath`），至少给一个 |
| `lux3d_image_to_four_view` | 图片（URL / 本地 / 文案）→ 四张标准视图 |
| `lux3d_img_to_3d_from_file` | 本地文件 → 3D（推荐走这条，文件不过 MCP 协议） |
| `lux3d_img_to_3d` | 图片 URL → 3D |
| `lux3d_text_to_3d` | 文生 3D（`prompt` + `style` 必填，可选参考图） |
| `lux3d_material_transfer` | 参考图材质迁移到 GLB 模型 |
| `lux3d_multi_format_export` | ZIP/GLB → USDZ / OBJ / FBX / STL / 3MF |
| `lux3d_part_split` | GLB 部件拆分 |
| `lux3d_articulation_animation` | GLB + 提示词 → 关节化与动画 |
| `lux3d_humanoid_auto_rig` | 数字人 GLB 自动绑骨 |
| `lux3d_humanoid_animation_retarget` | 已绑骨模型动画重定向（1–10 个预设动作，GLB/FBX） |
| `lux3d_list_tasks` | 分页查询 Lux3D 历史任务，可按状态和时间筛选 |
| `lux3d_get_task` | 查询单个 Lux3D 任务 |
| `lux3d_wait_for_task` | 阻塞轮询直到任务完成 |

## World（3DGS 重建/生成）工具

本项目目前用不上（做的是单体资产，不是空间重建），列出来以免误选。

| Tool | 用途 |
| :--- | :--- |
| `world_inspect_local_media` | 只读：分析本地图片/视频 |
| `world_reconstruct_object_from_files` | 本地文件 → 物体（model）重建 |
| `world_reconstruct_space_from_files` | 本地文件 → 室内（space）重建 |
| `world_reconstruct_object` | URL → 物体（model）重建 |
| `world_reconstruct_space` | URL → 室内（space）重建 |
| `world_generate` | 3DGS 世界生成：纯文案 / 本地单图 / 图文（至多 1 张） |
| `world_get` / `world_wait_for` / `world_list` | 查询与轮询 world |

> 图片重建须 ≥ 20 张（`.jpg` / `.jpeg` / `.png` / `.webp`）；普通视频 `resourceType=video`（`.mp4` / `.mov`）；
> Insta360 全景 `resourceType=insv`（`.insv`）。`useMask=true` 表示抠图（主体分割）。

## 通用工具

| Tool | 用途 |
| :--- | :--- |
| `upload_asset` | 上传本地文件，返回 CDN URL（二进制不过 MCP 协议） |

## 关键参数速记

- `version`（图生/文生 3D 必填）：`G1` / `G1-Turbo`。
- `faceCount`：10000–300000。
- `outputFormat`：`zip` / `glb` / `ply`。
- `aiPredictSize`：开启后自动预测包围盒尺寸。
- 单图输入与多视角输入**二选一**。
- 提交类工具默认 `wait=false`，返回 `taskId` / `worldId`。
- 参考图只接受本地 `localPath`，不接受外部网络 URL。

## Python 版备用通道

MCP 不可用时的退路（skillhub 官方 Lux3D skill 的用法）：

```bash
pip install Pillow requests
export LUX3D_API_KEY="<与 AHOLO_API_KEY 相同的 Key>"
export LUX3D_BASE_URL="https://api.aholo3d.cn"
```

```python
from lux3d_client import generate_3d_model

result = generate_3d_model("path/to/subject.png")   # 图生 3D
result = generate_text_to_3d("生成一个高质量的 3D 木椅", style="photorealistic")
```

命令行等价写法：

```bash
python lux3d_client.py input.jpg output.zip
python lux3d_client.py text "生成一个高质量的 3D 木椅" output.zip --style photorealistic
python lux3d_client.py text "生成一个未来感的台灯" output.zip --style cyberpunk --image ref.png
```

鉴权头是 `Authorization: <apiKey>`，**不带 `Bearer` 前缀**。
结果 URL 有效期约 2 小时。

官方文档：`https://labs.aholo3d.cn/api-docs/mcp`、`https://labs.aholo3d.cn/api-docs/skills/lux3d`
