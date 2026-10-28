#!/usr/bin/env bash
# 安装运行依赖。优先使用 vendor/ 内的离线包；缺失时在 root 下回退 apt。
# 用法：bash scripts/install.sh [--container]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR="$ROOT/vendor"
MODE="${1:-user}"

if [ "$MODE" = "--container" ]; then
  BIN_DIR="/usr/local/bin"
  FONT_DIR="/usr/local/share/fonts/video-cli"
else
  BIN_DIR="${HOME}/.local/bin"
  FONT_DIR="${HOME}/.local/share/fonts/video-cli"
fi
mkdir -p "$BIN_DIR" "$FONT_DIR"

is_root() { [ "$(id -u)" = "0" ]; }

echo "== video-cli 依赖安装（$MODE）=="

# ---------- ffmpeg / ffprobe ----------
if [ -x "$VENDOR/ffmpeg/ffmpeg" ] && [ -x "$VENDOR/ffmpeg/ffprobe" ]; then
  install -m 0755 "$VENDOR/ffmpeg/ffmpeg" "$BIN_DIR/ffmpeg"
  install -m 0755 "$VENDOR/ffmpeg/ffprobe" "$BIN_DIR/ffprobe"
  echo "ffmpeg: 使用 vendor 离线二进制"
elif command -v ffmpeg >/dev/null 2>&1 && command -v ffprobe >/dev/null 2>&1; then
  echo "ffmpeg: 使用系统已安装版本"
elif is_root; then
  echo "ffmpeg: vendor 未提供，尝试 apt 安装"
  apt-get update
  apt-get install -y --no-install-recommends ffmpeg
else
  echo "错误: 缺少 ffmpeg。请先运行 scripts/fetch_deps.sh 或安装系统 ffmpeg" >&2
  exit 1
fi

# ---------- 字体 ----------
font_count=0
shopt -s nullglob
for f in "$VENDOR"/fonts/*.ttf "$VENDOR"/fonts/*.otf "$VENDOR"/fonts/*.ttc; do
  cp -f "$f" "$FONT_DIR"/
  font_count=$((font_count + 1))
done
shopt -u nullglob

if [ "$font_count" -eq 0 ]; then
  if command -v fc-list >/dev/null 2>&1 && fc-list :lang=zh | grep -q .; then
    echo "字体: 系统已有中文字体"
  elif is_root; then
    echo "字体: vendor 未提供，尝试 apt 安装 Noto CJK"
    apt-get update
    apt-get install -y --no-install-recommends fonts-noto-cjk
  else
    echo "警告: 未找到中文字体，字幕可能显示为方块。运行 scripts/fetch_deps.sh 可下载字体。" >&2
  fi
else
  echo "字体: 已安装 $font_count 个到 $FONT_DIR"
fi

if command -v fc-cache >/dev/null 2>&1; then
  fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
fi

# ---------- yt-dlp（可选） ----------
if [ -x "$VENDOR/bin/yt-dlp" ]; then
  install -m 0755 "$VENDOR/bin/yt-dlp" "$BIN_DIR/yt-dlp"
  echo "yt-dlp: 使用 vendor 离线二进制"
fi

if [ -f "$ROOT/bin/video" ]; then
  chmod +x "$ROOT/bin/video"
fi

echo
echo "完成。验证："
echo "  ffmpeg -version | head -n1"
echo "  video doctor --json"
if [ "$MODE" != "--container" ] && [ "$BIN_DIR" = "${HOME}/.local/bin" ]; then
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo "提示: 把 $BIN_DIR 加入 PATH 后可直接使用 video 命令。" ;;
  esac
fi
