//
//  APIContentIntegrationTests.swift
//  BabyInCarAppTests
//
//  Integration tests for API content endpoints
//  Verifies tracks have correct data from D1 database
//

import XCTest
@testable import BabyInCarApp

final class APIContentIntegrationTests: XCTestCase {

    // MARK: - Properties

    var apiClient: APIClient!

    override func setUp() {
        super.setUp()
        apiClient = APIClient.shared
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Nature Sounds API Tests

    func testFetchNatureSounds_ReturnsTracksWithCorrectDurations() async throws {
        // Skip if no network (for CI environments)
        guard await hasNetworkConnectivity() else {
            throw XCTSkip("No network connectivity for integration test")
        }

        // When fetching nature sounds from API
        // This uses the content library service which calls the API
        let contentService = ContentLibraryService.shared

        // Wait for library to refresh
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // Get all nature sounds
        let natureSounds = contentService.allTracks.filter { $0.category == .natureSounds }

        // Then we should have nature sounds
        XCTAssertGreaterThan(natureSounds.count, 0, "Should have nature sound tracks")

        // And they should NOT all have hardcoded 600 second duration
        let durationVariety = Set(natureSounds.map { Int($0.duration) })
        XCTAssertGreaterThan(durationVariety.count, 1,
                            "Nature sounds should have varied durations, not all 600s")
    }

    func testNatureSoundStreamURLs_AreValid() async throws {
        // Skip if no network
        guard await hasNetworkConnectivity() else {
            throw XCTSkip("No network connectivity for integration test")
        }

        // Given nature sounds with stream URLs
        let contentService = ContentLibraryService.shared

        try await Task.sleep(nanoseconds: 2_000_000_000)

        let natureSounds = contentService.allTracks.filter {
            $0.category == .natureSounds && $0.streamURL != nil
        }

        // Then all stream URLs should be valid R2 URLs
        for track in natureSounds.prefix(5) { // Test first 5 to avoid rate limits
            guard let url = track.streamURL else { continue }

            XCTAssertTrue(url.absoluteString.contains("r2.dev/audio/"),
                         "Stream URL should point to R2: \(url)")

            // Verify URL is accessible
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 10

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    XCTAssertEqual(httpResponse.statusCode, 200,
                                  "Track \(track.title) should be accessible at \(url)")
                }
            } catch {
                XCTFail("Failed to access \(track.title): \(error)")
            }
        }
    }

    // MARK: - All Categories API Tests

    func testAllCategories_HaveTracksWithPositiveDurations() async throws {
        guard await hasNetworkConnectivity() else {
            throw XCTSkip("No network connectivity for integration test")
        }

        let contentService = ContentLibraryService.shared

        try await Task.sleep(nanoseconds: 2_000_000_000)

        // Check each category
        let categories: [AudioCategory] = [
            .lullabies,
            .natureSounds,
            .ambient,
            .classicalMusic,
            .fairyTales
        ]

        for category in categories {
            let tracks = contentService.allTracks.filter { $0.category == category }

            // All tracks should have positive duration
            for track in tracks {
                XCTAssertGreaterThan(track.duration, 0,
                                    "\(track.title) in \(category.displayName) should have positive duration")
            }
        }
    }

    // MARK: - R2 Audio Streaming Tests

    func testR2AudioStreaming_SupportsRangeRequests() async throws {
        guard await hasNetworkConnectivity() else {
            throw XCTSkip("No network connectivity for integration test")
        }

        // Given an R2 audio URL
        let testURL = URL(string: "https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/audio/nature/ocean_waves.mp3")!

        // When making a range request
        var request = URLRequest(url: testURL)
        request.httpMethod = "GET"
        request.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                // Then it should support partial content (206)
                XCTAssertTrue([200, 206].contains(httpResponse.statusCode),
                             "R2 should support range requests")

                // And return partial data
                XCTAssertLessThanOrEqual(data.count, 1024,
                                        "Should return partial content for range request")
            }
        } catch {
            XCTFail("Range request failed: \(error)")
        }
    }

    // MARK: - Helpers

    private func hasNetworkConnectivity() async -> Bool {
        let testURL = URL(string: "https://pub-8e38f4cfedc94123855a13244c87d5dc.r2.dev/")!
        var request = URLRequest(url: testURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
