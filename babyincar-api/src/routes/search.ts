import { Hono } from 'hono';
import type { Env, Track } from '../types';
import { optionalAuthMiddleware, authMiddleware } from '../middleware/auth';

const search = new Hono<{ Bindings: Env }>();

// Types for search
interface TaxonomyItem {
  taxonomy_type: string;
  taxonomy_value: string;
  display_name: string;
  display_name_localized: string;
  icon: string | null;
  color: string | null;
  is_featured: number;
  track_count: number;
}

interface SearchResult extends Track {
  relevance_score?: number;
  highlight?: string;
  taxonomies?: {
    origin?: string[];
    author?: string[];
    theme?: string[];
    source?: string[];
  };
}

// ==============================================
// GET /search
// Full-text search with filters
// ==============================================
search.get('/', optionalAuthMiddleware, async (c) => {
  const query = c.req.query('q')?.trim();
  const category = c.req.query('category');
  const language = c.req.query('language');
  const origin = c.req.query('origin');
  const author = c.req.query('author');
  const theme = c.req.query('theme');
  const ageMin = c.req.query('age_min');
  const ageMax = c.req.query('age_max');
  const durationMax = c.req.query('duration_max');
  const limit = Math.min(parseInt(c.req.query('limit') || '30'), 100);
  const offset = parseInt(c.req.query('offset') || '0');

  if (!query && !category && !origin && !author && !theme) {
    return c.json({
      success: false,
      error: 'Search query or filter required',
    }, 400);
  }

  try {
    let tracks: SearchResult[] = [];
    let total = 0;

    // Normalize query (handle synonyms)
    let normalizedQuery = query || '';
    if (query) {
      const synonymResult = await c.env.DB.prepare(`
        SELECT canonical FROM search_synonyms
        WHERE LOWER(term) = LOWER(?)
      `).bind(query.toLowerCase()).first<{ canonical: string }>();

      if (synonymResult) {
        normalizedQuery = synonymResult.canonical;
      }
    }

    // Build search query
    if (query) {
      // Use FTS5 for text search
      const ftsQuery = normalizedQuery.split(/\s+/).map(term => `"${term}"*`).join(' OR ');

      let sql = `
        SELECT t.*, bm25(tracks_fts) as relevance_score
        FROM tracks t
        JOIN tracks_fts fts ON t.rowid = fts.rowid
        WHERE tracks_fts MATCH ?
      `;
      const params: (string | number)[] = [ftsQuery];

      // Apply filters
      if (category) {
        sql += ' AND t.category = ?';
        params.push(category);
      }

      if (language) {
        sql += ' AND t.language = ?';
        params.push(language);
      }

      if (ageMin) {
        sql += ' AND t.age_range_max >= ?';
        params.push(parseInt(ageMin));
      }

      if (ageMax) {
        sql += ' AND t.age_range_min <= ?';
        params.push(parseInt(ageMax));
      }

      if (durationMax) {
        sql += ' AND t.duration <= ?';
        params.push(parseInt(durationMax));
      }

      // Taxonomy filters (join with content_taxonomy)
      if (origin) {
        sql += ` AND t.id IN (SELECT track_id FROM content_taxonomy WHERE taxonomy_type = 'origin' AND taxonomy_value = ?)`;
        params.push(origin);
      }

      if (author) {
        sql += ` AND t.id IN (SELECT track_id FROM content_taxonomy WHERE taxonomy_type = 'author' AND taxonomy_value = ?)`;
        params.push(author);
      }

      if (theme) {
        sql += ` AND t.id IN (SELECT track_id FROM content_taxonomy WHERE taxonomy_type = 'theme' AND taxonomy_value = ?)`;
        params.push(theme);
      }

      // Count total
      const countSql = sql.replace('SELECT t.*, bm25(tracks_fts) as relevance_score', 'SELECT COUNT(*) as count');
      const countResult = await c.env.DB.prepare(countSql).bind(...params).first<{ count: number }>();
      total = countResult?.count || 0;

      // Get results with pagination
      sql += ' ORDER BY relevance_score LIMIT ? OFFSET ?';
      params.push(limit, offset);

      const result = await c.env.DB.prepare(sql).bind(...params).all<SearchResult>();
      tracks = result.results;

    } else {
      // No text query, just filters
      let sql = 'SELECT t.* FROM tracks t WHERE 1=1';
      const params: (string | number)[] = [];

      if (category) {
        sql += ' AND t.category = ?';
        params.push(category);
      }

      if (language) {
        sql += ' AND t.language = ?';
        params.push(language);
      }

      if (ageMin) {
        sql += ' AND t.age_range_max >= ?';
        params.push(parseInt(ageMin));
      }

      if (ageMax) {
        sql += ' AND t.age_range_min <= ?';
        params.push(parseInt(ageMax));
      }

      if (durationMax) {
        sql += ' AND t.duration <= ?';
        params.push(parseInt(durationMax));
      }

      if (origin) {
        sql += ` AND t.id IN (SELECT track_id FROM content_taxonomy WHERE taxonomy_type = 'origin' AND taxonomy_value = ?)`;
        params.push(origin);
      }

      if (author) {
        sql += ` AND t.id IN (SELECT track_id FROM content_taxonomy WHERE taxonomy_type = 'author' AND taxonomy_value = ?)`;
        params.push(author);
      }

      if (theme) {
        sql += ` AND t.id IN (SELECT track_id FROM content_taxonomy WHERE taxonomy_type = 'theme' AND taxonomy_value = ?)`;
        params.push(theme);
      }

      // Count total
      const countSql = sql.replace('SELECT t.*', 'SELECT COUNT(*) as count');
      const countResult = await c.env.DB.prepare(countSql).bind(...params).first<{ count: number }>();
      total = countResult?.count || 0;

      // Get results with pagination
      sql += ' ORDER BY t.calming_score DESC, t.title LIMIT ? OFFSET ?';
      params.push(limit, offset);

      const result = await c.env.DB.prepare(sql).bind(...params).all<SearchResult>();
      tracks = result.results;
    }

    // Enrich with taxonomy data
    if (tracks.length > 0) {
      const trackIds = tracks.map(t => t.id);
      const placeholders = trackIds.map(() => '?').join(',');

      const taxonomyResult = await c.env.DB.prepare(`
        SELECT track_id, taxonomy_type, taxonomy_value
        FROM content_taxonomy
        WHERE track_id IN (${placeholders})
      `).bind(...trackIds).all<{ track_id: string; taxonomy_type: string; taxonomy_value: string }>();

      // Group taxonomies by track
      const taxonomyMap = new Map<string, { origin: string[]; author: string[]; theme: string[]; source: string[] }>();
      for (const row of taxonomyResult.results) {
        if (!taxonomyMap.has(row.track_id)) {
          taxonomyMap.set(row.track_id, { origin: [], author: [], theme: [], source: [] });
        }
        const trackTax = taxonomyMap.get(row.track_id)!;
        if (row.taxonomy_type === 'origin') trackTax.origin.push(row.taxonomy_value);
        if (row.taxonomy_type === 'author') trackTax.author.push(row.taxonomy_value);
        if (row.taxonomy_type === 'theme') trackTax.theme.push(row.taxonomy_value);
        if (row.taxonomy_type === 'source') trackTax.source.push(row.taxonomy_value);
      }

      // Attach to tracks
      tracks = tracks.map(t => ({
        ...t,
        taxonomies: taxonomyMap.get(t.id) || { origin: [], author: [], theme: [], source: [] },
      }));
    }

    // Log search for history (authenticated users only)
    const userId = c.get('userId');
    if (userId && query) {
      const searchId = `search_${Date.now()}_${Math.random().toString(36).substring(2, 10)}`;
      await c.env.DB.prepare(`
        INSERT INTO search_history (id, user_id, query, query_normalized, results_count, created_at)
        VALUES (?, ?, ?, ?, ?, datetime('now'))
      `).bind(searchId, userId, query, query.toLowerCase().trim(), total).run();

      // Update popular searches
      await c.env.DB.prepare(`
        INSERT INTO popular_searches (query_normalized, display_query, search_count, last_searched_at)
        VALUES (?, ?, 1, datetime('now'))
        ON CONFLICT(query_normalized) DO UPDATE SET
          search_count = search_count + 1,
          last_searched_at = datetime('now')
      `).bind(query.toLowerCase().trim(), query).run();
    }

    // Premium content handling
    const user = c.get('user');
    const isPremium = user && user.subscription_status !== 'free';

    tracks = tracks.map(track => ({
      ...track,
      stream_url: (!track.is_premium || isPremium) ? track.stream_url : null,
      is_locked: track.is_premium && !isPremium,
    }));

    return c.json({
      success: true,
      query: query || null,
      normalized_query: query ? normalizedQuery : null,
      filters: {
        category: category || null,
        language: language || null,
        origin: origin || null,
        author: author || null,
        theme: theme || null,
      },
      tracks,
      total,
      has_more: offset + limit < total,
    });

  } catch (error) {
    console.error('Search error:', error);
    return c.json({ success: false, error: 'Search failed' }, 500);
  }
});

