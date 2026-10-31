#!/usr/bin/env bash
# 在联网的 Docker 容器里抓取 AI 扩展离线 wheel，放入 vendor/extensions/
# 之后 Docker build 完全离线，不碰网络。
#
# 用法：
#   bash scripts/fetch_ai_deps.sh              # 拉全部
#   bash scripts/fetch_ai_deps.sh whisperx     # 只拉 whisperx
#   bash scripts/fetch_ai_deps.sh --force      # 跳过已存在的
#
# 产物：vendor/extensions/<runtime_name>/ 下的所有 wheel (.whl + .tar.gz)
#       可直接 docker build，或解压到任意 machine 离线 pip install。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR="$ROOT/vendor/extensions"
FORCE="${1:-}"

declare -A RUNTIMES
RUNTIMES["whisperx"]="whisperx"
RUNTIMES["playwright"]="playwright"
RUNTIMES["ultralytics"]="ultralytics opencv-python-headless"
RUNTIMES["opencv"]="opencv-python-headless"
# torch CPU wheel — whisperx 重依赖（~700MB），单独下
RUNTIMES["torch-cpu"]="torch torchaudio --index-url https://download.pytorch.org/whl/cpu"
# chromium 浏览器（apt 装，不走 pip）

mkdir -p "$VENDOR"

dl_runtime() {
  local name="$1" packages="${RUNTIMES[$name]}"
  local dst="$VENDOR/$name"
  mkdir -p "$dst"
  # 如果目录已有 wheel 且非 force，跳过
  if [ -n "$(ls -A "$dst" 2>/dev/null)" ] && [ "$FORCE" != "--force" ]; then
    echo "  [跳过] $dst 已有 $(ls "$dst" | wc -l) 个文件"
    return
  fi
  echo "  [下载] $name -> $dst"
  # 拆 package list（index-url 单独处理）
  local cmd=(pip download --dest "$dst" --python-version 3.12 --only-binary=:all: --platform manylinux2014_x86_64)
  # 分普通包和带 index-url 的
  local normal="" index_url=""
  for p in $packages; do
    if [ "$p" = "--index-url" ]; then index_url="next"; continue; fi
    if [ "$index_url" = "next" ]; then cmd+=(--index-url "$p"); index_url=""; continue; fi
    cmd+=("$p")
  done
  "${cmd[@]}" || {
    echo "  [警告] $name 下载部分失败（可能某些包无 manylinux wheel），继续..."
  }
  # 打印大小
  local sz
  sz=$(du -sh "$dst" | cut -f1)
  echo "  [完成] $name = $sz ($(ls "$dst" | wc -l) 个文件)"
}

fetch_all() {
  echo "== 拉取 AI 扩展离线 wheels =="
  echo "目标: $VENDOR"
  echo
  for name in "${!RUNTIMES[@]}"; do
    dl_runtime "$name"
  done
  echo
  echo "== 总览 =="
  du -sh "$VENDOR" || true
  echo
  echo "下一步："
  echo "  docker build --build-arg WITH_WHISPERX=1 -t video-cli:full ."
  echo "  （Dockerfile 会自动 --no-index --find-links vendor/extensions/whisperx/）"
}

fetch_one() {
  local name="$1"
  if [ -z "${RUNTIMES[$name]:-}" ]; then
    echo "未知运行时: $name"
    echo "可选: ${!RUNTIMES[*]}"
    exit 1
  fi
  dl_runtime "$name"
}

# 入口
case "${1:-all}" in
  all|"") fetch_all ;;
  whisperx|playwright|ultralytics|opencv|torch-cpu) fetch_one "$1" ;;
  --force) fetch_all ;;
  *) echo "用法: $0 [whisperx|playwright|ultralytics|opencv|torch-cpu|--force]" ;;
esac
