---
increment: 0033-soothbee-site-hero-brand-alignment
---

# Tasks

### T-001: Dusk-lavender cool counter-tone in hero overlay
**Satisfies ACs**: AC-US1-01 | **Status**: [x]
**Files**: soothbee-site/index.html (`.hero-overlay` rule)
**Test Plan**: Given the hero renders, When inspecting the overlay gradients, Then the left/bottom shadow stops use `rgba(40,30,60,…)` dusk-lavender instead of pure warm-black `rgba(26,17,8,…)`.

### T-002: Italic accent uses deeper honey gold
**Satisfies ACs**: AC-US1-02 | **Status**: [x]
**Files**: soothbee-site/index.html (`.hero-title .line-b`)
**Test Plan**: Given the hero title renders, When inspecting "listens.", Then computed color is `#E8A838` (not `#F5D985`).

### T-003: Logo lockup scale + glow
**Satisfies ACs**: AC-US1-03 | **Status**: [x]
**Files**: soothbee-site/index.html (`.nav-logo` / logo selector)
**Test Plan**: Given the page renders, When measuring the logo mark, Then its rendered height is ~1.4× the prior value AND a soft drop-shadow glow is present.

### T-004: Hero edge vignette
**Satisfies ACs**: AC-US1-04 | **Status**: [x]
**Files**: soothbee-site/index.html (`.hero-overlay::after`)
**Test Plan**: Given the hero renders, When sampling pixels near corners vs center at same elevation, Then the corners are measurably darker.

### T-005: Gradient primary CTA with ink shadow
**Satisfies ACs**: AC-US2-01, AC-US2-02, AC-US2-03 | **Status**: [x]
**Files**: soothbee-site/index.html (`.nav-cta`, `.btn-primary`)
**Test Plan**: Given the "Get Soothbee" button renders, When inspecting it, Then the background is a linear-gradient from `--primary-light` → `--primary` → `--primary-dark`, AND box-shadow is present with ink tone, AND hover state changes gradient direction/opacity.

### T-006: Mascot badge ink lift + pastel gradient frame
**Satisfies ACs**: AC-US3-01, AC-US3-02 | **Status**: [x]
**Files**: soothbee-site/index.html (`.hero-badge`, `.hero-badge img`)
**Test Plan**: Given the "Meet Soothbee" badge renders, When inspecting it, Then background alpha is deeper (~0.72) AND a lavender→pink gradient outline surrounds it AND the icon has a pastel gradient container echoing the iOS bee frame.

### T-007: Eyebrow pill legibility
**Satisfies ACs**: AC-US4-01 | **Status**: [x]
**Files**: soothbee-site/index.html (`.hero-eyebrow`)
**Test Plan**: Given the pill renders on the warm photo, When inspecting background, Then it is `rgba(26,17,8,.55)` with a 1px `--primary-light` border — not `rgba(255,255,255,.08)`.

### T-008: Visual verification via screenshot
**Satisfies ACs**: All | **Status**: [x]
**Files**: N/A (validation)
**Test Plan**: Given all CSS changes are in place, When rendering `soothbee-site/index.html` in a local browser, Then a before/after screenshot comparison shows clearer logo + CTA hierarchy and on-brand pastel accents.

### T-009: FAQ JSON-LD schema
**Satisfies ACs**: AC-US5-01 | **Status**: [x]
**Files**: soothbee-site/index.html (head)
**Test Plan**: Given the page renders, When reading head scripts, Then a `FAQPage` JSON-LD block lists all 6 FAQ Q/A pairs matching visible DOM.

### T-010: Organization JSON-LD schema
**Satisfies ACs**: AC-US5-02 | **Status**: [x]
**Files**: soothbee-site/index.html (head)
**Test Plan**: Given the page renders, When reading head scripts, Then an `Organization` JSON-LD block links the site to App Store via `sameAs`.

### T-011: Below-fold image lazy-load + CLS-safe dimensions
**Satisfies ACs**: AC-US5-03 | **Status**: [x]
**Files**: soothbee-site/index.html (img tags)
**Test Plan**: Given the page loads, When inspecting non-hero images, Then they have explicit `width`/`height` AND footer App-Store badge has `loading="lazy"` + `decoding="async"`. Hero-fold badge has `decoding="async"` only (eager load).
