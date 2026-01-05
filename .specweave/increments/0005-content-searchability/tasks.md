# Tasks - Content Searchability & Taxonomy

## T-001: Create database migration for taxonomy tables
**User Story**: US-001, US-002 | **Satisfies ACs**: AC-US1-01, AC-US2-01, AC-US2-02, AC-US2-03, AC-US2-04 | **Status**: [x] completed
**Test**: Given the database, When migration runs, Then content_taxonomy and tracks_fts tables exist with proper indices

Create migration file with:
- `content_taxonomy` table for structured taxonomy data
- FTS5 virtual table for full-text search
- `search_history` table for recent searches
- Proper indices for performance

---

## T-002: Populate taxonomy from existing track data
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-02, AC-US2-03, AC-US2-04, AC-US2-05 | **Status**: [x] completed
**Test**: Given tracks with tags/artist/language, When migration runs, Then taxonomy table has origin/author/theme/source entries

Parse existing data:
- Extract `origin` from `language` (ru → Russian, en → English) and artist patterns (Афанасьев → Russian)
- Extract `author` from `artist` field
- Extract `themes` from `tags` JSON array
- Extract `source` from existing source field

---

## T-003: Implement search API endpoint
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01, AC-US1-02, AC-US1-03 | **Status**: [x] completed
**Test**: Given query "russian fairy tales", When GET /content/search?q=russian+fairy+tales, Then returns Russian fairy tale tracks ranked by relevance

Implement `GET /content/search`:
- Query parameter: `q` (search query)
- Optional filters: `language`, `category`, `age_min`, `age_max`, `duration_max`
- Use FTS5 for full-text search with ranking
- Return paginated results with highlights

---

## T-004: Implement taxonomy browsing endpoints
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-02, AC-US2-03, AC-US2-04, AC-US2-05 | **Status**: [x] completed
**Test**: Given taxonomy data, When GET /content/taxonomy/origin, Then returns list of origins with track counts

Implement:
- `GET /content/taxonomy/:type` - List all values for a taxonomy type
- `GET /content/browse/:type/:value` - Get tracks for a specific taxonomy value
- Include track counts and localized display names

---

## T-005: Implement related tracks endpoint
**User Story**: US-003 | **Satisfies ACs**: AC-US3-01, AC-US3-02, AC-US3-03 | **Status**: [x] completed
**Test**: Given track with themes, When GET /content/tracks/:id/related, Then returns tracks with similar themes/origin

Implement `GET /content/tracks/:id/related`:
- Find tracks with same origin
- Find tracks with same author
- Find tracks with overlapping themes
- Rank by similarity and calming score

---

## T-006: Implement search suggestions endpoint
**User Story**: US-001, US-003 | **Satisfies ACs**: AC-US1-05, AC-US3-04 | **Status**: [x] completed
**Test**: Given search history and baby preferences, When GET /content/suggestions, Then returns personalized suggestions

Implement `GET /content/suggestions`:
- Return recent searches (authenticated users)
- Return popular searches
- Return trending content
- Consider baby's effectiveness history if authenticated

---

## T-007: Create iOS SearchView component
**User Story**: US-004 | **Satisfies ACs**: AC-US4-01, AC-US4-02, AC-US4-03, AC-US4-04, AC-US4-05 | **Status**: [x] completed
**Test**: Given SearchView, When user types query, Then suggestions appear and results are grouped

Create SwiftUI components:
- `SearchView` with search bar and results
- `SearchSuggestionRow` for autocomplete
- `FilterChipsView` for quick filters
- `TaxonomyBrowserView` for browsing by category

---

## T-008: Integrate search into LibraryView
**User Story**: US-004 | **Satisfies ACs**: AC-US4-01 | **Status**: [x] completed
**Test**: Given LibraryView, When search icon tapped, Then SearchView is presented

Add search integration:
- Add search icon to LibraryView navigation bar
- Present SearchView as sheet or navigation destination
- Maintain search state across navigation

---

## T-009: Add taxonomy browsing to Library
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-02, AC-US2-03, AC-US2-04, AC-US2-05 | **Status**: [x] completed
**Test**: Given LibraryView, When Browse section shown, Then user can browse by Origin, Author, Theme

Add browse sections to Library:
- "Browse by Origin" horizontal scroll
- "Browse by Author" section
- "Browse by Theme" section
- Each item shows icon, name, track count

---

## T-010: Add "More Like This" to PlayerView
**User Story**: US-003 | **Satisfies ACs**: AC-US3-01, AC-US3-02, AC-US3-03 | **Status**: [x] completed
**Test**: Given playing track, When "More Like This" tapped, Then related tracks are shown

Add related tracks UI:
- "More Like This" button in PlayerView
- Show related tracks in bottom sheet
- Allow quick play of related tracks

---

## T-011: Create API client methods for search
**User Story**: US-001, US-002, US-003 | **Satisfies ACs**: AC-US1-01, AC-US2-05, AC-US3-01 | **Status**: [x] completed
**Test**: Given API client, When search/taxonomy methods called, Then correct API endpoints are hit

Add to APIClient:
- `searchTracks(query:filters:)` method
- `getTaxonomy(type:)` method
- `browseTaxonomy(type:value:)` method
- `getRelatedTracks(trackId:)` method
- `getSuggestions()` method

---

## T-012: Add localized taxonomy display names
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-02 | **Status**: [x] completed
**Test**: Given Russian locale, When taxonomy displayed, Then Russian names shown ("Русские сказки")

Add localization:
- Store display_name_localized in taxonomy table
- Return appropriate locale based on user settings
- iOS displays localized names

---

## T-013: Implement search history persistence
**User Story**: US-001 | **Satisfies ACs**: AC-US1-05 | **Status**: [x] completed
**Test**: Given user searches, When they return to search, Then recent searches are shown

Implement search history:
- Save searches to search_history table (server)
- Cache recent searches locally (iOS)
- Show recent searches when search is empty
- Allow clearing search history
