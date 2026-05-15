#!/usr/bin/env python3
"""
生成供 Garmin Connect IQ 使用的 AngelCode 位图字体（.fnt + PNG）。
包含中文日期行 + 农历所需的全部字形（约 30 个字符），
在 FR255 等 MIP 设备上无需依赖固件内置字体即可正常显示中文。

用法（从项目根目录执行）:
    python tools/gen_lunar_font.py

产出:
    resources/drawables/lunar_zh.fnt
    resources/drawables/lunar_zh_0.png
"""

from PIL import Image, ImageFont, ImageDraw
import os, sys

# ─── 配置 ──────────────────────────────────────────────────────────────────────

# 日期行：  "4月14日 周三"（数字 + 月日 + 空格 + 周 + 星期字）
# 农历行：  "三月初二" / "闰六月廿一"
CHARS = " 0123456789月日周一二三四五六七八九十廿正冬腊初闰"

# 字号（像素）。FR255 屏宽 260px，FONT_XTINY 约 16–18px。
# 20px 在 FR255 上稍大但仍清晰；在 FR265/fenix7 等大屏上大小合适。
# 如需调整，修改此值后重新运行脚本即可。
FONT_SIZE = 20

# 字体文件：微软雅黑 (Win10 预装，含全部所需汉字)
FONT_PATH = "C:/Windows/Fonts/msyh.ttc"

# 字形之间的间隔像素（atlas 内每个字形四周留白）
PADDING = 1

# atlas 宽度（像素，Garmin 建议 ≤ 256）
ATLAS_MAX_W = 256

# 输出目录
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "resources", "drawables")
ATLAS_STEM = "lunar_zh"

# ─── 主逻辑 ───────────────────────────────────────────────────────────────────

def main():
    if not os.path.exists(FONT_PATH):
        sys.exit(f"[错误] 字体文件不存在: {FONT_PATH}\n请在脚本顶部修改 FONT_PATH 为本机可用的 CJK 字体路径。")

    font = ImageFont.truetype(FONT_PATH, FONT_SIZE)
    ascent, descent = font.getmetrics()
    line_height = ascent + descent
    base = ascent  # 行顶到基线的距离

    print(f"[字体] {FONT_SIZE}px  ascent={ascent}  descent={descent}  "
          f"line_height={line_height}  base={base}")

    # ── 1. 渲染每个字形并记录 metrics ─────────────────────────────────────────
    # 在宽松画布上以 anchor='lt'（左上角对齐）绘制，
    # 然后用 Image.getbbox() 找到非透明像素的紧包围盒。
    ORIGIN_X = FONT_SIZE * 2  # 绘制原点的 X 偏移（留出左侧空间）

    glyphs = {}  # char -> dict
    for ch in CHARS:
        tmp = Image.new("RGBA", (FONT_SIZE * 6, line_height + 4), (0, 0, 0, 0))
        draw = ImageDraw.Draw(tmp)
        draw.text((ORIGIN_X, 0), ch, font=font,
                  fill=(255, 255, 255, 255), anchor="lt")

        # xadvance：光标前进量
        bbox_adv = draw.textbbox((ORIGIN_X, 0), ch, font=font, anchor="lt")
        xadv = bbox_adv[2] - ORIGIN_X

        tight = tmp.getbbox()  # (x0, y0, x1, y1)，空字符（空格）返回 None

        if tight is None:
            # 空格：无可见像素，给一个合理的前进宽度
            glyphs[ch] = dict(img=None, gw=0, gh=0,
                              xoff=0, yoff=0,
                              xadv=max(xadv, FONT_SIZE // 3, 4))
            continue

        x0, y0, x1, y1 = tight
        glyph_img = tmp.crop(tight)
        gw = x1 - x0
        gh = y1 - y0
        xoff = x0 - ORIGIN_X   # 相对绘制原点的横向偏移
        yoff = y0               # 相对行顶（anchor='lt' → y=0 即行顶）的纵向偏移

        glyphs[ch] = dict(
            img=glyph_img, gw=gw, gh=gh,
            xoff=xoff, yoff=yoff,
            xadv=max(xadv, gw + max(xoff, 0)),
        )

    print(f"[字形] 共 {len(glyphs)} 个字符")

    # ── 2. 将字形排列进 atlas ──────────────────────────────────────────────────
    PAD = PADDING
    max_gh = max((g['gh'] for g in glyphs.values() if g['img'] is not None), default=line_height)
    row_h = max_gh + PAD * 2

    ax, ay = PAD, PAD
    for ch in CHARS:
        g = glyphs[ch]
        if g['img'] is None:
            g['ax'] = 0; g['ay'] = 0
            continue
        cell_w = g['gw'] + PAD * 2
        if ax + cell_w > ATLAS_MAX_W:
            ax = PAD
            ay += row_h
        g['ax'] = ax + PAD
        g['ay'] = ay + PAD
        ax += cell_w

    atlas_h_raw = ay + row_h + PAD
    atlas_h = 1
    while atlas_h < atlas_h_raw:
        atlas_h *= 2

    print(f"[atlas] {ATLAS_MAX_W}x{atlas_h}  (需要高度: {atlas_h_raw})")

    # ── 3. 绘制 atlas PNG ──────────────────────────────────────────────────────
    atlas = Image.new("RGBA", (ATLAS_MAX_W, atlas_h), (0, 0, 0, 0))
    for ch in CHARS:
        g = glyphs[ch]
        if g['img'] is None:
            continue
        atlas.paste(g['img'], (g['ax'], g['ay']))

    os.makedirs(OUT_DIR, exist_ok=True)
    png_name = f"{ATLAS_STEM}_0.png"
    png_path = os.path.join(OUT_DIR, png_name)
    atlas.save(png_path)
    print(f"[保存] {png_path}")

    # ── 4. 写 .fnt 描述文件 ────────────────────────────────────────────────────
    fnt_path = os.path.join(OUT_DIR, f"{ATLAS_STEM}.fnt")
    with open(fnt_path, "w", encoding="utf-8") as f:
        f.write(
            f'info face="MicrosoftYaHei" size={FONT_SIZE} bold=0 italic=0 '
            f'charset="unicode" unicode=1 stretchH=100 smooth=1 aa=1 '
            f'padding=0,0,0,0 spacing={PAD},{PAD}\n'
        )
        f.write(
            f'common lineHeight={line_height} base={base} '
            f'scaleW={ATLAS_MAX_W} scaleH={atlas_h} pages=1 packed=0\n'
        )
        f.write(f'page id=0 file="{png_name}"\n')
        f.write(f'chars count={len(CHARS)}\n')

        for ch in CHARS:
            g = glyphs[ch]
            cid = ord(ch)
            if g['img'] is None:
                f.write(
                    f'char id={cid} x=0 y=0 width=0 height=0 '
                    f'xoffset=0 yoffset=0 xadvance={g["xadv"]} page=0 chnl=15\n'
                )
            else:
                f.write(
                    f'char id={cid} x={g["ax"]} y={g["ay"]} '
                    f'width={g["gw"]} height={g["gh"]} '
                    f'xoffset={g["xoff"]} yoffset={g["yoff"]} '
                    f'xadvance={g["xadv"]} page=0 chnl=15\n'
                )

    print(f"[保存] {fnt_path}")
    print("完成！")


if __name__ == "__main__":
    main()
