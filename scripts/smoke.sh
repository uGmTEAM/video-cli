#!/usr/bin/env bash
# 容器内冒烟测试：渲染示例 -> 探测 -> 抽帧 -> GIF -> 封面
set -euo pipefail
OUT="${1:-/tmp/vcli-smoke}"
rm -rf "$OUT"
mkdir -p "$OUT"
cd "$OUT"

echo "== doctor =="
video doctor --json

echo "== demo =="
video demo --out "$OUT/demo.mp4" --json

echo "== probe =="
video probe "$OUT/demo.mp4" --json

echo "== frames =="
video frames "$OUT/demo.mp4" --at 1,5 --out "$OUT/frames" --json

echo "== gif =="
video gif "$OUT/demo.mp4" --start 0 --end 2 --width 360 --out "$OUT/demo.gif" --json

echo "== cover =="
video cover "$OUT/demo.mp4" --at 1 --title "封面标题" --subtitle "video-cli" --out "$OUT/cover.png" --json

echo "== 产物 =="
ls -lh "$OUT"
