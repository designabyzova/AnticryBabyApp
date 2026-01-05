# Tasks - Real Audio Quality Overhaul

## T-001: Delete All Placeholder Audio Files
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01 | **Status**: [x] completed
**Test**: Given placeholder files exist → When deletion script runs → Then all files < 100KB are removed

Deleted the following garbage files from the app bundle:
- `nature/ne_Calm_Ocean_cfcf4690.mp3`
- `nature/pb_Ocean_Waves_Calm_cfcf4690.mp3`
- `nature/ne_Beach_Waves_fe1b42d0.mp3`
- `nature/pb_Sea_Ambience_fe1b42d0.mp3`
- `nature/sb_stream.mp3`
- `lullabies/pb_Sleep_Music_cfcf4690.mp3`
- `classical/relaxing_piano_melody.mp3`
- `ambient/vt_Ofelia_9ab56a18.mp3`
- `ambient/vt_Going_Higher_8b6cbbcb.mp3`
- `ambient/ambient_piano_logo.mp3`

---

## T-002: Source Real Ocean Wave Sounds from Internet Archive
**User Story**: US-001 | **Satisfies ACs**: AC-US1-02 | **Status**: [x] completed
**Test**: Given ocean wave search → When download complete → Then file > 1MB and > 5 minutes

Downloaded from Internet Archive CC0 collection:
- `ocean_waves_beach_cc0.mp3` - 20.3MB, 27.5 minutes

---

## T-003: Source Real Stream/River Sounds
**User Story**: US-001 | **Satisfies ACs**: AC-US1-03 | **Status**: [x] completed
**Test**: Given stream search → When download complete → Then file > 1MB and > 5 minutes

Downloaded from Internet Archive CC0 collection:
- `stream_birds_cc0.mp3` - 16.9MB, 26.6 minutes

---

## T-004: Source Real Beach Wave Sounds
**User Story**: US-001 | **Satisfies ACs**: AC-US1-04 | **Status**: [x] completed
**Test**: Given beach wave search → When download complete → Then file > 1MB and > 5 minutes

Downloaded from Internet Archive CC0 collection:
- `sea_storm_cc0.mp3` - 43.9MB, 60 minutes

---

## T-005: Source Real Rain Sounds
**User Story**: US-001 | **Satisfies ACs**: AC-US1-05 | **Status**: [x] completed
**Test**: Given rain search → When download complete → Then file > 1MB and > 5 minutes

Downloaded from Internet Archive CC0 collection:
- `gentle_rain_cc0.mp3` - 24.6MB, 36 minutes
- `birdsong_cc0.mp3` - 7.3MB, 9.7 minutes

---

## T-006: Verify Existing Ambient Music Quality
**User Story**: US-001 | **Satisfies ACs**: AC-US1-05 | **Status**: [x] completed
**Test**: Given ambient files exist → When checked → Then all files > 100KB

Verified existing bensound tracks are high quality:
- `bensound_relaxing.mp3` - 4MB
- `bensound_dreams.mp3` - 5MB
- `bensound_memories.mp3` - 3.2MB
- And 12 more quality ambient tracks

---

## T-007: Verify Existing Lullaby/Classical Music Quality
**User Story**: US-001 | **Satisfies ACs**: AC-US1-06, AC-US1-07 | **Status**: [x] completed
**Test**: Given music files exist → When checked → Then all files > 100KB

Verified existing lullabies are high quality:
- `bedtime_tune.mp3` - 9.3MB, 6.5 min
- `gentle_melody.mp3` - 10.2MB, 7.1 min
- `lullaby_melody.mp3` - 8.9MB, 6.2 min

Verified existing classical tracks:
- `moonlight_sonata.mp3` - 15.8MB
- `clair_de_lune.mp3` - 6MB
- `gymnopedie_no1.mp3` - 9MB
- And more quality classical pieces

---

## T-008: Upload All New Audio Files to Cloudflare R2
**User Story**: US-001 | **Satisfies ACs**: AC-US1-08 | **Status**: [x] completed
**Test**: Given new audio files → When upload runs → Then all files accessible via R2 URL

Uploaded 5 CC0 files to R2:
- `https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ocean_waves_beach_cc0.mp3`
- `https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/sea_storm_cc0.mp3`
- `https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/stream_birds_cc0.mp3`
- `https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/gentle_rain_cc0.mp3`
- `https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/birdsong_cc0.mp3`

---

## T-009: Update Database with New Audio Entries
**User Story**: US-001 | **Satisfies ACs**: AC-US1-09 | **Status**: [x] completed
**Test**: Given new files uploaded → When migration runs → Then DB has correct URLs and durations

Created and ran `migrations/011_cc0_nature_sounds.sql`:
- Inserted 5 new CC0 tracks with accurate durations
- Created "Baby Sleep" playlist with best calming sounds
- Removed old placeholder track entries

---

## T-010: Create Audio Quality Verification Tests
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-02, AC-US2-03, AC-US2-04 | **Status**: [x] completed
**Test**: Given test suite → When npm test runs → Then all audio URLs verified

Created `tests/audio-quality.test.ts` with 16 tests:
1. CC0 tracks accessibility (5 tests)
2. API endpoint validation (3 tests)
3. File size verification (2 tests)
4. Duration accuracy (2 tests)
5. Category content (4 tests)

All 16 tests passing.

---

## T-011: Create Maestro E2E Audio Playback Test
**User Story**: US-002 | **Satisfies ACs**: AC-US2-05 | **Status**: [x] completed
**Test**: Given Maestro flow → When playback test runs → Then audio plays without error

Created `maestro/flows/audio_quality_flow.yaml`:
1. Navigate to Library
2. Select nature sounds category
3. Play ocean wave track
4. Verify playback starts
5. Check for no error states
6. Test rain sounds playback