// ==============================================
// GET /search/taxonomy/:type
// Get all values for a taxonomy type
// ==============================================
search.get('/taxonomy/:type', async (c) => {
  const taxonomyType = c.req.param('type');
  const locale = c.req.query('locale') || 'en';

  const validTypes = ['origin', 'author', 'theme', 'source', 'collection'];
  if (!validTypes.includes(taxonomyType)) {
    return c.json({ success: false, error: 'Invalid taxonomy type' }, 400);
  }

  try {
    const result = await c.env.DB.prepare(`
      SELECT
        tc.taxonomy_type,
        tc.taxonomy_value,
        cat.display_name,
        cat.display_name_localized,
        cat.icon,
        cat.color,
        cat.is_featured,
        cat.description,
        COUNT(DISTINCT tc.track_id) as track_count
      FROM content_taxonomy tc
      JOIN taxonomy_catalog cat ON tc.taxonomy_type = cat.taxonomy_type AND tc.taxonomy_value = cat.taxonomy_value
      WHERE tc.taxonomy_type = ?
      GROUP BY tc.taxonomy_value
      HAVING track_count > 0
      ORDER BY cat.is_featured DESC, cat.sort_order, track_count DESC
    `).bind(taxonomyType).all<TaxonomyItem>();

    // Extract localized names
    const items = result.results.map(item => {
      let displayName = item.display_name;
      try {
        const localized = JSON.parse(item.display_name_localized || '{}');
        if (localized[locale]) {
          displayName = localized[locale];
        }
      } catch {}

      return {
        value: item.taxonomy_value,
        display_name: displayName,
        icon: item.icon,
        color: item.color,
        is_featured: item.is_featured === 1,
        track_count: item.track_count,
      };
    });

    return c.json({
      success: true,
      taxonomy_type: taxonomyType,
      items,
    });

  } catch (error) {
    console.error('Taxonomy fetch error:', error);
    return c.json({ success: false, error: 'Failed to fetch taxonomy' }, 500);
  }
});

