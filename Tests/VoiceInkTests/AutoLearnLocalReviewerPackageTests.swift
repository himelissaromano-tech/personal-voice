import Foundation
import NaturalLanguage
import Testing

@testable import VoiceInk

@MainActor
struct AutoLearnLocalReviewerPackageTests {
    private func candidate(_ original: String, _ corrected: String, language: String? = "en")
        -> AutoLearnReviewCandidate
    {
        .init(candidateID: UUID(), originalText: original, correctedText: corrected, languageCode: language)
    }

    @Test
    func confirmedSpellingCorrectionSavesOnlyTheEdit() async throws {
        let analyzer = PackageFixtureAnalyzer(
            misspelled: ["sentance"],
            suggestions: ["sentance": ["sentence"]]
        )
        let result = try await AutoLearnLocalReviewer(analyzer: analyzer).review(
            [candidate("The sentance is clear", "The sentence is clear")],
            knownTerms: []
        )

        #expect(result.approvalDecisions.isEmpty)
        #expect(result.reviewDecisions.first?.learningAction == .addReplacementOnly)
        #expect(result.reviewDecisions.first?.incorrectTextToReplace == "sentance")
        #expect(result.reviewDecisions.first?.correctedVocabularyTerm == "sentence")
    }

    @Test
    func grammarAndMeaningChangesAreRejected() async throws {
        let reviewer = AutoLearnLocalReviewer(analyzer: PackageFixtureAnalyzer())
        for (original, corrected) in [
            ("Send it form here", "Send it from here"),
            ("I walk home", "I walked home"),
            ("It costs thirty dollars", "It costs forty dollars"),
            ("Meeting is on June 12", "Meeting is on June 13"),
        ] {
            let result = try await reviewer.review([candidate(original, corrected)], knownTerms: [])
            #expect(result.reviewDecisions.first?.learningAction == .rejectCorrection)
            #expect(result.approvalDecisions.isEmpty)
        }
    }

    @Test
    func recognizedNamesRequireExplicitApproval() async throws {
        let analyzer = PackageFixtureAnalyzer(
            misspelled: ["Jhn"],
            entities: ["John Smith": .personalName]
        )
        let result = try await AutoLearnLocalReviewer(analyzer: analyzer).review(
            [candidate("Please email Jhn Smith tomorrow", "Please email John Smith tomorrow")],
            knownTerms: []
        )

        #expect(result.reviewDecisions.isEmpty)
        #expect(result.approvalDecisions.count == 1)
        #expect(result.approvalDecisions.first?.incorrectTextToReplace == "Jhn Smith")
        #expect(result.approvalDecisions.first?.correctedVocabularyTerm == "John Smith")
    }

    @Test
    func unknownTechnicalTermNeedsAnApprovedDestination() async throws {
        let reviewer = AutoLearnLocalReviewer(
            analyzer: PackageFixtureAnalyzer(misspelled: ["Lumora", "Lumorra"])
        )
        let edit = candidate("We use Lumorra daily", "We use Lumora daily")

        let unknown = try await reviewer.review([edit], knownTerms: [])
        let approved = try await reviewer.review([edit], knownTerms: ["Lumora"])

        #expect(unknown.reviewDecisions.first?.learningAction == .rejectCorrection)
        #expect(approved.reviewDecisions.first?.learningAction == .addReplacementOnly)
    }

    @Test
    func unavailableLanguageDoesNotGuess() async throws {
        let analyzer = PackageFixtureAnalyzer(
            misspelled: ["sentance"],
            suggestions: ["sentance": ["sentence"]]
        )
        let result = try await AutoLearnLocalReviewer(analyzer: analyzer).review(
            [candidate("The sentance is clear", "The sentence is clear", language: "ne")],
            knownTerms: []
        )

        #expect(result.reviewDecisions.first?.learningAction == .rejectCorrection)
    }
}

@MainActor
private final class PackageFixtureAnalyzer: AutoLearnLocalTextAnalyzing {
    private let misspelled: Set<String>
    private let suggestions: [String: [String]]
    private let entities: [String: NLTag]

    init(
        misspelled: Set<String> = [],
        suggestions: [String: [String]] = [:],
        entities: [String: NLTag] = [:]
    ) {
        self.misspelled = misspelled
        self.suggestions = suggestions
        self.entities = entities
    }

    func analyze(_ text: String, languageHint: String?) -> AutoLearnLocalTextAnalysis? {
        guard languageHint == "en" else { return nil }
        var tokens: [AutoLearnLocalTextAnalysis.Token] = []
        var search = text.startIndex..<text.endIndex
        for word in text.split(separator: " ").map(String.init) {
            guard let range = text.range(of: word, range: search) else { continue }
            tokens.append(
                .init(
                    range: NSRange(range, in: text),
                    text: word,
                    lexicalClass: .noun,
                    lemma: word == "walked" ? "walk" : word.lowercased()
                )
            )
            search = range.upperBound..<text.endIndex
        }
        let names = entities.compactMap { term, type -> AutoLearnLocalTextAnalysis.Entity? in
            guard let range = text.range(of: term) else { return nil }
            return .init(range: NSRange(range, in: text), type: type)
        }
        return .init(language: .english, tokens: tokens, entities: names)
    }

    func spelling(for text: String, language: NLLanguage) -> AutoLearnSpellingEvidence? {
        .init(isMisspelled: misspelled.contains(text), suggestions: suggestions[text] ?? [])
    }
}
