"""Deterministic Korean-web subset of the packaged fonts (N04 follow-up, 2026-09-17).

Usage:
  py tools/fonts/subset_fonts.py --source <dir>           # regenerate packages/dp_design/fonts/*
  py tools/fonts/subset_fonts.py --source <dir> --check   # verify packaged bytes == subset(source)

<dir> holds the upstream originals: Pretendard-{Regular,Medium,SemiBold,Bold}.otf
(orioncactus/pretendard v1.3.9) and D2Coding.ttf (naver/d2codingfont 1.3.2).
Requires fontTools 4.65.0 (pip install fonttools==4.65.0).

Output is byte-reproducible: timestamps and bounds are not recalculated, so
`evidence/et13/assets.lock.json` can pin the produced bytes and sha256.
Every Hangul syllable (U+AC00-D7A3) and Jamo block is kept; only scripts the
product never renders (CJK ideographs, kana, Cyrillic, Greek, PUA) are dropped.
"""

import argparse
import hashlib
import io
import sys
from pathlib import Path

from fontTools import version as fonttools_version
from fontTools.subset import Options, Subsetter, load_font, save_font

FONTS = [
    "Pretendard-Regular.otf",
    "Pretendard-Medium.otf",
    "Pretendard-SemiBold.otf",
    "Pretendard-Bold.otf",
    "D2Coding.ttf",
]
UNICODES = (
    "U+0000-00FF,U+0100-017F,U+02B0-02FF,U+0300-036F,U+1100-11FF,"
    "U+2000-206F,U+20A0-20CF,U+2100-214F,U+2190-21FF,U+2200-22FF,"
    "U+2300-23FF,U+2460-24FF,U+2500-259F,U+25A0-25FF,U+2600-26FF,"
    "U+2700-27BF,U+3000-303F,U+3130-318F,U+A960-A97F,U+AC00-D7A3,"
    "U+D7B0-D7FF,U+FE00-FE0F,U+FF00-FFEF"
)
REQUIRED_FONTTOOLS = "4.65.0"
TARGET = Path(__file__).resolve().parents[2] / "packages" / "dp_design" / "fonts"


def parse_unicodes(spec: str) -> set[int]:
    out: set[int] = set()
    for part in spec.split(","):
        a, _, b = part.removeprefix("U+").partition("-")
        lo, hi = int(a, 16), int(b or a, 16)
        out.update(range(lo, hi + 1))
    return out


def subset_bytes(source: Path) -> bytes:
    options = Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.notdef_outline = True
    options.glyph_names = True
    options.recalc_timestamp = False
    options.recalc_bounds = False
    options.drop_tables += ["FFTM"]
    font = load_font(str(source), options)
    subsetter = Subsetter(options=options)
    subsetter.populate(unicodes=parse_unicodes(UNICODES))
    subsetter.subset(font)
    buffer = io.BytesIO()
    save_font(font, buffer, options)
    return buffer.getvalue()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if fonttools_version != REQUIRED_FONTTOOLS:
        sys.exit(f"fontTools {REQUIRED_FONTTOOLS} required, found {fonttools_version}")
    drift = 0
    for name in FONTS:
        data = subset_bytes(Path(args.source) / name)
        target = TARGET / name
        if args.check:
            packaged = target.read_bytes()
            ok = packaged == data
            drift += 0 if ok else 1
            print(
                f"{'OK   ' if ok else 'DRIFT'} {target.as_posix()} "
                f"{len(packaged)} {hashlib.sha256(packaged).hexdigest()}"
            )
        else:
            target.write_bytes(data)
            print(f"{target.as_posix()} {len(data)} {hashlib.sha256(data).hexdigest()}")
    sys.exit(1 if drift else 0)


if __name__ == "__main__":
    main()
