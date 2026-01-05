# Content Searchability & Taxonomy

## Problem Statement

Users cannot easily discover content by origin (e.g., "Russian fairy tales"), source (e.g., "Internet Archive", "LibriVox"), author (e.g., "Brothers Grimm", "Афанасьев"), or themes (e.g., "bedtime", "animals", "magic"). The current system only supports basic category filtering and simple text search on title/artist.

## Solution

Implement a comprehensive content taxonomy and full-text search system that allows users to:
1. Search by natural language queries ("Russian fairy tales", "lullabies for bedtime")
2. Browse by structured taxonomies (Origin, Author, Theme, Source, Age)
3. Discover related content through smart suggestions
4. Filter and combine multiple criteria

## User Stories

### US-001: Natural Language Search
**As a** parent
**I want to** search for content using natural phrases like "Russian fairy tales" or "calming nature sounds"
**So that** I can quickly find exactly what I'm looking for

**Acceptance Criteria:**
- [x] AC-US1-01: Full-text search on title, artist, tags, and description
- [x] AC-US1-02: Search supports multiple languages (English, Russian)
- [x] AC-US1-03: Search returns ranked results by relevance
- [x] AC-US1-04: Search handles synonyms (e.g., "lullaby" = "колыбельная")
- [x] AC-US1-05: Recent searches are saved and suggested

### US-002: Taxonomy Browsing
**As a** parent
**I want to** browse content by organized categories like Origin, Author, Theme
**So that** I can explore content I didn't know existed

**Acceptance Criteria:**
- [x] AC-US2-01: Content can be browsed by Origin (Russian, German, English, Japanese, etc.)
- [x] AC-US2-02: Content can be browsed by Author/Collector (Grimm, Афанасьев, Andersen, etc.)
- [x] AC-US2-03: Content can be browsed by Theme (animals, magic, adventure, moral, bedtime)
- [x] AC-US2-04: Content can be browsed by Source (LibriVox, Internet Archive, Original)
- [x] AC-US2-05: Each taxonomy shows track count and allows drill-down

### US-003: Smart Suggestions
**As a** parent
**I want to** see related content suggestions when viewing a track
**So that** I can discover more content my baby might like

**Acceptance Criteria:**
- [x] AC-US3-01: Related tracks shown based on same author/origin
- [x] AC-US3-02: Related tracks shown based on similar themes
- [x] AC-US3-03: "More like this" button suggests similar calming content
- [x] AC-US3-04: Suggestions consider baby's effectiveness history

### US-004: iOS Search UI
**As a** parent
**I want to** access search from anywhere in the app
**So that** I can quickly find content without navigating through menus

**Acceptance Criteria:**
- [x] AC-US4-01: Global search bar in library view
- [x] AC-US4-02: Search suggestions appear as user types
- [x] AC-US4-03: Filter chips for quick filtering (Language, Age, Duration)
- [x] AC-US4-04: Search results grouped by category
- [x] AC-US4-05: Empty state shows browse suggestions

## Technical Design

### Database Changes

Add new tables and indices for taxonomy:

```sql
-- Content taxonomy table
CREATE TABLE content_taxonomy (
  track_id TEXT NOT NULL,
  taxonomy_type TEXT NOT NULL, -- 'origin', 'author', 'theme', 'source'
  taxonomy_value TEXT NOT NULL,
  display_name TEXT,
  display_name_localized JSON, -- {"en": "Russian", "ru": "Русские"}
  PRIMARY KEY (track_id, taxonomy_type, taxonomy_value),
  FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
);

-- Full-text search virtual table
CREATE VIRTUAL TABLE tracks_fts USING fts5(
  title, artist, tags, description, origin, themes,
  content='tracks',
  content_rowid='rowid'
);

-- Search history
CREATE TABLE search_history (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  query TEXT NOT NULL,
  results_count INTEGER,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### API Endpoints

1. `GET /content/search` - Full-text search with filters
2. `GET /content/taxonomy/:type` - Get taxonomy values (origins, authors, themes)
3. `GET /content/browse/:taxonomy_type/:value` - Browse by taxonomy
4. `GET /content/tracks/:id/related` - Get related tracks
5. `GET /content/suggestions` - Get personalized suggestions

### Data Migration

Parse existing `tags` JSON and `artist` fields to populate taxonomy:
- Extract origin from language and artist name patterns
- Extract themes from tags
- Map sources from existing `source` field

## Out of Scope

- Voice search
- Image-based search
- User-generated tags
- Collaborative playlists

## Dependencies

- Existing tracks table with tags field
- D1 FTS5 support (SQLite full-text search)

## Deployment Notes

### Before deploying, configure Cloudflare resources:

1. **Create D1 Database** (if not exists):
   ```bash
   wrangler d1 create babyincar-db
   # Update wrangler.toml with the returned database_id
   ```

2. **Run Migration**:
   ```bash
   wrangler d1 execute babyincar-db --file=./migrations/008_content_taxonomy.sql --remote
   ```

3. **Deploy Worker**:
   ```bash
   wrangler deploy
   ```

### Files Implemented:
- `babyincar-api/migrations/008_content_taxonomy.sql` - Database schema
- `babyincar-api/src/routes/search.ts` - Search API endpoints
- `BabyInCarApp/Services/APIClient.swift` - iOS API client
- `BabyInCarApp/Views/SearchView.swift` - iOS search UI
- `BabyInCarApp/Views/LibraryView.swift` - Taxonomy browsing integration
- `BabyInCarApp/Views/PlayerView.swift` - "More Like This" feature
