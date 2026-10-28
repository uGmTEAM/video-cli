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

WORKDIR /work
ENTRYPOINT ["video"]
CMD ["doctor", "--json"]
