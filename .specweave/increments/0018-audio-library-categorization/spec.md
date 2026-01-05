# FS-018: Audio Library Categorization

## Overview
Clean separation between fairy tales (audiobooks) and music/sounds in the audio library with proper human-readable titles and clear content type distinction.

## User Stories

### US-001: Proper Fairy Tale Titles
**As a** parent browsing the library
**I want** fairy tales to have proper human-readable titles
**So that** I can easily identify and select stories for my child

**Acceptance Criteria:**
- [x] AC-US1-01: English fairy tales have proper titles (e.g., "Sleeping Beauty" instead of "Grimm Briar Rose")
- [x] AC-US1-02: Russian fairy tales have proper bilingual titles (English + Cyrillic)
- [x] AC-US1-03: Artist field shows proper author attribution (Brothers Grimm, Afanasyev Collection)

### US-002: Clear Category Separation
**As a** user navigating the app
**I want** clear separation between spoken content and music
**So that** I can quickly find what I'm looking for

**Acceptance Criteria:**
- [x] AC-US2-01: Category "english" renamed to "fairytales_en"
- [x] AC-US2-02: Category "russian" renamed to "fairytales_ru"
- [x] AC-US2-03: Subcategory matches new category names

### US-003: Content Type Distinction
**As a** developer or filter system
**I want** a contentType field on each track
**So that** I can distinguish audiobooks from music/sounds

**Acceptance Criteria:**
- [x] AC-US3-01: All fairy tales have `contentType: "audiobook"`
- [x] AC-US3-02: All music tracks have `contentType: "music"`
- [x] AC-US3-03: All nature/whitenoise tracks have `contentType: "sounds"`

## Technical Notes
- Updates to tracks.json only
- No backend changes required
- iOS app reads categories from JSON
