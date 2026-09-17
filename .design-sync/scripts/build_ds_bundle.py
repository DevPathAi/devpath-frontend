"""Off-script design-sync layout for a tokens-only DS (Leva).
Inputs: Flutter projection dump, fonts downloaded via the homepage font manifest, DESIGN.md.
Output: <frontend worktree>/ds-bundle/
"""
import io, json, os, shutil, hashlib, sys
F = r"D:/workspace/dpa/.worktrees/frontend-design-sync-20260917/"
H = r"D:/workspace/dpa/.worktrees/home-govtech-hotfix-20260917/"
OUT = F + "ds-bundle/"
if os.path.isdir(OUT):
    shutil.rmtree(OUT)
for d in ["tokens", "fonts", "guidelines"]:
    os.makedirs(OUT + d, exist_ok=True)

# tokens — Flutter projection, font family keys normalised to the CSS family names shipped in fonts/
css = io.open(F + "packages/dp_design/build/dp-tokens.css", encoding="utf-8").read()
css = css.replace('"packages/dp_design/Pretendard"', '"Pretendard"').replace('"packages/dp_design/D2Coding"', '"D2Coding"')
assert "packages/dp_design/" not in css.split("\n", 1)[1]
io.open(OUT + "tokens/leva-tokens.css", "w", encoding="utf-8", newline="\n").write(css)

# fonts — copy woff2 (hash-verified at download) and write @font-face
fonts = json.load(io.open(H + "e2e/visual/fonts/manifest.v2.json", encoding="utf-8"))["fonts"]
face = ["/* Leva brand fonts. Pretendard 1.3.9 (OFL) and D2Coding 1.3.2 (OFL), subset woff2 as served to leva.ai.kr. */"]
for f in fonts:
    src = H + "ds-bundle/fonts/" + f["file"]
    data = open(src, "rb").read()
    assert hashlib.sha256(data).hexdigest() == f["sha256"], f["file"]
    open(OUT + "fonts/" + f["file"], "wb").write(data)
    face.append(
        "@font-face {\n  font-family: \"%s\";\n  font-style: %s;\n  font-weight: %d;\n  font-display: swap;\n  src: url(\"./%s\") format(\"woff2\");\n}"
        % (f["family"], f["style"], f["weight"], f["file"])
    )
io.open(OUT + "fonts/fonts.css", "w", encoding="utf-8", newline="\n").write("\n".join(face) + "\n")

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
io.open(OUT + "tokens/leva-base.css", "w", encoding="utf-8", newline="\n").write(base)

# styles.css — the only closure rendered designs receive
io.open(OUT + "styles.css", "w", encoding="utf-8", newline="\n").write(
    "@import \"./fonts/fonts.css\";\n@import \"./tokens/leva-tokens.css\";\n@import \"./tokens/leva-base.css\";\n@import \"./_ds_bundle.css\";\n"
)

# bundle stubs — tokens-only DS: no components, empty-bodied bundle with the @ds-bundle header
header = {"namespace": "Leva", "components": [], "sourceHashes": {}, "inlinedExternals": [], "builtBy": "cc-design-sync"}
io.open(OUT + "_ds_bundle.js", "w", encoding="utf-8", newline="\n").write(
    "/* @ds-bundle: " + json.dumps(header).replace("*/", "*\\/") + " */\n(function(){ window.Leva = window.Leva || {}; })();\n"
)
io.open(OUT + "_ds_bundle.css", "w", encoding="utf-8", newline="\n").write(
    "/* @ds-css-runtime: tokens-only design system — no compiled component CSS. Tokens and fonts come from styles.css's imports. */\n"
)

# guidelines — the product design contract
shutil.copyfile(F + "DESIGN.md", OUT + "guidelines/DESIGN.md")

# local-only build metadata the validator reads (never uploaded)
meta = {"shape": "package", "pkg": "leva-design-tokens", "globalName": "Leva", "componentCount": 0,
        "tokensOnly": True, "dtsStubbed": False, "builtBy": "off-script tokens-only layout (see .design-sync/NOTES.md)"}
io.open(OUT + ".ds-build-meta.json", "w", encoding="utf-8", newline="\n").write(json.dumps(meta, indent=2) + "\n")
print("layout written:", sorted(os.listdir(OUT)))
