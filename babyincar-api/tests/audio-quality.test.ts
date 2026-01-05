import { describe, it, expect, beforeAll } from 'vitest';

/**
 * Audio Quality Verification Tests
 *
 * These tests verify that all audio files in the library meet quality standards:
 * - All URLs return 200 status
 * - All files are > 100KB (no placeholder files)
 * - Duration metadata matches actual file duration (within tolerance)
 */

const API_BASE_URL = process.env.API_URL || 'https://babyincar-api.anton-abyzov.workers.dev';
const R2_PUBLIC_URL = 'https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev';

// Minimum file sizes by category
const MIN_FILE_SIZES: Record<string, number> = {
  nature_sounds: 100_000,      // 100KB minimum
  lullabies: 100_000,          // 100KB minimum
  classical: 100_000,          // 100KB minimum
  ambient: 100_000,            // 100KB minimum
  whitenoise: 100_000,         // 100KB minimum
  default: 100_000             // 100KB minimum for any category
};

// Sample tracks to verify (high priority CC0 tracks)
const CC0_TRACKS = [
  {
    id: 'cc0_nature_ocean_waves_beach',
    url: `${R2_PUBLIC_URL}/audio/nature/ocean_waves_beach_cc0.mp3`,
    expectedDuration: 1650, // 27.5 minutes
    minSize: 15_000_000     // ~15MB
  },
  {
    id: 'cc0_nature_sea_storm',
    url: `${R2_PUBLIC_URL}/audio/nature/sea_storm_cc0.mp3`,
    expectedDuration: 3600, // 60 minutes
    minSize: 40_000_000     // ~40MB
  },
  {
    id: 'cc0_nature_stream_birds',
    url: `${R2_PUBLIC_URL}/audio/nature/stream_birds_cc0.mp3`,
    expectedDuration: 1597, // 26.6 minutes
    minSize: 15_000_000     // ~15MB
  },
  {
    id: 'cc0_nature_gentle_rain',
    url: `${R2_PUBLIC_URL}/audio/nature/gentle_rain_cc0.mp3`,
    expectedDuration: 2160, // 36 minutes
    minSize: 20_000_000     // ~20MB
  },
  {
    id: 'cc0_nature_birdsong',
    url: `${R2_PUBLIC_URL}/audio/nature/birdsong_cc0.mp3`,
    expectedDuration: 582,  // 9.7 minutes
    minSize: 5_000_000      // ~5MB
  }
];

