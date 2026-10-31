"""
vcli.extensions — hypit 风格可选扩展库。

所有扩展均为纯算法实现，不依赖 ffmpeg/AI 服务/Chromium。
按需 import，不导入则零开销。

用法示例：
    from vcli.extensions.wordtiming import words_at, phrase_ranges
    from vcli.extensions.temporal_math import resolve_overlap
    from vcli.extensions.spatial_math import center_offset, make_video_filter
    from vcli.extensions.ffmpeg_filter_builder import (
        f_xfade, xfade_chain, amix_chain, ducking_chain, filter_complex,
    )
"""

__all__ = ["wordtiming", "temporal_math", "spatial_math", "ffmpeg_filter_builder"]
