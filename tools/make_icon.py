"""生成计件本的启动图标（不用 flutter_launcher_icons，避免多一个构建依赖）。

设计：深青绿圆角方块 + 白色计数符号「四竖一斜」。
    竖线 = 一件一件数下去，斜线 = 第五件打结（车间里划正字的习惯）。
    不用中文字形，是因为 48px 下汉字会糊成一团；纯几何笔画在最小尺寸也清楚。

输出：
    android/app/src/main/res/mipmap-*/ic_launcher.png          传统图标
    android/app/src/main/res/mipmap-*/ic_launcher_foreground.png 自适应图标前景（66% 安全区）
    android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml   自适应图标（Android 8+）
    android/app/src/main/res/values/colors.xml                  自适应图标背景色
    图标-512.png                                                 商店/文档用

用法：python tools/make_icon.py
"""

from __future__ import annotations

import os
from PIL import Image, ImageDraw

# 经典皮肤主色（v1.0 的 #0E7A63 及其深浅两档）
TEAL_TOP = (20, 138, 112)
TEAL_BOT = (8, 78, 62)
BG_FLAT = (14, 122, 99)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

# 传统图标尺寸（mdpi 为基准 48dp）
LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
# 自适应图标前景：108dp 画布，其中中间 72dp 是安全区
FORE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def vertical_gradient(size: int) -> Image.Image:
    g = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / max(size - 1, 1)
        g.putpixel(
            (0, y),
            (
                round(TEAL_TOP[0] + (TEAL_BOT[0] - TEAL_TOP[0]) * t),
                round(TEAL_TOP[1] + (TEAL_BOT[1] - TEAL_TOP[1]) * t),
                round(TEAL_TOP[2] + (TEAL_BOT[2] - TEAL_TOP[2]) * t),
            ),
        )
    return g.resize((size, size))


def rounded_mask(size: int, radius_ratio: float = 0.22) -> Image.Image:
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=size * radius_ratio, fill=255)
    return m


def draw_tally(img: Image.Image, box: float, color=(255, 255, 255, 255)) -> None:
    """在 img 的正中间画「四竖一斜」，box = 整体占画布的比例。"""
    size = img.size[0]
    span = size * box
    cx = cy = size / 2

    bar_w = span * 0.115          # 竖线粗细
    bar_h = span * 0.86           # 竖线高度
    gap = span * 0.245            # 竖线间距（四根）
    left = cx - gap * 1.5 - bar_w / 2

    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(4):
        x = left + i * gap
        d.rounded_rectangle(
            [x, cy - bar_h / 2, x + bar_w, cy + bar_h / 2],
            radius=bar_w / 2,
            fill=color,
        )

    # 斜线：从左下穿到右上，比竖线长一点，两端超出最外两根竖线
    slash = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(slash)
    x0 = left - span * 0.055
    x1 = left + gap * 3 + bar_w + span * 0.055
    y0 = cy + bar_h * 0.30
    y1 = cy - bar_h * 0.30
    sd.line([(x0, y0), (x1, y1)], fill=color, width=round(bar_w))
    # 给斜线两端补圆头
    for (px, py) in ((x0, y0), (x1, y1)):
        sd.ellipse([px - bar_w / 2, py - bar_w / 2, px + bar_w / 2, py + bar_w / 2], fill=color)

    layer = Image.alpha_composite(layer, slash)
    img.alpha_composite(layer)


def make_legacy(size: int, path: str) -> None:
    base = vertical_gradient(size).convert("RGBA")
    base.putalpha(rounded_mask(size))
    # 顶部一层极淡的高光：必须是平滑渐变，用椭圆会留下一道看得见的接缝
    hi = Image.new("RGBA", (1, size))
    for y in range(size):
        t = y / max(size - 1, 1)
        a = round(34 * max(0.0, 1 - t / 0.55))
        hi.putpixel((0, y), (255, 255, 255, a))
    base.alpha_composite(hi.resize((size, size)))
    draw_tally(base, box=0.56)
    base.save(path)


def make_foreground(size: int, path: str) -> None:
    """前景层只画笔画：安全区是中间 72/108 ≈ 66.7%，所以 box 要小于这个比例。"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_tally(img, box=0.40)
    img.save(path)


def main() -> None:
    for dens, size in LEGACY.items():
        d = os.path.join(RES, f"mipmap-{dens}")
        os.makedirs(d, exist_ok=True)
        make_legacy(size, os.path.join(d, "ic_launcher.png"))
        make_foreground(FORE[dens], os.path.join(d, "ic_launcher_foreground.png"))

    anydpi = os.path.join(RES, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    adaptive = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        with open(os.path.join(anydpi, name), "w", encoding="utf-8") as f:
            f.write(adaptive)

    values = os.path.join(RES, "values")
    os.makedirs(values, exist_ok=True)
    colors_path = os.path.join(values, "colors.xml")
    with open(colors_path, "w", encoding="utf-8") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
            f'    <color name="ic_launcher_background">#{BG_FLAT[0]:02X}{BG_FLAT[1]:02X}{BG_FLAT[2]:02X}</color>\n'
            "</resources>\n"
        )

    make_legacy(512, os.path.join(ROOT, "图标-512.png"))
    print("done")


if __name__ == "__main__":
    main()
