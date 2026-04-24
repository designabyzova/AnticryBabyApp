---
increment: 0034-soothbee-site-color-ultrathink-peach-dusk
---

# Plan

## Scope
Single file: `soothbee-site/index.html`. Additive tokens + 8 targeted CSS changes. No structural edits.

## Token Additions (:root)
- `--peach: #F5C89A` — logo NW corner peak
- `--peach-light: #FBE5D0` — logo NW corner start
- `--peach-dark: #E5A878` — stronger peach for emphasis

## Application Map
| Surface | Change | Source of truth |
|---|---|---|
| `.logo-mark` | lavender→peach→honey gradient | logo tile corners |
| `.hero-badge` outline | lavender→peach→honey gradient | mascot card frame |
| `.hero-badge img` | lavender→peach→honey gradient | mascot icon frame |
| `.hero-overlay` | +peach radial NW + lavender SE | logo corners → page corners |
| `.hero-eyebrow` color | `--primary-light` → `--peach` | logo NW directly above pill |
| `.nav-cta` | +peach-light start stop | golden-hour sweep |
| `.hero-trust-row svg` | tint shield=lavender, bolt=peach, check=honey | each icon carries a corner |
| `.scroll-hint .line` | transparent→peach→honey→lavender | mini logo-corner gradient |

## Rollback
`git revert <commit-hash>` — single-commit increment.
