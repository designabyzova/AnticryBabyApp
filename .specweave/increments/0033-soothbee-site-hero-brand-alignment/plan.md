---
increment: 0033-soothbee-site-hero-brand-alignment
---

# Plan

## Scope

Single file: `soothbee-site/index.html`. All changes are in the inline `<style>` block. No new assets, no new files, no build-system changes.

## Design Principles

1. **Keep brand tokens as-is.** The `:root` palette is good — the problem is how tokens are *applied* in the hero, not the tokens themselves.
2. **Counter-tone for contrast.** Warm-sepia photo + warm-gold accents = hue collision. A dusk-lavender shadow tone (already a brand secondary `#9B8DC7`) gives gold something to contrast against without adding new brand colors.
3. **Echo the iOS-app visual language.** The app uses pastel-framed icons (lavender→pink gradient frames), gradient action buttons, and light cream backgrounds. Port the *treatments* to the site's hero — framed logo, gradient CTA, pastel outline on the mascot card.
4. **Never sacrifice accessibility.** WCAG AA contrast must hold for all copy over the new overlay.

## Token Usage Map

| Existing token | Hero application |
|---|---|
| `--primary #E8A838` | Italic accent word "listens.", CTA gradient mid-stop |
| `--primary-dark #B8791E` | CTA gradient end-stop, CTA border |
| `--primary-light #F5D985` | CTA gradient start-stop, pill border, logo glow |
| `--secondary #9B8DC7` | Hero overlay cool counter-tone, mascot badge outline start |
| `--tertiary #F4B8C5` | Mascot badge outline end, logo frame gradient end |
| `--ink #1A140B` | CTA text, CTA shadow base |

## Key CSS Changes

1. **`.hero-overlay`** — replace pure warm-black with warm-black + dusk-lavender in the left/bottom gradient bands.
2. **`.hero-overlay::after`** — new rule, radial vignette to darken edges.
3. **`.hero-title .line-b`** — color change from `--primary-light` to `--primary`.
4. **`.hero-eyebrow`** — background + border change.
5. **`.nav-logo`** — size bump + drop-shadow glow.
6. **`.nav-cta`, `.btn-primary`** — convert to gradient, add ink shadow, add hover variant.
7. **`.hero-badge`** — deeper alpha, pastel gradient outline.
8. **`.hero-badge img`** — pastel gradient container.

## Verification

- Local render of `soothbee-site/index.html` in Chrome.
- Before/after screenshot comparison.
- Spot-check: logo visible, CTA pops, eyebrow legible, mascot feels native.

## Rollback

Single file edit — `git checkout -- soothbee-site/index.html` reverts.
