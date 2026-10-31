FROM python:3.12-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    LANG=C.UTF-8

# 国内网络可传 --build-arg APT_MIRROR=mirrors.aliyun.com 加速
ARG APT_MIRROR=deb.debian.org

# fontconfig 用于 libass 查找字体；其余依赖优先使用 vendor/ 内的离线包
RUN if [ "$APT_MIRROR" != "deb.debian.org" ]; then \
      sed -i "s|deb.debian.org|$APT_MIRROR|g" /etc/apt/sources.list.d/debian.sources 2>/dev/null || true; \
      sed -i "s|deb.debian.org|$APT_MIRROR|g" /etc/apt/sources.list 2>/dev/null || true; \
    fi \
    && apt-get update \
    && apt-get install -y --no-install-recommends fontconfig ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/video-cli
COPY vendor/ ./vendor/
COPY scripts/ ./scripts/
RUN bash scripts/install.sh --container

COPY vcli/ ./vcli/
COPY bin/ ./bin/
COPY schema/ ./schema/
COPY examples/ ./examples/
COPY README.md ./

RUN chmod +x ./bin/video && ln -sf /opt/video-cli/bin/video /usr/local/bin/video

# ═══════════════════════════════════════════════════════════════
# 可选 AI 运行时预装层 —— 默认全不装，保持镜像 ~309MB 瘦
#
# 两层安装策略：
#   1. vendor/extensions/<name>/ 有 wheel → --no-index --find-links 完全离线
#   2. 没有 vendor wheel → 在线 pip install（联网 build）
#
# 联网机器先拉离线包：
#   bash scripts/fetch_ai_deps.sh            # 拉全部
#   bash scripts/fetch_ai_deps.sh whisperx   # 只拉 whisperx
#
# 然后 build 时自动离线：
#   docker build --build-arg WITH_WHISPERX=1 -t video-cli:full .
#
# 也可以在线 build（不先拉 wheel）：
#   docker build --build-arg WITH_WHISPERX=1 --build-arg ALLOW_ONLINE_PIP=1 ...
# ═══════════════════════════════════════════════════════════════

ARG WITH_WHISPERX=0
ARG WITH_CHROMIUM=0
ARG WITH_ULTRALYTICS=0
ARG WITH_OPENCV=0
ARG ALLOW_ONLINE_PIP=0

# 辅助：离线优先的 pip install
# 用法: RUN $OPT_PIP_INSTALL "playwright" "vendor/extensions/playwright"
ENV OPT_PIP_INSTALL="bash -c 'vend=$2; shift 2; if [ -d \"$vend\" ] && ls \"$vend\"/*.whl >/dev/null 2>&1; then echo \"[vendor] 离线装 $*\"; pip install --quiet --no-input --no-index --find-links \"$vend\" \"$@\"; else echo \"[online] 在线装 $*\"; pip install --quiet --no-input \"$@\"; fi'"

# Chromium（hypit chromium-render — 字幕 CSS 渲染）
RUN if [ "$WITH_CHROMIUM" = "1" ]; then \
      apt-get update \
      && apt-get install -y --no-install-recommends chromium fonts-noto-cjk \
      && rm -rf /var/lib/apt/lists/* \
      && pip install --quiet playwright \
      && python -m playwright install chromium \
      && echo "CHROMIUM_INSTALLED"; \
    fi

# WhisperX（hypit speech-evidence — 词级转写）
# 依赖 torch CPU wheel（单独目录 vendor/extensions/torch-cpu/）
RUN if [ "$WITH_WHISPERX" = "1" ]; then \
      if [ -d "vendor/extensions/torch-cpu" ] && ls vendor/extensions/torch-cpu/*.whl >/dev/null 2>&1; then \
        echo "[vendor] 离线装 torch" \
        && pip install --quiet --no-input --no-index --find-links vendor/extensions/torch-cpu torch torchaudio; \
      elif [ "$ALLOW_ONLINE_PIP" = "1" ]; then \
        echo "[online] 在线装 torch" \
        && pip install --quiet torch torchaudio --index-url https://download.pytorch.org/whl/cpu; \
      else \
        echo "错误: 找不到 vendor/extensions/torch-cpu/ 离线 wheel，且 ALLOW_ONLINE_PIP=0" >&2; exit 1; \
      fi \
      && if [ -d "vendor/extensions/whisperx" ] && ls vendor/extensions/whisperx/*.whl >/dev/null 2>&1; then \
        echo "[vendor] 离线装 whisperx" \
        && pip install --quiet --no-input --no-index --find-links vendor/extensions/whisperx whisperx; \
      elif [ "$ALLOW_ONLINE_PIP" = "1" ]; then \
        echo "[online] 在线装 whisperx" \
        && pip install --quiet whisperx; \
      else \
        echo "错误: 找不到 vendor/extensions/whisperx/ 离线 wheel，且 ALLOW_ONLINE_PIP=0" >&2; exit 1; \
      fi \
      && echo "WHISPERX_INSTALLED"; \
    fi

# YOLOv8 + OpenCV（hypit face — 自动主体检测裁剪）
RUN if [ "$WITH_ULTRALYTICS" = "1" ]; then \
      if [ -d "vendor/extensions/ultralytics" ] && ls vendor/extensions/ultralytics/*.whl >/dev/null 2>&1; then \
        echo "[vendor] 离线装 ultralytics" \
        && pip install --quiet --no-input --no-index --find-links vendor/extensions/ultralytics ultralytics opencv-python-headless; \
      elif [ "$ALLOW_ONLINE_PIP" = "1" ]; then \
        echo "[online] 在线装 ultralytics" \
        && pip install --quiet ultralytics opencv-python-headless; \
      else \
        echo "错误: 找不到 vendor/extensions/ultralytics/ 离线 wheel，且 ALLOW_ONLINE_PIP=0" >&2; exit 1; \
      fi \
      && echo "ULTRALYTICS_INSTALLED"; \
    fi

# 单独 OpenCV
RUN if [ "$WITH_OPENCV" = "1" ] && [ "$WITH_ULTRALYTICS" != "1" ]; then \
      if [ -d "vendor/extensions/opencv" ] && ls vendor/extensions/opencv/*.whl >/dev/null 2>&1; then \
        echo "[vendor] 离线装 opencv" \
        && pip install --quiet --no-input --no-index --find-links vendor/extensions/opencv opencv-python-headless; \
      elif [ "$ALLOW_ONLINE_PIP" = "1" ]; then \
        echo "[online] 在线装 opencv" \
        && pip install --quiet opencv-python-headless; \
      else \
        echo "错误: 找不到 vendor/extensions/opencv/ 离线 wheel，且 ALLOW_ONLINE_PIP=0" >&2; exit 1; \
      fi \
      && echo "OPENCV_INSTALLED"; \
    fi

WORKDIR /work
ENTRYPOINT ["video"]
CMD ["doctor", "--json"]
