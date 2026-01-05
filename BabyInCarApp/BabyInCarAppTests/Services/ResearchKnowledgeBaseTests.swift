//
//  ResearchKnowledgeBaseTests.swift
//  BabyInCarAppTests
//
//  Unit tests for ResearchKnowledgeBase
//

import XCTest
import Testing
@testable import BabyInCarApp

// MARK: - Swift Testing Suite

@Suite("Research Knowledge Base")
struct ResearchKnowledgeBaseTests {

    // MARK: - Citation Tests

    @Test("Research database is populated")
    func citationsPopulated() {
        let knowledge = ResearchKnowledgeBase.shared

        let carSoundCitations = knowledge.getCitations(for: .carSounds)
        #expect(!carSoundCitations.isEmpty, "Should have car sound citations")

        let fiveSSCitations = knowledge.getCitations(for: .fiveSs)
        #expect(!fiveSSCitations.isEmpty, "Should have 5 S's citations")

        let whiteNoiseCitations = knowledge.getCitations(for: .whiteNoise)
        #expect(!whiteNoiseCitations.isEmpty, "Should have white noise citations")
    }

    @Test("Citations have required fields")
    func citationFields() {
        let knowledge = ResearchKnowledgeBase.shared
        let citations = knowledge.getCitations(for: .carSounds)

        for citation in citations {
            #expect(!citation.title.isEmpty, "Citation should have title")
            #expect(!citation.authors.isEmpty, "Citation should have authors")
            #expect(citation.year > 1900, "Citation should have valid year")
            #expect(!citation.summary.isEmpty, "Citation should have summary")
            #expect(!citation.keyFindings.isEmpty, "Citation should have key findings")
        }
    }

    @Test("Search returns relevant citations")
    func searchCitations() {
        let knowledge = ResearchKnowledgeBase.shared

        let hondaResults = knowledge.searchCitations(query: "honda")
        #expect(!hondaResults.isEmpty, "Should find Honda study")

        let karpResults = knowledge.searchCitations(query: "karp")
        #expect(!karpResults.isEmpty, "Should find Dr. Karp research")
    }

    // MARK: - Explanation Tests

    @Test("Explanations exist for research topics", arguments: [
        ResearchTopic.whiteNoise,
        ResearchTopic.pinkNoise,
        ResearchTopic.carSounds,
        ResearchTopic.fiveSs,
        ResearchTopic.lullabies,
        ResearchTopic.wombSounds
    ])
    func explanationsExist(topic: ResearchTopic) {
        let knowledge = ResearchKnowledgeBase.shared

        let explanation = knowledge.getExplanation(for: topic)
        #expect(explanation != nil, "Should have explanation for \(topic)")

        if let exp = explanation {
            #expect(!exp.shortExplanation.isEmpty)
            #expect(!exp.detailedExplanation.isEmpty)
            #expect(exp.confidence > 0)
        }
    }

    @Test("Parent-friendly explanations are generated")
    func parentFriendlyExplanations() {
        let knowledge = ResearchKnowledgeBase.shared

        let explanation = knowledge.getParentFriendlyExplanation(
            soundType: .womb,
            cryType: .tired,
            babyAge: 6
        )

        #expect(!explanation.isEmpty)
        #expect(explanation.contains("heartbeat") || explanation.contains("womb"))
    }

    @Test("Car environment explanation varies by score")
    func carEnvironmentExplanations() {
        let knowledge = ResearchKnowledgeBase.shared

        let highScore = knowledge.getCarEnvironmentExplanation(soothingScore: 0.8)
        let midScore = knowledge.getCarEnvironmentExplanation(soothingScore: 0.5)
        let lowScore = knowledge.getCarEnvironmentExplanation(soothingScore: 0.2)

        #expect(highScore != lowScore, "Different scores should produce different explanations")
        #expect(highScore.contains("working") || highScore.contains("helping"))
        #expect(lowScore.contains("quiet") || lowScore.contains("playing"))
    }

    // MARK: - Sound Type Mapping Tests

    @Test("Sound types map to correct topics", arguments: [
        (GeneratorType.ocean, ResearchTopic.sleepScience),
        (GeneratorType.river, ResearchTopic.sleepScience),
        (GeneratorType.heartbeat, ResearchTopic.wombSounds),
        (GeneratorType.shushing, ResearchTopic.fiveSs),
        (GeneratorType.womb, ResearchTopic.wombSounds)
    ])
    func soundTypeMapping(input: (GeneratorType, ResearchTopic)) {
        let (soundType, expectedTopic) = input
        let knowledge = ResearchKnowledgeBase.shared

        let explanation = knowledge.getExplanation(for: soundType)
        #expect(explanation != nil)

        if let exp = explanation {
            #expect(exp.topic == expectedTopic)
        }
    }
}

// MARK: - Research Citation Model Tests

@Suite("Research Citation Model")
struct ResearchCitationTests {

    @Test("Citation is identifiable")
    func citationIdentifiable() {
        let citation = ResearchCitation(
            title: "Test Study",
            authors: "Test Author",
            year: 2024,
            source: "Test Journal",
            summary: "Test summary",
            keyFindings: ["Finding 1"],
            topics: [.sleepScience]
        )

        #expect(citation.id != UUID())
        #expect(citation.title == "Test Study")
    }

    @Test("Research topics have raw values")
    func topicRawValues() {
        for topic in ResearchTopic.allCases {
            #expect(!topic.rawValue.isEmpty)
        }
    }
}
