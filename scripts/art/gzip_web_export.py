#!/usr/bin/env python3
"""Web 导出产物 gzip 后处理（创空间加载优化，2026-11-20）。

创空间静态托管（*.ms.show）不输出 Content-Encoding: gzip/br，
index.wasm / index.pck 裸传。导出后把这两个文件再存一份 .gz，
由自定义壳（scripts/art/piggame_web_shell.html）在浏览器端用
DecompressionStream 解压；.gz 缺失时壳自动回退原文件，两者都随包部署。

用法：python scripts/art/gzip_web_export.py [builds/web]
"""

import gzip
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
TARGETS = ("index.wasm", "index.pck")


def patch_index_js_audio_bus_bug(out_dir: Path) -> None:
    js_path = out_dir / "index.js"
    if not js_path.exists():
        return
    text = js_path.read_text(encoding="utf-8")
    bug_target = "if(index!==newBus.getId()){GodotAudio.Bus.move(newBus.getId(),index)}"
    fixed_target = "if(index!==-1&&index!==newBus.getId()){GodotAudio.Bus.move(newBus.getId(),index)}"
    if bug_target in text:
        text = text.replace(bug_target, fixed_target)
        js_path.write_text(text, encoding="utf-8")
        print("[patch] index.js: 修复 Godot 4.3 WebAudio SampleBus addAt(-1) 索引环路 Bug")


def main() -> int:
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else PROJECT_ROOT / "builds" / "web"
    if not (out_dir / "index.html").exists():
        print(f"未找到 {out_dir / 'index.html'}，先导出 Web Demo 预设")
        return 1
    patch_index_js_audio_bus_bug(out_dir)
    for name in TARGETS:
        src = out_dir / name
        if not src.exists():
            print(f"[skip] {name} 不存在")
            continue
        dst = out_dir / (name + ".gz")
        # mtime=0 保证产物可复现（同输入同输出，方便校验）
        with open(src, "rb") as f_in:
            with gzip.GzipFile(fileobj=open(dst, "wb"), mode="wb", compresslevel=9, mtime=0) as f_out:
                f_out.writelines(iter(lambda: f_in.read(1 << 20), b""))
        saved = 1 - dst.stat().st_size / src.stat().st_size
        print(f"{name}: {src.stat().st_size/1e6:.1f}MB -> {dst.stat().st_size/1e6:.1f}MB .gz（省 {saved*100:.0f}%）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
