#!/usr/bin/env python3
"""GLB 贴图瘦身管线（web 加载优化，2026-11-20）。

背景：assets/models/aholo 的 133 个 *_game.glb 共 468MB，其中 96 张
2048x2048 内嵌 PNG 贴图占 419MB（90%）——创空间静态托管无 gzip，
480MB 裸传是加载慢的主因。平涂色块画风下贴图降到 512px 视觉无损，
像素 1/16，pck 预计 431MB -> ~60MB。

做法：保持网格/动画/蒙皮的 bufferView 偏移原样（新贴图字节追加在
BIN chunk 末尾，4 字节对齐），只重写 images 的 bufferView 与
buffers[0].byteLength，再紧凑化 JSON chunk。无 alpha 贴图量化到
256 色调色板（平涂艺术几乎无损，体积再降一半）；带 alpha 的保 RGBA。
已经是目标尺寸以内的贴图原字节保留，脚本幂等。

用法：
  python scripts/art/shrink_glb_textures.py            # 全库
  python scripts/art/shrink_glb_textures.py A/B.glb C/D.glb  # 指定文件
  python scripts/art/shrink_glb_textures.py --dry-run
  python scripts/art/shrink_glb_textures.py --max-size 256    # 更激进
回滚：模型源包 *_lux3d.zip 留在各资产目录，且 git 里有原版。
"""

import io
import json
import struct
import sys
from pathlib import Path

from PIL import Image

PROJECT_ROOT = Path(__file__).resolve().parents[2]
AHOLO_DIR = PROJECT_ROOT / "assets" / "models" / "aholo"
DEFAULT_MAX_SIZE = 512
GLB_MAGIC = 0x46546C67
CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942


def _load_glb(path: Path):
    data = path.read_bytes()
    magic, version, total = struct.unpack_from("<III", data, 0)
    if magic != GLB_MAGIC:
        raise ValueError("not a GLB")
    pos = 12
    json_chunk = None
    bin_chunk = None
    while pos + 8 <= total:
        clen, ctype = struct.unpack_from("<II", data, pos)
        cdata = data[pos + 8 : pos + 8 + clen]
        if ctype == CHUNK_JSON:
            json_chunk = cdata
        elif ctype == CHUNK_BIN:
            bin_chunk = cdata
        pos += 8 + clen + ((4 - (clen % 4)) % 4)  # 跳过 chunk padding
    doc = json.loads(json_chunk.decode("utf-8"))
    return doc, bin_chunk


def _reencode_image(raw: bytes, max_size: int) -> tuple[bytes, int, int]:
    """缩到 max_size 以内并重编码 PNG；返回 (新字节, 宽, 高)。"""
    img = Image.open(io.BytesIO(raw))
    img.load()
    w, h = img.size
    if max(w, h) > max_size:
        scale = max_size / max(w, h)
        img = img.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS)
    has_alpha = img.mode in ("RGBA", "LA", "PA") or (img.mode == "P" and "transparency" in img.info)
    buf = io.BytesIO()
    if has_alpha:
        img = img.convert("RGBA")
        img.save(buf, format="PNG", optimize=True)
    else:
        img = img.convert("RGB")
        img = img.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        img.save(buf, format="PNG", optimize=True)
    return buf.getvalue(), img.size[0], img.size[1]


def _pad4(n: int) -> int:
    return (4 - (n % 4)) % 4


