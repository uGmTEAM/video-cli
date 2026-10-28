#!/usr/bin/env bash
# 在联网机器上抓取离线依赖，产物放入 vendor/，之后 Docker 构建无需再下大文件。
# 用法：bash scripts/fetch_deps.sh [--force]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR="$ROOT/vendor"
FORCE="${1:-}"

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) FF_ARCH="linux64"; YT_ASSET="yt-dlp_linux" ;;
  aarch64|arm64) FF_ARCH="linuxarm64"; YT_ASSET="yt-dlp_linux_aarch64" ;;
  *) echo "不支持的架构: $ARCH" >&2; exit 1 ;;
esac

FFMPEG_URL="${FFMPEG_URL:-https://github.com/BtbN/FFmpeg-Builds/releases/latest/download/ffmpeg-master-latest-${FF_ARCH}-gpl.tar.xz}"
YTDLP_URL="${YTDLP_URL:-https://github.com/yt-dlp/yt-dlp/releases/latest/download/${YT_ASSET}}"
FONT_BASE="${FONT_BASE:-https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/OTF/SimplifiedChinese}"

mkdir -p "$VENDOR/ffmpeg" "$VENDOR/fonts" "$VENDOR/bin"

dl() {
  local url="$1" dst="$2"
  if [ -s "$dst" ] && [ "$FORCE" != "--force" ]; then
    echo "已存在，跳过: $dst"
    return
  fi
  echo "下载: $url"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 --connect-timeout 20 -o "$dst.part" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$dst.part" "$url"
  else
    echo "错误: 需要 curl 或 wget" >&2
    exit 1
  fi
  mv "$dst.part" "$dst"
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "== 1/3 ffmpeg =="
dl "$FFMPEG_URL" "$TMP/ffmpeg.tar.xz"
tar -xJf "$TMP/ffmpeg.tar.xz" -C "$TMP"
SRC="$(find "$TMP" -maxdepth 4 -type f -name ffmpeg | head -n1)"
if [ -z "$SRC" ]; then
  echo "错误: 压缩包内找不到 ffmpeg" >&2
  exit 1
fi
cp -f "$SRC" "$VENDOR/ffmpeg/ffmpeg"
cp -f "$(dirname "$SRC")/ffprobe" "$VENDOR/ffmpeg/ffprobe"
chmod 0755 "$VENDOR/ffmpeg/"*
echo "ffmpeg -> $("$VENDOR/ffmpeg/ffmpeg" -version | head -n1)"

echo "== 2/3 字体 =="
for name in NotoSansCJKsc-Regular.otf NotoSansCJKsc-Bold.otf; do
  dl "$FONT_BASE/$name" "$VENDOR/fonts/$name"
done

echo "== 3/3 yt-dlp（可选） =="
dl "$YTDLP_URL" "$VENDOR/bin/yt-dlp"
chmod 0755 "$VENDOR/bin/yt-dlp"

echo
echo "依赖已放入 $VENDOR："
du -sh "$VENDOR"/* 2>/dev/null || true
echo "下一步：bash scripts/install.sh 或 docker build -t video-cli ."
