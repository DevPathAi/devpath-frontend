"""README for the tokens-only layout: conventions header + generated token index.

Run after build_ds_bundle.py:  py .design-sync/scripts/build_ds_readme.py
"""
import io
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
BUNDLE = REPO / "ds-bundle"
css = io.open(BUNDLE / "tokens" / "leva-tokens.css", encoding="utf-8").read()
light_block, dark_block = css.split('[data-theme="dark"], .dp-theme-dark {', 1)


def props(block):
    return dict(re.findall(r'(--dp-[a-z0-9-]+)\s*:\s*([^;]+);', block))


light, dark = props(light_block), props(dark_block)
version = light["--dp-token-manifest-version"].strip().strip('"')
header = io.open(REPO / ".design-sync" / "conventions.md", encoding="utf-8").read().rstrip() + "\n\n---\n\n"
lines = [header, "# Leva Design Tokens — generated index\n",
         f"Source: `packages/dp_design` `DpSemanticTokenManifest` (contract `leva.semantic-tokens` {version}), projected with `DpSemanticTokenManifest.cssCustomProperties(Brightness.light|dark)`. Fonts: Pretendard 1.3.9, D2Coding 1.3.2 (subset woff2). Guide: `guidelines/DESIGN.md`.\n",
         "## Files\n", "- `styles.css` — import this. It imports `fonts/fonts.css`, `tokens/leva-tokens.css`, `tokens/leva-base.css`.",
         "- `tokens/leva-tokens.css` — all `--dp-*` custom properties; light on `:root`, dark under `[data-theme=\"dark\"]` / `.dp-theme-dark`.",
         "- `tokens/leva-base.css` — body/background/font, focus ring, reduced-motion defaults.",
         "- `fonts/` — self-hosted woff2 + `@font-face`.", "- `guidelines/DESIGN.md` — the design contract.\n",
         "## Token index (light / dark)\n", "| Token | Light | Dark |", "|---|---|---|"]
for name in light:
    l = light[name].strip()
    d = dark.get(name, "").strip()
    lines.append(f"| `{name}` | `{l}` | `{d if d != l else '='}` |")
out = BUNDLE / "README.md"
io.open(out, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
print("README written", len(light), "tokens", len(io.open(out, encoding="utf-8").read()), "chars")
