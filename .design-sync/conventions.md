# Leva design tokens — how to build with them

This design system ships **tokens, fonts and the design contract only** — no compiled React components (the product UI is Flutter; `window.Leva` is an empty namespace). Build every control yourself with plain React + CSS, and take every colour, size, radius, duration and type style from the tokens below. Never hard-code a hex, px or font-family that a token already provides.

## Setup

- Import `styles.css` once at the document root. It pulls in `fonts/fonts.css` (Pretendard 400/500/600/700, D2Coding 400 — self-hosted woff2), `tokens/leva-tokens.css` (the `--dp-*` custom properties, light on `:root`, dark under `[data-theme="dark"]` or `.dp-theme-dark`) and `tokens/leva-base.css` (body colour/background/font, focus ring, reduced motion).
- Dark theme: put `data-theme="dark"` on `<html>` or `<body>`. Do not invent dark colours — every token has a dark value.
- Korean copy: keep `word-break: keep-all` (base sets it on `body`); do not override with `break-all`.

## The idiom: `var(--dp-*)` everywhere

| Family | Tokens (real names from `tokens/leva-tokens.css`) | Use |
|---|---|---|
| Colour | `--dp-color-primary` (fill only) · `--dp-color-primary-text` (text/links/focus on light) · `--dp-color-primary-text-strong` · `--dp-color-on-primary` · `--dp-color-accent-soft` · `--dp-color-accent-line` · `--dp-color-bg` · `--dp-color-surface` · `--dp-color-surface-muted` · `--dp-color-border` · `--dp-color-text-primary` · `--dp-color-text-secondary` · `--dp-color-text-faint` · `--dp-color-success` · `--dp-color-warning` · `--dp-color-danger` · `--dp-color-tag-bg` · `--dp-color-tag-text` · `--dp-color-chart1`…`--dp-color-chart5` · `--dp-color-code-editor-bg` · `--dp-color-code-log-bg` · `--dp-color-code-text` · rail: `--dp-color-rail-bg` · `--dp-color-rail-text` · `--dp-color-rail-muted` · `--dp-color-rail-faint` · `--dp-color-rail-active` · `--dp-color-rail-border` | Primary is a **fill** colour: use it for buttons/progress, never for body text. Text on primary is `--dp-color-on-primary`. Links and focus use `--dp-color-primary-text`. |
| Interaction state | `--dp-state-{default,hover,pressed,focus,selected,disabled,error}-{background,foreground,border}` · `--dp-state-focus-ring` · `--dp-state-focus-ring-width` · `--dp-state-disabled-opacity` | Style hover/pressed/selected/disabled/error from these triples, not from ad-hoc opacity or lightness tweaks. |
| Spacing | `--dp-space-xs` 4 · `--dp-space-sm` 8 · `--dp-space-md` 12 · `--dp-space-lg` 16 · `--dp-space-xl` 24 · `--dp-space-xxl` 32 · `--dp-space-xxxl` 48 | Padding, gap, margin. |
| Radius | `--dp-radius-chip` · `--dp-radius-button` · `--dp-radius-input` · `--dp-radius-panel` · `--dp-radius-dialog` | Per element kind — a card is a panel, a text field an input. |
| Type | `--dp-type-display-small` · `--dp-type-headline-small` · `--dp-type-title-large` · `--dp-type-title-medium` · `--dp-type-title-small` · `--dp-type-body-large` · `--dp-type-body-medium` · `--dp-type-body-small` · `--dp-type-label-large` · `--dp-type-label-medium` · `--dp-type-label-small` · `--dp-type-code` | Each is a full `font` shorthand (`weight size/line-height family`): write `font: var(--dp-type-title-medium);`. Body text is body-large (16/25.6); UI hints body-medium; buttons label-large; code uses `--dp-type-code` (D2Coding). |
| Motion | `--dp-duration-hover` 120ms · `--dp-duration-select` 180ms · `--dp-duration-stage-reveal` 200ms · `--dp-duration-panel-expand` 220ms · `--dp-duration-skeleton-crossfade` 150ms | Transitions only; base disables them under reduced motion. |
| Layout | `--dp-layout-content-max` 1440px · `--dp-layout-readable-max` 880px · `--dp-layout-rail` 256px · `--dp-layout-rail-collapsed` 72px · breakpoints `--dp-breakpoint-medium` 600px · `--dp-breakpoint-expanded` 840px · `--dp-breakpoint-large` 1240px | Compact < 600, Medium 600–839, Expanded 840–1239, Large ≥ 1240 (Material 3 window classes). Rail navigation from Expanded up; bottom bar below. |

Accessibility floor (from `guidelines/DESIGN.md` §6): 44×44px hit targets, visible focus ring (`--dp-state-focus-ring`), text contrast ≥ 4.5:1 using the token pairs above, 200% text without horizontal overflow, reduced motion honoured.

## Where the truth lives

Read before styling: `styles.css` → `tokens/leva-tokens.css` (every token and its light/dark value), `tokens/leva-base.css`, `fonts/fonts.css`. The design contract (colour meaning, type scale, spacing, responsive classes, accessibility baseline, shell structure) is `guidelines/DESIGN.md`. Tokens are generated from the Flutter `DpSemanticTokenManifest` (contract `leva.semantic-tokens`; the version is `--dp-token-manifest-version`); do not edit them here.

## One idiomatic snippet

```jsx
export function MissionCard({ title, why, progress, onOpen }) {
  return (
    <section style={{
      background: 'var(--dp-color-surface)', border: '1px solid var(--dp-color-border)',
      borderRadius: 'var(--dp-radius-panel)', padding: 'var(--dp-space-lg)',
      display: 'grid', gap: 'var(--dp-space-md)', maxWidth: 'var(--dp-layout-readable-max)',
    }}>
      <h2 style={{ margin: 0, font: 'var(--dp-type-title-medium)', color: 'var(--dp-color-text-primary)' }}>{title}</h2>
      <p style={{ margin: 0, font: 'var(--dp-type-body-medium)', color: 'var(--dp-color-text-secondary)' }}>{why}</p>
      <progress value={progress} max={100} style={{ accentColor: 'var(--dp-color-primary)', width: '100%' }} />
      <button onClick={onOpen} style={{
        minHeight: 44, padding: '0 var(--dp-space-xl)', border: 0, borderRadius: 'var(--dp-radius-button)',
        background: 'var(--dp-color-primary)', color: 'var(--dp-color-on-primary)', font: 'var(--dp-type-label-large)',
        transition: `background var(--dp-duration-hover)`,
      }}>미션 열기</button>
    </section>
  );
}
```
