//
//  IntentHandler.swift
//  BabyInCarAppIntents
//
//  Intents Extension for Siri voice control
//  This extension runs independently from the main app and handles Siri intents.
//
//  Architecture:
//    User → "Hey Siri, play lullabies in Lulla"
//      ↓
//    iOS invokes this extension
//      ↓
//    Extension wakes main app via NSUserActivity
//      ↓
//    Main app handles playback (AudioEngine)
//
//  Supported Commands:
//    - "Hey Siri, play lullabies in Lulla"
//    - "Hey Siri, play classical music in Lulla"
//    - "Hey Siri, play nature sounds in Lulla"
//    - "Hey Siri, calm baby in Lulla"
//    - "Hey Siri, find Mozart in Lulla"
//    - "Hey Siri, add to favorites in Lulla"
//

import Intents

/// Main intent handler for the Intents Extension
/// Inherits from INExtension (required for extension entry point)
/// Implements specific intent handlers for each supported intent type
class IntentHandler: INExtension {

    /// Override to return specific handler for each intent type
    /// This method is called by iOS when Siri receives a voice command
    override func handler(for intent: INIntent) -> Any {
        // Route to appropriate handler based on intent type
        switch intent {
        case is INPlayMediaIntent:
            return PlayMediaIntentHandler()
        case is INSearchForMediaIntent:
            return SearchForMediaIntentHandler()
        case is INAddMediaIntent:
            return AddMediaIntentHandler()
        default:
            // Fallback to self for any unhandled intents
            return self
        }
    }
}

// MARK: - Play Media Intent Handler

/// Handles "Hey Siri, play [content] in Lulla" commands
class PlayMediaIntentHandler: NSObject, INPlayMediaIntentHandling {

    // Emergency phrases that trigger SmartEmergencyQueue
    private let emergencyPhrases = [
        "emergency", "calm baby", "baby crying", "soothe",
        "help baby", "cry again", "crying again", "urgent"
    ]

    /// Main handler - executes when user says "play X in Lulla"
    func handle(intent: INPlayMediaIntent, completion: @escaping (INPlayMediaIntentResponse) -> Void) {
        print("🎤 [Extension] Received INPlayMediaIntent")

        // Parse what the user wants to play
        let mediaSearch = intent.mediaSearch
        let searchText = (mediaSearch?.mediaName ?? "").lowercased()

        print("🎤 [Extension] Search text: '\(searchText)'")

        // Create user activity to hand off to main app
        let userActivity = NSUserActivity(activityType: "com.lulla.playMedia")

        // Check for emergency mode
        let isEmergency = emergencyPhrases.contains(where: { searchText.contains($0) })

        if isEmergency {
            print("🎤 [Extension] Emergency mode detected")
            userActivity.userInfo = [
                "action": "emergency",
                "searchText": searchText
            ]
        } else {
            // Parse category or search term
            let category = parseCategory(from: searchText)

            if let category = category {
                print("🎤 [Extension] Parsed category: \(category)")
                userActivity.userInfo = [
                    "action": "playCategory",
                    "category": category,
                    "searchText": searchText
                ]
            } else {
                print("🎤 [Extension] Search mode: '\(searchText)'")
                userActivity.userInfo = [
                    "action": "search",
                    "searchText": searchText
                ]
            }
        }

        // Tell iOS to open the main app and continue this activity
        let response = INPlayMediaIntentResponse(code: .continueInApp, userActivity: userActivity)
        completion(response)
    }

    /// Resolve media items - tell Siri what content is available
    func resolveMediaItems(for intent: INPlayMediaIntent, with completion: @escaping ([INPlayMediaMediaItemResolutionResult]) -> Void) {
        // If no specific item requested, provide default
        guard let mediaSearch = intent.mediaSearch,
              let searchTerm = mediaSearch.mediaName else {
            let defaultItem = INMediaItem(
                identifier: "default",
                title: "Lulla Music",
                type: .music,
                artwork: nil
            )
            completion([.success(with: defaultItem)])
            return
        }

        // Parse category
        let category = parseCategory(from: searchTerm.lowercased())

        if let category = category {
            let mediaItem = INMediaItem(
                identifier: category,
                title: category.capitalized,
                type: .musicStation,
                artwork: nil
            )
            completion([.success(with: mediaItem)])
        } else {
            // Generic search result
            let mediaItem = INMediaItem(
                identifier: "search:\(searchTerm)",
                title: searchTerm,
                type: .music,
                artwork: nil
            )
            completion([.success(with: mediaItem)])
        }
    }

    /// Parse category from search text
    private func parseCategory(from searchText: String) -> String? {
        let categoryMappings: [(keywords: [String], category: String)] = [
            (["lullaby", "lullabies", "bedtime song"], "lullabies"),
            (["classical", "mozart", "beethoven", "bach", "piano"], "classicalMusic"),
            (["fairy tale", "story", "stories", "bedtime story"], "fairyTales"),
            (["nature", "ocean", "waves", "forest", "birds"], "natureSounds"),
            (["ambient", "womb", "heartbeat"], "ambient"),
            (["instrumental", "guitar", "ukulele"], "instrumental"),
            (["children", "kids", "nursery", "nursery rhyme"], "childrenSongs"),
        ]

        for (keywords, category) in categoryMappings {
            if keywords.contains(where: { searchText.contains($0) }) {
                return category
            }
        }

        return nil
    }
}

// MARK: - Search For Media Intent Handler

/// Handles "Hey Siri, find [content] in Lulla" commands
class SearchForMediaIntentHandler: NSObject, INSearchForMediaIntentHandling {

    func handle(intent: INSearchForMediaIntent, completion: @escaping (INSearchForMediaIntentResponse) -> Void) {
        print("🎤 [Extension] Received INSearchForMediaIntent")

        guard let searchTerm = intent.mediaSearch?.mediaName else {
            completion(INSearchForMediaIntentResponse(code: .failure, userActivity: nil))
            return
        }

        print("🎤 [Extension] Search term: '\(searchTerm)'")

        // Create user activity to hand off to main app
        let userActivity = NSUserActivity(activityType: "com.lulla.searchMedia")
        userActivity.userInfo = [
            "action": "search",
            "searchTerm": searchTerm
        ]

        // For search, we show results in the app
        let response = INSearchForMediaIntentResponse(code: .continueInApp, userActivity: userActivity)
        completion(response)
    }
}

// MARK: - Add Media Intent Handler

/// Handles "Hey Siri, add to favorites in Lulla" commands
class AddMediaIntentHandler: NSObject, INAddMediaIntentHandling {

    func handle(intent: INAddMediaIntent, completion: @escaping (INAddMediaIntentResponse) -> Void) {
        print("🎤 [Extension] Received INAddMediaIntent")

        // Get track ID if specified, otherwise we'll use currently playing
        let trackId = intent.mediaItems?.first?.identifier

        // Create user activity to hand off to main app
        let userActivity = NSUserActivity(activityType: "com.lulla.addToFavorites")

        if let trackId = trackId {
            userActivity.userInfo = [
                "action": "addToFavorites",
                "trackId": trackId
            ]
        } else {
            userActivity.userInfo = [
                "action": "addToFavorites",
                "trackId": "current" // Signal to use current track
            ]
        }

        // Open app to add favorite
        let response = INAddMediaIntentResponse(code: .continueInApp, userActivity: userActivity)
        completion(response)
    }

    /// Resolve media destination - always favorites
    func resolveMediaDestination(for intent: INAddMediaIntent, with completion: @escaping (INAddMediaMediaDestinationResolutionResult) -> Void) {
        completion(.success(with: .library))
    }
}
