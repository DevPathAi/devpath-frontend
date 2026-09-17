"""Off-script design-sync layout for a tokens-only DS (Leva).

Run from anywhere (paths are derived from this file's location):
    py .design-sync/scripts/build_ds_bundle.py [--dump packages/dp_design/build/dp-tokens.css]

Inputs:  the Flutter projection dump written by
         packages/dp_design/test/theme/dp_semantic_tokens_dump_test.dart (DP_TOKEN_DUMP=<path>),
         .design-sync/fonts.json (woff2 URLs + sha256; downloaded into .design-sync/.cache/fonts/),
         DESIGN.md (product design contract).
Output:  <repo root>/ds-bundle/ (gitignored)
"""
import argparse
import hashlib
import io
import json
import os
import shutil
import sys
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DS = REPO / ".design-sync"
OUT = REPO / "ds-bundle"
CACHE = DS / ".cache" / "fonts"

parser = argparse.ArgumentParser()
parser.add_argument("--dump", default=str(REPO / "packages" / "dp_design" / "build" / "dp-tokens.css"))
args = parser.parse_args()
dump = Path(args.dump)
if not dump.is_file():
    sys.exit(
        f"token dump not found: {dump}\n"
        "run first: DP_TOKEN_DUMP=<that path> flutter test packages/dp_design/test/theme/dp_semantic_tokens_dump_test.dart"
    )


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    io.open(path, "w", encoding="utf-8", newline="\n").write(text)


def fetch_font(font: dict) -> bytes:
    """Return the woff2 bytes, from the cache when its sha256 matches, else downloaded and verified."""
    cached = CACHE / font["file"]
    if cached.is_file():
        data = cached.read_bytes()
        if hashlib.sha256(data).hexdigest() == font["sha256"]:
            return data
    with urllib.request.urlopen(font["url"], timeout=60) as resp:  # noqa: S310 - pinned https URL from fonts.json
        data = resp.read()
    digest = hashlib.sha256(data).hexdigest()
    if digest != font["sha256"]:
        sys.exit(f"sha256 mismatch for {font['file']}: expected {font['sha256']}, got {digest}")
    CACHE.mkdir(parents=True, exist_ok=True)
    cached.write_bytes(data)
    return data


if OUT.is_dir():
    shutil.rmtree(OUT)
for d in ["tokens", "fonts", "guidelines", "components"]:
    (OUT / d).mkdir(parents=True, exist_ok=True)

# tokens — Flutter projection, font family keys normalised to the CSS family names shipped in fonts/
css = io.open(dump, encoding="utf-8").read()
css = css.replace('"packages/dp_design/Pretendard"', '"Pretendard"').replace('"packages/dp_design/D2Coding"', '"D2Coding"')
assert "packages/dp_design/" not in css.split("\n", 1)[1], "unnormalised package-qualified family left in dump"
write_text(OUT / "tokens" / "leva-tokens.css", css)

# fonts — woff2 verified against fonts.json, plus @font-face
fonts = json.load(io.open(DS / "fonts.json", encoding="utf-8"))["fonts"]
face = ["/* Leva brand fonts. Pretendard 1.3.9 (OFL) and D2Coding 1.3.2 (OFL), subset woff2 as served to leva.ai.kr. */"]
for f in fonts:
    (OUT / "fonts" / f["file"]).write_bytes(fetch_font(f))
    face.append(
        "@font-face {\n  font-family: \"%s\";\n  font-style: %s;\n  font-weight: %d;\n  font-display: swap;\n  src: url(\"./%s\") format(\"woff2\");\n}"
        % (f["family"], f["style"], f["weight"], f["file"])
    )
write_text(OUT / "fonts" / "fonts.css", "\n".join(face) + "\n")

# base — apply the tokens to the document so any design starts on-brand
base = """/* Leva base: applies the semantic tokens to the document. Everything else is up to the design. */
html { color-scheme: light; }
body {
  margin: 0;
  background: var(--dp-color-bg);
  color: var(--dp-color-text-primary);
  font: var(--dp-type-body-large);
  font-family: "Pretendard", system-ui, sans-serif;
  word-break: keep-all;
}
code, pre, kbd, samp { font: var(--dp-type-code); font-family: "D2Coding", ui-monospace, monospace; }
:focus-visible { outline: var(--dp-state-focus-ring-width) solid var(--dp-state-focus-ring); outline-offset: 2px; }
@media (prefers-reduced-motion: reduce) { *, *::before, *::after { animation-duration: 0.001ms !important; transition-duration: 0.001ms !important; } }
"""
write_text(OUT / "tokens" / "leva-base.css", base)

# styles.css — the only closure rendered designs receive
write_text(
    OUT / "styles.css",
    "@import \"./fonts/fonts.css\";\n@import \"./tokens/leva-tokens.css\";\n@import \"./tokens/leva-base.css\";\n@import \"./_ds_bundle.css\";\n",
)

# bundle stubs — tokens-only DS: no components, empty-bodied bundle with the @ds-bundle header
header = {"namespace": "Leva", "components": [], "sourceHashes": {}, "inlinedExternals": [], "builtBy": "cc-design-sync"}
write_text(
    OUT / "_ds_bundle.js",
    "/* @ds-bundle: " + json.dumps(header).replace("*/", "*\\/") + " */\n(function(){ window.Leva = window.Leva || {}; })();\n",
)
write_text(
    OUT / "_ds_bundle.css",
    "/* @ds-css-runtime: tokens-only design system — no compiled component CSS. Tokens and fonts come from styles.css's imports. */\n",
)

# guidelines — the product design contract
shutil.copyfile(REPO / "DESIGN.md", OUT / "guidelines" / "DESIGN.md")

# local-only build metadata the validator reads (never uploaded)
meta = {"shape": "package", "pkg": "leva-design-tokens", "globalName": "Leva", "componentCount": 0,
        "tokensOnly": True, "dtsStubbed": False, "builtBy": "off-script tokens-only layout (see .design-sync/NOTES.md)"}
write_text(OUT / ".ds-build-meta.json", json.dumps(meta, indent=2) + "\n")
print("layout written:", sorted(os.listdir(OUT)))
