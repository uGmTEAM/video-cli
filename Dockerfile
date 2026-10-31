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
# 可选 AI 运行时预装层 —— 默认全不装，保持镜像 ~294MB 瘦
# 用法: docker build --build-arg WITH_WHISPERX=1 -t video-cli:full .
#       docker build --build-arg WITH_CHROMIUM=1 --build-arg WITH_WHISPERX=1 -t video-cli:full .
# ═══════════════════════════════════════════════════════════════

ARG WITH_WHISPERX=0
ARG WITH_CHROMIUM=0
ARG WITH_ULTRALYTICS=0
ARG WITH_OPENCV=0

# Chromium（hypit chromium-render 底层 — 字幕 CSS 渲染）
RUN if [ "$WITH_CHROMIUM" = "1" ]; then \
      apt-get update \
      && apt-get install -y --no-install-recommends chromium fonts-noto-cjk \
      && rm -rf /var/lib/apt/lists/* \
      && pip install --quiet playwright \
      && python -m playwright install chromium \
      && echo "CHROMIUM_INSTALLED"; \
    fi

# WhisperX（hypit speech-evidence 底层 — 词级转写）
RUN if [ "$WITH_WHISPERX" = "1" ]; then \
      pip install --quiet torch torchaudio --index-url https://download.pytorch.org/whl/cpu \
      && pip install --quiet whisperx \
      && echo "WHISPERX_INSTALLED"; \
    fi

# YOLOv8 + OpenCV（hypit face 底层 — 自动主体检测裁剪）
RUN if [ "$WITH_ULTRALYTICS" = "1" ]; then \
      pip install --quiet ultralytics opencv-python-headless \
      && echo "ULTRALYTICS_INSTALLED"; \
    fi

# 单独 OpenCV
RUN if [ "$WITH_OPENCV" = "1" ] && [ "$WITH_ULTRALYTICS" != "1" ]; then \
      pip install --quiet opencv-python-headless \
      && echo "OPENCV_INSTALLED"; \
    fi

WORKDIR /work
ENTRYPOINT ["video"]
CMD ["doctor", "--json"]
