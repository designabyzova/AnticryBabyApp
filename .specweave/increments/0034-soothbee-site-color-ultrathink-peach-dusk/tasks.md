---
increment: 0034-soothbee-site-color-ultrathink-peach-dusk
---

# Tasks

### T-001: Add peach tokens to :root
**Satisfies ACs**: AC-US1-01 | **Status**: [x]
**Files**: soothbee-site/index.html (`:root`)
**Test Plan**: Given the stylesheet loads, When inspecting CSS custom properties, Then `--peach`, `--peach-light`, `--peach-dark` are defined with logo-derived hex values.

### T-002: Swap logo gradient to peach-corner palette
**Satisfies ACs**: AC-US1-02 | **Status**: [x]
**Files**: soothbee-site/index.html (`.logo-mark`)
**Test Plan**: Given the nav renders, When inspecting `.logo-mark`, Then gradient stops are peach-light → peach → primary-light → secondary (pink removed, peach present).

### T-003: Swap mascot badge outline to peach
**Satisfies ACs**: AC-US1-03 | **Status**: [x]
**Files**: soothbee-site/index.html (`.hero-badge`)
**Test Plan**: Given the mascot badge renders, When inspecting the outline layer of the two-layer background, Then it is peach-light → peach → primary-light → secondary.

### T-004: Swap mascot img gradient to peach
**Satisfies ACs**: AC-US1-04 | **Status**: [x]
**Files**: soothbee-site/index.html (`.hero-badge img`)
**Test Plan**: Given the badge renders, When inspecting the image frame, Then gradient is peach-light → peach → primary-light → secondary.

### T-005: Peach warm-glow in hero overlay NW corner
**Satisfies ACs**: AC-US2-01, AC-US2-02 | **Status**: [x]
**Files**: soothbee-site/index.html (`.hero-overlay`)
**Test Plan**: Given the hero renders, When sampling the overlay near 18% 22% (upper-left), Then a warm peach tint is present; AND lavender tint at 85% 82% is retained.

### T-006: Eyebrow pill text → peach
**Satisfies ACs**: AC-US2-03 | **Status**: [x]
**Files**: soothbee-site/index.html (`.hero-eyebrow`)
**Test Plan**: Given the pill renders, When inspecting computed `color`, Then it is `var(--peach)` (#F5C89A), not `--primary-light`.

### T-007: CTA golden-hour gradient
**Satisfies ACs**: AC-US3-01 | **Status**: [x]
**Files**: soothbee-site/index.html (`.nav-cta`)
**Test Plan**: Given the CTA renders, When inspecting the gradient stops, Then they are peach-light → primary-light → primary → primary-dark, AND a peach drop-shadow ring is present.

### T-008: Trust-row icon tints
**Satisfies ACs**: AC-US4-01, AC-US4-02, AC-US4-03 | **Status**: [x]
**Files**: soothbee-site/index.html (`.hero-trust-row svg`)
**Test Plan**: Given the trust row renders, When inspecting each SVG's `color`, Then span 1 = lavender, span 2 = peach, span 3 = primary-light.

### T-009: Scroll-hint line gradient
**Satisfies ACs**: AC-US5-01 | **Status**: [x]
**Files**: soothbee-site/index.html (`.scroll-hint .line`)
**Test Plan**: Given the scroll hint renders at the bottom of the hero, When inspecting the gradient, Then stops are transparent → peach → primary-light → secondary.

### T-010: Visual verification
**Satisfies ACs**: All | **Status**: [x]
**Files**: N/A
**Test Plan**: Given all changes are in place, When rendering desktop (1440x900) and mobile (390x844) screenshots, Then the logo's peach↔lavender corner palette is visibly present across logo frame, mascot badge, eyebrow pill text, CTA, trust-row icons, and scroll hint.