// ==============================================
// GET /search/browse/:type/:value
// Get tracks for a specific taxonomy value
// ==============================================
search.get('/browse/:type/:value', optionalAuthMiddleware, async (c) => {
  const taxonomyType = c.req.param('type');
  const taxonomyValue = c.req.param('value');
  const limit = Math.min(parseInt(c.req.query('limit') || '50'), 100);
  const offset = parseInt(c.req.query('offset') || '0');
  const sortBy = c.req.query('sort') || 'calming_score';

  const validTypes = ['origin', 'author', 'theme', 'source', 'collection'];
  if (!validTypes.includes(taxonomyType)) {
    return c.json({ success: false, error: 'Invalid taxonomy type' }, 400);
  }

  const validSorts = ['calming_score', 'title', 'duration', 'created_at'];
  const sortColumn = validSorts.includes(sortBy) ? sortBy : 'calming_score';
  const sortOrder = sortBy === 'title' ? 'ASC' : 'DESC';

  try {
    // Get taxonomy metadata
    const catalog = await c.env.DB.prepare(`
      SELECT * FROM taxonomy_catalog
      WHERE taxonomy_type = ? AND taxonomy_value = ?
    `).bind(taxonomyType, taxonomyValue).first();

    if (!catalog) {
      return c.json({ success: false, error: 'Taxonomy value not found' }, 404);
    }

    // Get tracks count
    const countResult = await c.env.DB.prepare(`
      SELECT COUNT(*) as count FROM tracks t
      JOIN content_taxonomy ct ON t.id = ct.track_id
      WHERE ct.taxonomy_type = ? AND ct.taxonomy_value = ?
    `).bind(taxonomyType, taxonomyValue).first<{ count: number }>();

    const total = countResult?.count || 0;

    // Get tracks
    const result = await c.env.DB.prepare(`
      SELECT t.* FROM tracks t
      JOIN content_taxonomy ct ON t.id = ct.track_id
      WHERE ct.taxonomy_type = ? AND ct.taxonomy_value = ?
      ORDER BY t.${sortColumn} ${sortOrder}
      LIMIT ? OFFSET ?
    `).bind(taxonomyType, taxonomyValue, limit, offset).all<Track>();

    // Premium content handling
    const user = c.get('user');
    const isPremium = user && user.subscription_status !== 'free';

    const tracks = result.results.map(track => ({
      ...track,
      stream_url: (!track.is_premium || isPremium) ? track.stream_url : null,
      is_locked: track.is_premium && !isPremium,
    }));

    // Get localized name
    const locale = c.req.query('locale') || 'en';
    let displayName = (catalog as any).display_name;
    try {
      const localized = JSON.parse((catalog as any).display_name_localized || '{}');
      if (localized[locale]) {
        displayName = localized[locale];
      }
    } catch {}

    return c.json({
      success: true,
      taxonomy: {
        type: taxonomyType,
        value: taxonomyValue,
        display_name: displayName,
        icon: (catalog as any).icon,
        color: (catalog as any).color,
        description: (catalog as any).description,
      },
      tracks,
      total,
      has_more: offset + limit < total,
    });

  } catch (error) {
    console.error('Browse error:', error);
    return c.json({ success: false, error: 'Failed to browse taxonomy' }, 500);
  }
});

