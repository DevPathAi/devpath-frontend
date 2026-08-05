def lum(h):
    h = h.lstrip('#')
    c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]

def ratio(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)

L = {  # 라이트
    'bg': '#FAF9F7', 'surface': '#FFFFFF', 'surfaceMuted': '#F2F0EC',
    'textPrimary': '#1A1815', 'textSecondary': '#615C54', 'textFaint': '#918B81',
    'primary': '#B45309', 'onPrimary': '#FFFFFF',
    'primaryText': '#92400E', 'primaryTextStrong': '#78350F',
    'success': '#15803D', 'warning': '#A16207', 'danger': '#B91C1C',
    'railBg': '#1A1815', 'railText': '#F2F0EC', 'railMuted': '#A9A298', 'railFaint': '#9C958B',
    'railActive': '#2F2B24',
    'accentSoft': '#FDF1E0', 'tagBg': '#F2F0EC', 'tagText': '#524D45',
    'chart1': '#B45309', 'chart2': '#B8863A', 'chart3': '#78350F',
    'chart4': '#0F766E', 'chart5': '#8B857D',
}
D = {  # 다크
    'bg': '#0F0E0C', 'surface': '#1A1815', 'surfaceMuted': '#231F1B',
    'textPrimary': '#EAE7E2', 'textSecondary': '#A09991', 'textFaint': '#6F6961',
    'primary': '#F59E0B', 'onPrimary': '#1A1200',
    'primaryText': '#FBBF24', 'primaryTextStrong': '#FCD34D',
    'success': '#4ADE80', 'warning': '#FCD34D', 'danger': '#F87171',
    'railBg': '#131210', 'railText': '#EAE7E2', 'railMuted': '#948D85', 'railFaint': '#8A837B',
    'railActive': '#231F1B',
    'accentSoft': '#2E2007', 'tagBg': '#231F1B', 'tagText': '#A09991',
    'chart1': '#F59E0B', 'chart2': '#D9A653', 'chart3': '#FCD34D',
    'chart4': '#2DD4BF', 'chart5': '#8B857D',
}

CHECKS = [
    ('textPrimary', 'bg', 4.5), ('textPrimary', 'surface', 4.5),
    ('textSecondary', 'bg', 4.5), ('textSecondary', 'surface', 4.5),
    ('textFaint', 'bg', 3.0),
    ('primaryText', 'bg', 4.5), ('primaryText', 'surface', 4.5),
    ('primaryTextStrong', 'surface', 7.0),
    ('onPrimary', 'primary', 4.5),
    ('success', 'surface', 4.5), ('warning', 'surface', 4.5), ('danger', 'surface', 4.5),
    ('railText', 'railBg', 4.5), ('railMuted', 'railBg', 4.5), ('railFaint', 'railBg', 4.5),
    ('railText', 'railActive', 4.5), ('railMuted', 'railActive', 4.5),
    ('primaryText', 'accentSoft', 4.5), ('tagText', 'tagBg', 4.5),
    # 차트 토큰(UI 컴포넌트 기준 3:1) — 2026-08-03 재점검: chart2가 34건 대비
    # 점검에서 빠져 있었고, 라이트 1.47:1·다크 1.95:1로 미달이었다.
    ('chart1', 'surface', 3.0), ('chart2', 'surface', 3.0),
    ('chart3', 'surface', 3.0), ('chart4', 'surface', 3.0),
    ('chart5', 'surface', 3.0),
]

for name, P in (('라이트', L), ('다크', D)):
    print(f"=== {name} ===")
    bad = 0
    for fg, bgk, need in CHECKS:
        r = ratio(P[fg], P[bgk])
        ok = r >= need
        if not ok:
            bad += 1
        print(f"  {'OK ' if ok else 'FAIL'} {fg:>18} on {bgk:<13} {r:5.2f}:1  (기준 {need})")
    print(f"  → 미달 {bad}건\n")
