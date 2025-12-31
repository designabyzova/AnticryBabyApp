# FS-001: Audio Library Cleanup - Fix Placeholders and Enable Real Content

## Problem Statement

The audio library has several critical issues:
1. Many audio files are placeholders (beeps, hardcoded values) instead of real melodies
2. Russian-labeled files contain placeholder audio, not actual Russian content
3. Style mismatch - files named "gentle" may not be gentle
4. Children's content needs to be appropriate and pleasant
5. Audio should stream from API, not rely on potentially broken local files

## User Stories

### US-001: Remove Placeholder Audio
As a parent, I want all audio tracks to contain real, pleasant music instead of placeholder beeps so my baby can be soothed.

**Acceptance Criteria:**
- [x] AC-US1-01: Identify all placeholder/hardcoded audio files in local storage
- [x] AC-US1-02: Remove placeholder files from the bundle
- [x] AC-US1-03: Ensure ContentLibraryService fetches real content from API

### US-002: Fix Russian Content Labels
As a Russian-speaking parent, I want properly labeled Russian content with actual Russian audio.

**Acceptance Criteria:**
- [x] AC-US2-01: Audit Russian-named files for placeholder content
- [x] AC-US2-02: Remove fake Russian placeholders
- [x] AC-US2-03: Configure API to serve real Russian fairytales/lullabies

### US-003: Verify All Categories Work via API
As a user, I want every audio category to play real content through the API.

**Acceptance Criteria:**
- [x] AC-US3-01: Test classical music category streams correctly
- [x] AC-US3-02: Test children's songs category streams correctly
- [x] AC-US3-03: Test fairytales category streams correctly
- [x] AC-US3-04: Test nature sounds category streams correctly
- [x] AC-US3-05: Test white noise category streams correctly
- [x] AC-US3-06: Test ambient category streams correctly
- [x] AC-US3-07: Test instrumental category streams correctly

### US-004: Ensure Content Quality
As a parent, I want audio content to match its name and be appropriate for children.

**Acceptance Criteria:**
- [x] AC-US4-01: Verify "gentle" melodies are actually gentle (low tempo, soft sounds)
- [x] AC-US4-02: Ensure children's content is age-appropriate
- [x] AC-US4-03: Audio style matches the category metadata

## Technical Approach

1. Audit local Resources/Audio for placeholder files (small size, synthetic beeps)
2. Remove placeholder files from Xcode project
3. Update ContentLibraryService to prioritize API content
4. Verify API endpoints return real audio streams
5. Test each category through the API

## Out of Scope

- Creating new audio content (use existing API curation)
- Changing the audio player architecture
- Subscription/premium changes
