离线依赖目录。运行 `bash scripts/fetch_deps.sh` 后会生成：

- ffmpeg/ffmpeg, ffmpeg/ffprobe  （静态构建，含 libass）
- fonts/*.otf                     （Noto Sans CJK SC）
- bin/yt-dlp                      （可选）

安装时 `scripts/install.sh` 会优先使用这里的文件，缺失才回退 apt。
