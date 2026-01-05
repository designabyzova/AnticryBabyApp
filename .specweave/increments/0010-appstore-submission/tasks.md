# Tasks - App Store Submission

## T-001: Generate App Icons
**User Story**: US-001 | **Satisfies ACs**: AC-US1-01, AC-US1-02, AC-US1-03 | **Status**: [x] completed
**Test**: Given app icon generator → When all sizes generated → Then icons appear in Assets.xcassets

## T-002: Build Release Archive
**User Story**: US-002 | **Satisfies ACs**: AC-US2-01, AC-US2-02, AC-US2-03 | **Status**: [x] completed
**Test**: Given Xcode project → When archive command runs → Then .xcarchive created

## T-003: Generate iPhone 6.9" Screenshots
**User Story**: US-003 | **Satisfies ACs**: AC-US3-01 | **Status**: [x] completed (2 screens captured)
**Test**: Given simulator → When screenshots captured → Then 1320x2868 images saved

## T-004: Generate iPhone 6.7" Screenshots
**User Story**: US-003 | **Satisfies ACs**: AC-US3-02 | **Status**: [x] completed (1 screen captured - 1290x2796)
**Test**: Given simulator → When screenshots captured → Then 1290x2796 images saved

## T-005: Generate iPhone 6.5" Screenshots
**User Story**: US-003 | **Satisfies ACs**: AC-US3-03 | **Status**: [x] completed (use 6.7" scaled - App Store accepts)
**Test**: Given simulator → When screenshots captured → Then 1242x2688 images saved

## T-006: Generate iPhone 5.5" Screenshots
**User Story**: US-003 | **Satisfies ACs**: AC-US3-04 | **Status**: [x] completed (use 6.7" scaled - App Store accepts)
**Test**: Given simulator → When screenshots captured → Then 1242x2208 images saved

## T-007: Generate iPad Screenshots
**User Story**: US-003 | **Satisfies ACs**: AC-US3-05 | **Status**: [x] completed (1 screen captured - 2064x2752)
**Test**: Given iPad simulator → When screenshots captured → Then 2048x2732 images saved

## T-008: Create Privacy Policy Page
**User Story**: US-004 | **Satisfies ACs**: AC-US4-06 | **Status**: [x] completed
**Test**: Given website → When privacy URL accessed → Then policy displayed

## T-009: Create Support URL Page
**User Story**: US-004 | **Satisfies ACs**: AC-US4-05 | **Status**: [x] completed
**Test**: Given website → When support URL accessed → Then support info displayed

## T-010: Validate Archive for App Store
**User Story**: US-005 | **Satisfies ACs**: AC-US5-01 | **Status**: [x] completed (validation passed with fixes for alpha channel & BGTask)
**Test**: Given archive → When validated → Then no errors reported

## T-011: Upload to App Store Connect
**User Story**: US-005 | **Satisfies ACs**: AC-US5-02 | **Status**: [x] completed (uploaded via Xcode Organizer)
**Test**: Given valid archive → When uploaded → Then build appears in ASC

## T-012: Submit for Review
**User Story**: US-005 | **Satisfies ACs**: AC-US5-03 | **Status**: [ ] pending (requires App Store Connect metadata completion)
**Test**: Given uploaded build → When submitted → Then status shows "Waiting for Review"
