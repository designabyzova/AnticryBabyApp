# Tasks for FS-018: Audio Library Categorization

## Tasks

### T-001: Update English Fairy Tale Titles
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01, AC-US1-03 | **Status**: [x] completed
**Test**: Given tracks.json → When I read English fairy tales → Then titles are human-readable

### T-002: Update Russian Fairy Tale Titles
**User Story**: US-001 | **Satisfies ACs**: AC-US1-02, AC-US1-03 | **Status**: [x] completed
**Test**: Given tracks.json → When I read Russian fairy tales → Then titles have proper Russian names

### T-003: Rename Categories for Fairy Tales
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-02, AC-US2-03 | **Status**: [x] completed
**Test**: Given tracks.json → When I filter by category → Then fairytales_en and fairytales_ru exist

### T-004: Add contentType Field
**User Story**: US-003 | **Satisfies ACs**: AC-US3-01, AC-US3-02, AC-US3-03 | **Status**: [x] completed
**Test**: Given tracks.json → When I check any track → Then contentType field exists with correct value

### T-005: Verify JSON Validity
**User Story**: All | **Satisfies ACs**: All | **Status**: [x] completed
**Test**: Given updated tracks.json → When I parse it → Then it's valid JSON with no errors
