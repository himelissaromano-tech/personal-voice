// Added by personal-voice (2026-10-15).
//
// MeaningGuard is the last line of defense for Polished Prompt: if AI output drops a
// protected token or a negation, the pipeline pastes the verbatim transcript instead.
// These tests mutate every corpus instruction in meaning-changing ways and require
// the guard to catch each one, while accepting harmless polish.

import Foundation
import Testing

@testable import VoiceInk

struct MeaningGuardTests {
    @Test(arguments: TechnicalCorpus.instructions)
    func unchangedTextIsPreserved(_ instruction: String) {
        let result = MeaningGuard.check(original: instruction, polished: instruction)
        #expect(result.isPreserved, "\(result.violations)")
    }

    @Test(arguments: TechnicalCorpus.instructions)
    func droppingAnyNegationIsRejected(_ instruction: String) {
        let words = instruction.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        for (index, word) in words.enumerated() where MeaningGuard.negationCount(in: word) > 0 {
            var mutated = words
            mutated.remove(at: index)
            let polished = mutated.joined(separator: " ")
            #expect(
                !MeaningGuard.check(original: instruction, polished: polished).isPreserved,
                "Dropping \"\(word)\" was accepted: \(polished)"
            )
        }
    }

    @Test(arguments: TechnicalCorpus.instructions)
    func droppingOrAlteringAnyProtectedTokenIsRejected(_ instruction: String) {
        let tokens = MeaningGuard.protectedTokens(in: instruction)
        for token in tokens {
            let alterations = [
                "",  // dropped
                token.lowercased() == token ? token.uppercased() : token.lowercased(),  // re-cased
                token.replacingOccurrences(of: "_", with: " "),  // de-identified
                incrementingDigits(in: token),  // changed number
            ]
            for replacement in Set(alterations) where replacement != token {
                let polished = instruction.replacingOccurrences(of: token, with: replacement)
                guard polished != instruction, !otherTokenStillCovers(token, in: polished) else { continue }
                #expect(
                    !MeaningGuard.check(original: instruction, polished: polished).isPreserved,
                    "Changing \"\(token)\" to \"\(replacement)\" was accepted: \(polished)"
                )
            }
        }
    }

    @Test
    func corpusContainsProtectedDetails() {
        // Guards against the corpus silently losing its technical content.
        let withTokens = TechnicalCorpus.instructions.filter { !MeaningGuard.protectedTokens(in: $0).isEmpty }
        let withNegations = TechnicalCorpus.instructions.filter { MeaningGuard.negationCount(in: $0) > 0 }
        #expect(withTokens.count >= 20)
        #expect(withNegations.count >= 12)
    }

    @Test(arguments: [
        // Punctuation, capitalization, filler removal, list formatting, contractions.
        ("um so don't push to main just open a PR",
         "Don't push to main. Just open a PR."),
        ("run npm test and only commit if all 42 tests pass",
         "1. Run npm test.\n2. Only commit if all 42 tests pass."),
        ("in config.py set MAX_RETRIES to 5 do not hardcode it",
         "In config.py, set MAX_RETRIES to 5. Do not hardcode it."),
        ("don't use print use Logger",
         "Do not use print; use Logger."),
        ("set the timeout to thirty seconds",
         "Set the timeout to 30 seconds."),
        ("check http://localhost:11434/api/tags",
         "Check http://localhost:11434/api/tags."),
        ("fix the crash in items[0]",
         "Fix the crash in `items[0]`."),
    ])
    func harmlessPolishIsAccepted(_ pair: (String, String)) {
        let result = MeaningGuard.check(original: pair.0, polished: pair.1)
        #expect(result.isPreserved, "\(result.violations)")
    }

    @Test(arguments: [
        // Real failure shapes seen from small local models.
        ("don't force push", "Force push."),
        ("never delete the migrations folder", "Delete the migrations folder carefully."),
        ("set retries to 3 not 5", "Set retries to 5."),
        ("rename user_id to account_id", "Rename user ID to account ID."),
        ("run git rebase -i HEAD~3", "Run an interactive rebase of the last three commits."),
        ("edit src/api/client.ts", "Edit the API client file."),
        ("call fetchToken", "Call fetch token."),
        ("use the --dry-run flag", "Use the dry run flag."),
        ("bump 2.21 to 2.22", "Bump the version to 2.22."),
    ])
    func meaningChangesAreRejected(_ pair: (String, String)) {
        #expect(!MeaningGuard.check(original: pair.0, polished: pair.1).isPreserved)
    }

    @Test
    func ordinaryProseHasNoProtectedTokens() {
        let prose = "Hi Maya, thanks for the update. I think Friday works for everyone, see you then."
        #expect(MeaningGuard.protectedTokens(in: prose).isEmpty)
        #expect(MeaningGuard.protectedTokens(in: "e.g. this, i.e. that.").isEmpty)
    }

    @Test
    func tokenizerKeepsCodeShapes() {
        let tokens = MeaningGuard.protectedTokens(in: "Call parseDate(input) on items[0], then read `a b`.")
        #expect(tokens.contains("parseDate(input)"))
        #expect(tokens.contains("items[0]"))
        #expect(tokens.contains("a b"))
    }

    // MARK: - Helpers

    private func incrementingDigits(in token: String) -> String {
        String(token.map { character in
            guard let digit = character.wholeNumberValue else { return character }
            return Character(String((digit + 1) % 10))
        })
    }

    /// A shorter protected token can legitimately still be present after mutating a longer one
    /// (e.g. ".env" inside ".env.example"); those cases prove nothing either way.
    private func otherTokenStillCovers(_ token: String, in polished: String) -> Bool {
        polished.contains(token)
    }
}