// ==============================================
// GET /search/related/:trackId
// Get tracks related to a specific track
// ==============================================
search.get('/related/:trackId', optionalAuthMiddleware, async (c) => {
  const trackId = c.req.param('trackId');
  const limit = Math.min(parseInt(c.req.query('limit') || '10'), 30);

  try {
    // Get the source track
    const track = await c.env.DB.prepare(`
      SELECT * FROM tracks WHERE id = ?
    `).bind(trackId).first<Track>();

    if (!track) {
      return c.json({ success: false, error: 'Track not found' }, 404);
    }

    // Get track's taxonomies
    const taxonomyResult = await c.env.DB.prepare(`
      SELECT taxonomy_type, taxonomy_value FROM content_taxonomy WHERE track_id = ?
    `).bind(trackId).all<{ taxonomy_type: string; taxonomy_value: string }>();

    const themes = taxonomyResult.results.filter(t => t.taxonomy_type === 'theme').map(t => t.taxonomy_value);
    const origins = taxonomyResult.results.filter(t => t.taxonomy_type === 'origin').map(t => t.taxonomy_value);
    const authors = taxonomyResult.results.filter(t => t.taxonomy_type === 'author').map(t => t.taxonomy_value);

    // Find related tracks with scoring
    // Priority: Same author > Same origin > Same themes > Same category
    let sql = `
      SELECT DISTINCT t.*,
        (
          CASE WHEN ct_author.track_id IS NOT NULL THEN 40 ELSE 0 END +
          CASE WHEN ct_origin.track_id IS NOT NULL THEN 30 ELSE 0 END +
          CASE WHEN ct_theme.track_id IS NOT NULL THEN 20 ELSE 0 END +
          CASE WHEN t.category = ? THEN 10 ELSE 0 END +
          t.calming_score * 10
        ) as similarity_score
      FROM tracks t
      LEFT JOIN content_taxonomy ct_author ON t.id = ct_author.track_id
        AND ct_author.taxonomy_type = 'author'
        AND ct_author.taxonomy_value IN (${authors.map(() => '?').join(',') || "''"})
      LEFT JOIN content_taxonomy ct_origin ON t.id = ct_origin.track_id
        AND ct_origin.taxonomy_type = 'origin'
        AND ct_origin.taxonomy_value IN (${origins.map(() => '?').join(',') || "''"})
      LEFT JOIN content_taxonomy ct_theme ON t.id = ct_theme.track_id
        AND ct_theme.taxonomy_type = 'theme'
        AND ct_theme.taxonomy_value IN (${themes.map(() => '?').join(',') || "''"})
      WHERE t.id != ?
        AND t.category = ?
      ORDER BY similarity_score DESC, t.calming_score DESC
      LIMIT ?
    `;

    const params = [
      track.category,
      ...authors,
      ...origins,
      ...themes,
      trackId,
      track.category,
      limit,
    ];

    const result = await c.env.DB.prepare(sql).bind(...params).all<Track & { similarity_score: number }>();

    // Premium content handling
    const user = c.get('user');
    const isPremium = user && user.subscription_status !== 'free';

    const tracks = result.results.map(t => ({
      ...t,
      stream_url: (!t.is_premium || isPremium) ? t.stream_url : null,
      is_locked: t.is_premium && !isPremium,
    }));

    return c.json({
      success: true,
      source_track: {
        id: track.id,
        title: track.title,
        category: track.category,
      },
      related_tracks: tracks,
    });

  } catch (error) {
    console.error('Related tracks error:', error);
    return c.json({ success: false, error: 'Failed to get related tracks' }, 500);
  }
});

