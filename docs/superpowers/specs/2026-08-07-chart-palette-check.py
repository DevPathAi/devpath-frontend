"""차트 팔레트 합격 판정(스펙 3-B §3.2). 위반 0건이면 exit 0.

기준:
  1) 배경 대비 >= 3:1 (bg·surface 각각)
  2) 색각 이상(deuteranopia) 시뮬 후 계열 간 dE76 >= 20
  3) 계열 간 hue차 >= 40도
  4) primary와의 dE76 >= 25
  5) 계열 간 명도 대비 — 기록만(합격 판정에 쓰지 않는다)
  6) success·warning·danger·chart4·chart5와의 dE76 >= 25
"""
import colorsys
import math
import sys

# dp_colors.dart와 손으로 맞춘 값. 토큰을 바꾸면 여기도 바꾼다.
PALETTE = {
    'light': {
        'bg': '#FAF9F7', 'surface': '#FFFFFF', 'primary': '#B45309',
        'success': '#15803D', 'warning': '#A16207', 'danger': '#B91C1C',
        'chart1': '#1D4ED8', 'chart2': '#BE185D', 'chart3': '#7E22CE',
        'chart4': '#0F766E', 'chart5': '#8B857D',
    },
    'dark': {
        'bg': '#0F0E0C', 'surface': '#1A1815', 'primary': '#F59E0B',
        'success': '#4ADE80', 'warning': '#FCD34D', 'danger': '#F87171',
        'chart1': '#60A5FA', 'chart2': '#F472B6', 'chart3': '#D8B4FE',
        'chart4': '#2DD4BF', 'chart5': '#8B857D',
    },
}
SERIES = ['chart1', 'chart2', 'chart3']
# chart5(#8B857D, 라이트·다크 동일)는 스펙 초안이 빠뜨린 실재 토큰이다.
# 지금은 어느 화면에도 배선돼 있지 않지만, 배선되는 순간 기준6의 대상이 된다.
RESERVED = ['success', 'warning', 'danger', 'chart4', 'chart5']


def rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def lum(h):
    def ch(c):
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(x) for x in rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = lum(a), lum(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def to_lab(h):
    r, g, b = rgb(h)

    def inv(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = inv(r), inv(g), inv(b)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(t):
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    fx, fy, fz = f(x), f(y), f(z)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


def de76(a, b):
    la, aa, ba = to_lab(a)
    lb, ab, bb = to_lab(b)
    return math.sqrt((la - lb) ** 2 + (aa - ab) ** 2 + (ba - bb) ** 2)


def hue_diff(a, b):
    ha = colorsys.rgb_to_hsv(*rgb(a))[0] * 360
    hb = colorsys.rgb_to_hsv(*rgb(b))[0] * 360
    d = abs(ha - hb)
    return min(d, 360 - d)


def deuteranopia(h):
    """적록 색각 이상 근사. 계열이 시뮬 후에도 갈리는지 보기 위한 것."""
    r, g, b = rgb(h)
    m = (0.625 * r + 0.375 * g, 0.70 * r + 0.30 * g, 0.30 * g + 0.70 * b)
    return '#%02X%02X%02X' % tuple(round(max(0, min(1, c)) * 255) for c in m)


violations = []
for theme, p in PALETTE.items():
    for k in SERIES + ['chart4']:
        for bgk in ('bg', 'surface'):
            cr = contrast(p[k], p[bgk])
            print(f'[{theme}] {k} on {bgk}: {cr:.2f}:1')
            if cr < 3.0:
                violations.append(f'[{theme}] 기준1 {k} on {bgk} = {cr:.2f}:1 (< 3:1)')
    for i in range(len(SERIES)):
        for j in range(i + 1, len(SERIES)):
            a, b = SERIES[i], SERIES[j]
            d = de76(deuteranopia(p[a]), deuteranopia(p[b]))
            hd = hue_diff(p[a], p[b])
            cr = contrast(p[a], p[b])
            print(f'[{theme}] {a}-{b}: 시뮬dE={d:.1f} hue={hd:.1f}도 명도={cr:.2f}:1(기록)')
            if d < 20:
                violations.append(f'[{theme}] 기준2 {a}-{b} 시뮬dE={d:.1f} (< 20)')
            if hd < 40:
                violations.append(f'[{theme}] 기준3 {a}-{b} hue={hd:.1f}도 (< 40)')
    for k in SERIES:
        d = de76(p[k], p['primary'])
        if d < 25:
            violations.append(f'[{theme}] 기준4 {k} vs primary dE={d:.1f} (< 25)')
        for rk in RESERVED:
            dr = de76(p[k], p[rk])
            if dr < 25:
                violations.append(f'[{theme}] 기준6 {k} vs {rk} dE={dr:.1f} (< 25)')

print()
if violations:
    print(f'위반 {len(violations)}건:')
    for v in violations:
        print(f'  - {v}')
    sys.exit(1)
print('위반 0건 — 팔레트 합격')