def shrink_glb(path: Path, max_size: int, dry_run: bool = False) -> tuple[int, int, int]:
    """单个 GLB 瘦身。整体重建 BIN：非贴图 view 按序搬移（字节不变、偏移重排），
    贴图重编码后追加。返回 (原大小, 新大小, 重编码贴图数)。未变化时新大小==原大小。"""
    original = path.read_bytes()
    doc, bin_chunk = _load_glb(path)
    images = doc.get("images", [])
    buffers = doc.get("buffers", [])
    if not images:
        return len(original), len(original), 0
    if len(buffers) != 1 or bin_chunk is None:
        print(f"  [skip] {path.name}: 非单缓冲 GLB（buffers={len(buffers)}），不动")
        return len(original), len(original), 0

    views = doc["bufferViews"]
    image_views = {}
    for img in images:
        vi = img.get("bufferView")
        if vi is None:
            continue  # uri 外链（GLB 内不该出现）
        if views[vi].get("buffer", 0) != 0:
            print(f"  [skip] {path.name}: image 指向非 0 缓冲，不动")
            return len(original), len(original), 0
        image_views[vi] = img

    new_bin = bytearray()

    def _append_aligned(data: bytes) -> int:
        nonlocal new_bin
        if _pad4(len(new_bin)):
            new_bin += b"\x00" * _pad4(len(new_bin))
        start = len(new_bin)
        new_bin += data
        return start

    recompressed = 0
    for vi, view in enumerate(views):
        if vi in image_views:
            continue
        # 网格/动画/蒙皮等：字节原样搬移，只更新偏移
        off = view.get("byteOffset", 0)
        view["byteOffset"] = _append_aligned(bytes(bin_chunk[off : off + view["byteLength"]]))

    for vi, img in image_views.items():
        view = views[vi]
        off = view.get("byteOffset", 0)
        length = view["byteLength"]
        raw = bytes(bin_chunk[off : off + length])
        try:
            probe = Image.open(io.BytesIO(raw))
            probe.load()
            already_small = max(probe.size) <= max_size
        except Exception:
            already_small = False
        if already_small and raw[:8] == b"\x89PNG\r\n\x1a\n":
            view["byteOffset"] = _append_aligned(raw)  # 幂等：原字节保留，仅搬移
            continue
        new_raw, _w, _h = _reencode_image(raw, max_size)
        view["byteOffset"] = _append_aligned(new_raw)
        view["byteLength"] = len(new_raw)
        img["mimeType"] = "image/png"
        recompressed += 1

    if recompressed == 0:
        return len(original), len(original), 0

    buffers[0]["byteLength"] = len(new_bin)
    json_bytes = json.dumps(doc, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    json_pad = b" " * _pad4(len(json_bytes))
    bin_pad = b"\x00" * _pad4(len(new_bin))

    out = bytearray()
    total = 12 + 8 + len(json_bytes) + len(json_pad) + 8 + len(new_bin) + len(bin_pad)
    out += struct.pack("<III", GLB_MAGIC, 2, total)
    out += struct.pack("<II", len(json_bytes) + len(json_pad), CHUNK_JSON)
    out += json_bytes + json_pad
    out += struct.pack("<II", len(new_bin) + len(bin_pad), CHUNK_BIN)
    out += new_bin + bin_pad

    if len(out) >= len(original):
        # 重编码反而更大（理论少见）：放弃
        return len(original), len(original), 0
    if not dry_run:
        path.write_bytes(bytes(out))
    return len(original), len(out), recompressed


def main() -> int:
    argv = sys.argv[1:]
    dry_run = "--dry-run" in argv
    max_size = DEFAULT_MAX_SIZE
    if "--max-size" in argv:
        max_size = int(argv[argv.index("--max-size") + 1])
    args = [a for a in argv if not a.startswith("--")]
    if args:
        targets = [PROJECT_ROOT / a for a in args]
    else:
        targets = sorted(AHOLO_DIR.glob("*/*_game.glb"))
    total_before = total_after = total_imgs = 0
    changed = 0
    for p in targets:
        before, after, imgs = shrink_glb(p, max_size, dry_run)
        total_before += before
        total_after += after
        total_imgs += imgs
        if after != before:
            changed += 1
            print(f"  {p.parent.name}/{p.name}: {before/1e6:.1f}MB -> {after/1e6:.1f}MB ({imgs} 贴图)")
    print(
        f"\n== {len(targets)} 个 GLB，{changed} 个重写，{total_imgs} 张贴图重编码："
        f"{total_before/1e6:.0f}MB -> {total_after/1e6:.0f}MB (省 {(1-total_after/max(total_before,1))*100:.0f}%)"
        + ("  [dry-run]" if dry_run else "")
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