// ==============================================
// GET /search/suggestions
// Get search suggestions and trending searches
// ==============================================
search.get('/suggestions', optionalAuthMiddleware, async (c) => {
  const userId = c.get('userId');
  const locale = c.req.query('locale') || 'en';

  try {
    const suggestions: {
      recent: { query: string; results_count: number }[];
      popular: { query: string; search_count: number }[];
      featured_taxonomies: TaxonomyItem[];
    } = {
      recent: [],
      popular: [],
      featured_taxonomies: [],
    };

    // Get recent searches for authenticated user
    if (userId) {
      const recentResult = await c.env.DB.prepare(`
        SELECT DISTINCT query, results_count
        FROM search_history
        WHERE user_id = ?
        ORDER BY created_at DESC
        LIMIT 5
      `).bind(userId).all<{ query: string; results_count: number }>();

      suggestions.recent = recentResult.results;
    }

    // Get popular searches
    const popularResult = await c.env.DB.prepare(`
      SELECT display_query as query, search_count
      FROM popular_searches
      ORDER BY search_count DESC, last_searched_at DESC
      LIMIT 10
    `).all<{ query: string; search_count: number }>();

    suggestions.popular = popularResult.results;

    // Get featured taxonomies (for empty state browsing)
    const featuredResult = await c.env.DB.prepare(`
      SELECT
        cat.taxonomy_type,
        cat.taxonomy_value,
        cat.display_name,
        cat.display_name_localized,
        cat.icon,
        cat.color,
        cat.is_featured,
        COUNT(DISTINCT ct.track_id) as track_count
      FROM taxonomy_catalog cat
      JOIN content_taxonomy ct ON cat.taxonomy_type = ct.taxonomy_type AND cat.taxonomy_value = ct.taxonomy_value
      WHERE cat.is_featured = 1
      GROUP BY cat.taxonomy_type, cat.taxonomy_value
      HAVING track_count > 0
      ORDER BY cat.taxonomy_type, cat.sort_order
      LIMIT 15
    `).all<TaxonomyItem>();

    // Extract localized names
    suggestions.featured_taxonomies = featuredResult.results.map(item => {
      let displayName = item.display_name;
      try {
        const localized = JSON.parse(item.display_name_localized || '{}');
        if (localized[locale]) {
          displayName = localized[locale];
        }
      } catch {}

      return {
        ...item,
        display_name: displayName,
      };
    });

    return c.json({
      success: true,
      suggestions,
    });

  } catch (error) {
    console.error('Suggestions error:', error);
    return c.json({ success: false, error: 'Failed to get suggestions' }, 500);
  }
});

// ==============================================
// DELETE /search/history
// Clear search history for authenticated user
// ==============================================
search.delete('/history', authMiddleware, async (c) => {
  const userId = c.get('userId');

  try {
    await c.env.DB.prepare(`
      DELETE FROM search_history WHERE user_id = ?
    `).bind(userId).run();

    return c.json({
      success: true,
      message: 'Search history cleared',
    });

  } catch (error) {
    console.error('Clear history error:', error);
    return c.json({ success: false, error: 'Failed to clear history' }, 500);
  }
});

export default search;