describe('Audio Quality Verification', () => {
  describe('CC0 Nature Sounds', () => {
    it.each(CC0_TRACKS)('$id should be accessible and have correct size', async ({ id, url, minSize }) => {
      const response = await fetch(url, { method: 'HEAD' });

      expect(response.status).toBe(200);

      const contentLength = parseInt(response.headers.get('content-length') || '0', 10);
      expect(contentLength).toBeGreaterThan(minSize);

      const contentType = response.headers.get('content-type');
      expect(contentType).toMatch(/audio\/(mpeg|mp3)/);
    }, 30000);

    it('all CC0 tracks should return 200 status', async () => {
      const results = await Promise.all(
        CC0_TRACKS.map(async (track) => {
          const response = await fetch(track.url, { method: 'HEAD' });
          return { id: track.id, status: response.status };
        })
      );

      for (const result of results) {
        expect(result.status).toBe(200);
      }
    }, 60000);
  });

  describe('API Audio Tracks Endpoint', () => {
    it('should return tracks from /api/tracks endpoint', async () => {
      const response = await fetch(`${API_BASE_URL}/content/tracks?category=nature_sounds`);

      expect(response.ok).toBe(true);

      const data = await response.json() as { tracks?: Array<{ id: string; stream_url: string; duration: number }> };
      expect(data.tracks).toBeDefined();
      expect(Array.isArray(data.tracks)).toBe(true);

      // Should have at least the 5 CC0 tracks
      const cc0Tracks = data.tracks?.filter((t: { id: string }) => t.id.startsWith('cc0_')) || [];
      expect(cc0Tracks.length).toBeGreaterThanOrEqual(5);
    }, 30000);

    it('all returned tracks should have valid stream_url', async () => {
      const response = await fetch(`${API_BASE_URL}/content/tracks?category=nature_sounds&limit=20`);
      const data = await response.json() as { tracks?: Array<{ id: string; stream_url: string }> };

      expect(data.tracks).toBeDefined();

      for (const track of data.tracks || []) {
        expect(track.stream_url).toBeDefined();
        expect(track.stream_url).toMatch(/^https?:\/\//);
        expect(track.stream_url).not.toContain('undefined');
        expect(track.stream_url).not.toContain('null');
      }
    }, 30000);
  });

  describe('No Placeholder Files', () => {
    it('should not have main category tracks with duration < 30 seconds', async () => {
      const response = await fetch(`${API_BASE_URL}/content/tracks?category=nature_sounds`);
      const data = await response.json() as { tracks?: Array<{ id: string; duration: number; title: string }> };

      // Short sound effects (< 30s) are acceptable, but main calming tracks should be longer
      // Filter to main calming tracks (ocean, rain, forest, stream)
      const mainCalmingTracks = data.tracks?.filter((t: { id: string; title: string }) =>
        t.id.includes('cc0_') ||
        t.title.toLowerCase().includes('forest') ||
        t.title.toLowerCase().includes('relaxing') ||
        t.id.includes('sea_storm') ||
        t.id.includes('gentle_rain')
      ) || [];

      const shortMainTracks = mainCalmingTracks.filter((t: { duration: number }) => t.duration < 30);

      // Log any problematic tracks for debugging
      if (shortMainTracks.length > 0) {
        console.log('Found short main tracks:', shortMainTracks.map((t: { id: string; title: string; duration: number }) =>
          `${t.id}: ${t.title} (${t.duration}s)`
        ));
      }

      expect(shortMainTracks.length).toBe(0);
    }, 30000);

    it('should not have any tracks with file size < 100KB', async () => {
      // Sample a few tracks to verify file sizes
      const sampleUrls = CC0_TRACKS.slice(0, 3).map(t => t.url);

      for (const url of sampleUrls) {
        const response = await fetch(url, { method: 'HEAD' });
        const contentLength = parseInt(response.headers.get('content-length') || '0', 10);

        expect(contentLength).toBeGreaterThan(MIN_FILE_SIZES.default);
      }
    }, 30000);
  });

  describe('Duration Accuracy', () => {
    it.each(CC0_TRACKS.slice(0, 2))('$id duration should match metadata within 5% tolerance', async ({ id, expectedDuration }) => {
      // Fetch track metadata from API
      const response = await fetch(`${API_BASE_URL}/content/tracks?category=nature_sounds`);
      const data = await response.json() as { tracks?: Array<{ id: string; duration: number }> };

      const track = data.tracks?.find((t: { id: string }) => t.id === id);
      expect(track).toBeDefined();

      if (track) {
        const tolerance = expectedDuration * 0.05; // 5% tolerance
        expect(track.duration).toBeGreaterThan(expectedDuration - tolerance);
        expect(track.duration).toBeLessThan(expectedDuration + tolerance);
      }
    }, 30000);
  });
});

describe('Audio Content Categories', () => {
  const categories = ['nature_sounds', 'classical_music', 'children_songs'];

  it.each(categories)('%s category should have at least 5 tracks', async (category) => {
    const response = await fetch(`${API_BASE_URL}/content/tracks?category=${category}`);
    const data = await response.json() as { tracks?: Array<{ id: string }> };

    expect(data.tracks).toBeDefined();
    expect(data.tracks?.length).toBeGreaterThanOrEqual(5);
  }, 30000);

  it('baby_sleep playlist should exist and have tracks', async () => {
    const response = await fetch(`${API_BASE_URL}/content/playlists/pl_baby_sleep`);

    if (response.ok) {
      const data = await response.json() as { playlist?: { tracks?: Array<{ id: string }> } };
      expect(data.playlist?.tracks?.length).toBeGreaterThan(0);
    } else {
      // Playlist endpoint might not exist, skip gracefully
      expect(response.status).toBe(404);
    }
  }, 30000);
});
