---
increment: 0034-soothbee-site-color-ultrathink-peach-dusk
title: 'Soothbee site color pass #2 — logo-derived peach↔lavender palette'
type: change-request
priority: P1
status: completed
created: 2026-04-24T00:00:00.000Z
structure: user-stories
---

# Color ultrathink — pull the site palette from the logo's four corners

## Problem

Pass #1 (increment 0033) added a `lavender → pink → honey` gradient frame around the logo and mascot card. But the **actual logo tile** has a **peach NW corner + lavender SE corner** (not pink). The site's pink `--tertiary #F4B8C5` doesn't appear anywhere in the real logo. Result: the gradient frames we added echo the *structure* of the logo but not its *hues*.

Also: the hero photo is warm-sepia (dusk mood), the copy calls Soothbee a "night-shift co-pilot," and the logo's SE corner is dusk-lavender. These three facts line up — the site can commit harder to a **dusk story** while using **peach as a "promise of dawn" accent** that echoes the logo's NW corner.

## Color narrative

The logo is a tiny sunrise palette:
- **NW corner**: peach dawn `#F5C89A` (promise of morning)
- **Center halo**: cream-gold `#FAF5E8` (the warmth of being soothed)
- **SE corner**: lavender dusk `#9B8DC7` (the night just survived)
- **Subject**: honey bee `#E8A838` (the product)

## Goals

- Add `--peach` / `--peach-light` / `--peach-dark` as first-class brand tokens.
- Replace every `--tertiary` (pink) gradient stop in hero/mascot/logo surfaces with peach.
- Add a peach warm-glow to the hero overlay upper-left (logo NW corner mirrored into the page).
- Tint the three hero-trust-row icons with brand colors (shield=lavender, zap=peach, check=honey) so the trust signals feel on-brand, not generic.
- Use peach as the eyebrow pill text color to connect the pill to the logo frame.
- Sprinkle peach subtly into the primary CTA gradient stop so honey→peach→amber reads as a continuous golden-hour sweep.

## User Stories

### US-001: Gradient frames match the real logo corners
**Project**: soothbee-site

**As a** visitor
**I want** the pastel gradient around the logo, mascot badge, and mascot card to use the same peach-to-lavender corner treatment as the real logo icon
**So that** the page element-chrome feels like it was derived from the logo, not bolted on

**Acceptance Criteria**:
- [x] **AC-US1-01**: `--peach`, `--peach-light`, `--peach-dark` exist in `:root`.
- [x] **AC-US1-02**: `.logo-mark` gradient frame uses `lavender → peach → primary-light` (pink removed).
- [x] **AC-US1-03**: `.hero-badge` outline gradient uses `lavender → peach → primary-light`.
- [x] **AC-US1-04**: `.hero-badge img` container uses `lavender → peach → primary-light`.

### US-002: Hero tells a peach-dawn + lavender-dusk story
**Project**: soothbee-site

**As a** visitor looking at the hero
**I want** a subtle peach warm-glow in the upper corner and lavender in the lower corner
**So that** the hero feels like dusk-to-dawn (the Soothbee journey) instead of flat warm-sepia

**Acceptance Criteria**:
- [x] **AC-US2-01**: Hero overlay includes a peach radial glow at upper-left (mirrors logo NW corner).
- [x] **AC-US2-02**: Hero overlay retains the existing lavender-dusk glow at lower-right.
- [x] **AC-US2-03**: Eyebrow pill text color is peach, not `--primary-light` — echoing the logo corner directly above the pill.

### US-003: CTA sweeps through golden-hour hues
**Project**: soothbee-site

**As a** visitor scanning for the primary action
**I want** the CTA gradient to feel like a continuous golden-hour sweep (peach → honey → amber) rather than a flat honey blob
**So that** the CTA visually carries the brand's warmth narrative

**Acceptance Criteria**:
- [x] **AC-US3-01**: `.nav-cta` / `.btn-primary` gradient stops are `peach-light → primary-light → primary → primary-dark`.

### US-004: Trust-row icons feel on-brand, not generic
**Project**: soothbee-site

**As a** visitor scanning the three micro-trust signals below the CTA
**I want** each icon tinted with one of the brand's three accent hues
**So that** the trust row feels designed, not stock-iconography

**Acceptance Criteria**:
- [x] **AC-US4-01**: Shield icon (on-device) is tinted lavender.
- [x] **AC-US4-02**: Lightning icon (speed) is tinted peach.
- [x] **AC-US4-03**: Check icon (free) is tinted honey.

### US-005: Scroll hint is a mini logo corner
**Project**: soothbee-site

**As a** visitor reaching the bottom of the hero
**I want** the scroll-hint line to transition from transparent → peach → lavender
**So that** even the smallest brand surface carries the logo's palette

**Acceptance Criteria**:
- [x] **AC-US5-01**: `.scroll-hint .line` uses `transparent → peach → lavender` gradient.
