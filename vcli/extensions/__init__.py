"""
vcli.extensions — hypit 风格可选扩展库。

所有扩展均为纯算法实现，不依赖 ffmpeg/AI 服务/Chromium。
按需 import，不导入则零开销。

用法示例：
    from vcli.extensions.wordtiming import words_at, phrase_ranges
    from vcli.extensions.temporal_math import resolve_overlap
"""

__all__ = ["wordtiming", "temporal_math"]
