---
increment: 0033-soothbee-site-hero-brand-alignment
title: Soothbee site hero color harmony & iOS-app brand alignment
type: feature
priority: P1
status: completed
created: 2026-04-21T00:00:00.000Z
structure: user-stories
test_mode: test-after
coverage_target: 70
---

# Soothbee site hero color harmony & iOS-app brand alignment

## Problem

The soothbee.com hero uses a warm-sepia baby-in-car photograph combined with honey-gold brand accents (`#E8A838`, `#F5D985`). The photo's dominant hue collides with the logo's hue family, so brand accents get "absorbed" rather than "branded." Meanwhile, the iOS app uses a brighter, airier multi-pastel palette (cream + lavender + pink + peach + honey) that feels friendlier. The website and app feel like different products.

## Goals

- Make the logo + primary CTA read with clear visual hierarchy against the hero photo.
- Align the marketing site's accent language with the iOS app (pastel lavender/pink/peach accents, gradient CTAs, framed logo badge).
- Keep the baby-in-car hero photo — user likes it.
- Preserve existing brand tokens in `:root` (no token-level rebrand).

## User Stories

### US-001: Hero reads as on-brand at first glance
**Project**: soothbee-site

**As a** first-time visitor arriving from an ad or App Store page
**I want** the hero to feel warm, trustworthy, and clearly branded
**So that** I immediately understand this is Soothbee

**Acceptance Criteria**:
- [x] **AC-US1-01**: The hero overlay includes a cool counter-tone (dusk lavender `#9B8DC7`) in the shadow bands so honey-gold accents no longer blend into warm-sepia photo tones.
- [x] **AC-US1-02**: The italic accent word "listens." uses the deeper brand gold (`--primary #E8A838`), not pale `--primary-light`.
- [x] **AC-US1-03**: The logo lockup is ~1.4× visual weight with subtle honey glow.
- [x] **AC-US1-04**: A soft radial vignette darkens hero edges so the eye lands on headline + CTA.

### US-002: The "Get Soothbee" CTA pops off the warm photo
**Project**: soothbee-site

**As a** visitor scanning for the next action
**I want** the primary CTA to read as a distinct clickable object
**So that** I don't miss the entry point to installation

**Acceptance Criteria**:
- [x] **AC-US2-01**: Primary CTA uses a honey→amber gradient matching the iOS app "Start" button visual language.
- [x] **AC-US2-02**: CTA has ink-dark shadow + 1px outline so it detaches from the amber photo background.
- [x] **AC-US2-03**: Hover state shifts gradient for clear feedback.

### US-003: Mascot badge feels like premium packaging
**Project**: soothbee-site

**As a** visitor noticing the bottom-right mascot card
**I want** the card to feel like a native branded element
**So that** the mascot reads as personality, not an afterthought

**Acceptance Criteria**:
- [x] **AC-US3-01**: Mascot badge background is deeper ink (`rgba(10,6,2,.72)`) with a pastel lavender→pink gradient outline echoing the iOS app logo-frame.
- [x] **AC-US3-02**: Mascot icon sits inside a pastel gradient container matching the iOS Home screen bee icon frame.

### US-004: Eyebrow pill is legible
**Project**: soothbee-site

**As a** visitor
**I want** the eyebrow pill to read clearly
**So that** I understand feature scope in one glance

**Acceptance Criteria**:
- [x] **AC-US4-01**: Eyebrow pill uses `rgba(26,17,8,.55)` background with 1px `--primary-light` border, replacing the near-invisible `rgba(255,255,255,.08)`.

## Non-Goals

- No change to brand tokens in `:root`.
- No change to the hero photograph.
- No layout/structural changes — purely color, contrast, hierarchy.
- No content copy changes.

### US-005: SEO + performance polish
**Project**: soothbee-site

**As a** first-time visitor discovering Soothbee via Google
**I want** rich search snippets (FAQ expansions, app card, org info) and fast image loads
**So that** I click through with context and the page feels instant

**Acceptance Criteria**:
- [x] **AC-US5-01**: Page includes `FAQPage` JSON-LD with all 6 visible FAQ Q/A pairs.
- [x] **AC-US5-02**: Page includes `Organization` JSON-LD with `sameAs` link to the App Store listing.
- [x] **AC-US5-03**: Below-fold images use `loading="lazy"` + `decoding="async"`, and all images declare `width`/`height` to prevent CLS.
