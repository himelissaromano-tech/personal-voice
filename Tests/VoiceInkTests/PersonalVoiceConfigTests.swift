// Added by personal-voice (2026-10-15).
//
// The shipped import files are the product: these tests pin the privacy and
// safety properties of PersonalVoice/PersonalVoice-Settings.json and
// PersonalVoice/Technical-Dictionary.json.

import Foundation
import Testing

@testable import VoiceInk

enum PersonalVoiceFiles {
    static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // VoiceInkTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // repo root
        .appendingPathComponent("PersonalVoice")

    static let settingsURL = directory.appendingPathComponent("PersonalVoice-Settings.json")
    static let dictionaryURL = directory.appendingPathComponent("Technical-Dictionary.json")

    static func json(_ url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    static func settings() throws -> [String: Any] { try json(settingsURL) }
    static func modes() throws -> [[String: Any]] {
        try #require(try settings()["modeConfigs"] as? [[String: Any]])
    }
    static func prompts() throws -> [[String: Any]] {
        try #require(try settings()["customPrompts"] as? [[String: Any]])
    }
    static func replacements() throws -> [String: String] {
        try #require(try settings()["wordReplacements"] as? [String: String])
    }
    static func mode(named name: String) throws -> [String: Any] {
        try #require(try modes().first { $0["name"] as? String == name })
    }
}

struct PersonalVoiceLocalOnlyTests {
    /// Engines that run on this Mac. Cloud transcription models and paid AI providers are excluded.
    static let localTranscriptionModels: Set<String> = [
        "parakeet-tdt-0.6b-v3", "parakeet-tdt-0.6b-v2", "ggml-large-v3-turbo", "ggml-base.en", "ggml-small.en",
    ]
    static let localAIProviders: Set<String> = ["Ollama"]

    @Test
    func everyModeTranscribesLocally() throws {
        for mode in try PersonalVoiceFiles.modes() {
            let model = try #require(mode["selectedTranscriptionModelName"] as? String)
            #expect(Self.localTranscriptionModels.contains(model), "\(mode["name"] ?? "?") uses \(model)")
        }
    }

    @Test
    func everyAIStepRunsOnLocalhostOllama() throws {
        for mode in try PersonalVoiceFiles.modes() where mode["isAIEnhancementEnabled"] as? Bool == true {
            let provider = try #require(mode["selectedAIProvider"] as? String)
            #expect(Self.localAIProviders.contains(provider), "\(mode["name"] ?? "?") uses \(provider)")
            #expect(mode["selectedAIModel"] as? String != nil)
        }
    }

    @Test
    func noModeSendsContextOrRunsCommands() throws {
        for mode in try PersonalVoiceFiles.modes() {
            let name = mode["name"] as? String ?? "?"
            #expect(mode["useScreenCapture"] as? Bool == false, "\(name)")
            #expect(mode["useClipboardContext"] as? Bool == false, "\(name)")
            #expect(mode["useSelectedTextContext"] as? Bool == false, "\(name)")
            #expect(mode["outputMode"] as? String == "paste", "\(name) must paste, not respond or run a command")
            #expect(mode["customCommand"] == nil, "\(name)")
        }
    }

    @Test
    func noCloudModelsOrKeysAreShipped() throws {
        let settings = try PersonalVoiceFiles.settings()
        #expect(settings["customCloudModels"] == nil)
        let raw = try String(contentsOf: PersonalVoiceFiles.settingsURL, encoding: .utf8).lowercased()
        for forbidden in ["apikey", "api_key", "sk-", "https://api."] {
            #expect(!raw.contains(forbidden), "Found \(forbidden)")
        }
    }

    @Test
    func autoLearnIsOffBecauseItUsesAnAIProvider() throws {
        let general = try #require(try PersonalVoiceFiles.settings()["generalSettings"] as? [String: Any])
        #expect(general["isAutoLearnDictionaryEnabled"] as? Bool == false)
    }
}

struct PersonalVoiceNoAutoSubmitTests {
    @Test
    func finishAndSendKeyIsNone() throws {
        let general = try #require(try PersonalVoiceFiles.settings()["generalSettings"] as? [String: Any])
        #expect(general["finishAndSendKey"] as? String == "none")
    }

    @Test
    func promptsTellTheModelTheUserSendsManually() throws {
        for prompt in try PersonalVoiceFiles.prompts() {
            let text = try #require(prompt["promptText"] as? String)
            #expect(
                text.contains("themselves"),
                "\(prompt["title"] ?? "?") should state the speaker reviews and sends it themselves"
            )
        }
    }
}

struct PersonalVoiceModeTests {
    @Test
    func verbatimIsTheDefaultAndHasNoAIOrReformatting() throws {
        let verbatim = try PersonalVoiceFiles.mode(named: "Verbatim")
        #expect(verbatim["isDefault"] as? Bool == true)
        #expect(verbatim["isAIEnhancementEnabled"] as? Bool == false)
        #expect(verbatim["isTextFormattingEnabled"] as? Bool == false)
        #expect(verbatim["selectedPrompt"] == nil)
        #expect(try PersonalVoiceFiles.modes().filter { $0["isDefault"] as? Bool == true }.count == 1)
    }

    @Test
    func polishedPromptUsesThePolishedPrompt() throws {
        let mode = try PersonalVoiceFiles.mode(named: "Polished Prompt")
        let promptId = try #require(mode["selectedPrompt"] as? String)
        let prompt = try #require(try PersonalVoiceFiles.prompts().first { $0["id"] as? String == promptId })
        #expect(prompt["title"] as? String == "Polished Prompt")
        #expect(prompt["useSystemInstructions"] as? Bool == true, "must inherit VoiceInk's preserve-meaning rules")
    }

    @Test(arguments: [
        ("ChatGPT", ["com.openai.chat"], ["chatgpt.com"], true),
        ("Claude Code", ["com.apple.Terminal", "com.googlecode.iterm2", "com.anthropic.claudefordesktop"],
         ["claude.ai/code"], true),
        ("Gmail", [], ["mail.google.com"], true),
        ("Messages", ["com.apple.MobileSMS"], [], false),
    ])
    func appProfilesTriggerOnTheirApps(_ expected: (String, [String], [String], Bool)) throws {
        let mode = try PersonalVoiceFiles.mode(named: expected.0)
        let apps = (mode["appConfigs"] as? [[String: Any]] ?? []).compactMap { $0["bundleIdentifier"] as? String }
        let urls = (mode["urlConfigs"] as? [[String: Any]] ?? []).compactMap { $0["url"] as? String }
        for bundleId in expected.1 { #expect(apps.contains(bundleId), "\(expected.0) missing \(bundleId)") }
        for address in expected.2 { #expect(urls.contains(address), "\(expected.0) missing \(address)") }
        #expect(mode["isAIEnhancementEnabled"] as? Bool == expected.3)
    }

    @Test
    func noAppOrSiteIsClaimedByTwoProfiles() throws {
        var seen: [String: String] = [:]
        for mode in try PersonalVoiceFiles.modes() {
            let name = mode["name"] as? String ?? "?"
            let apps = (mode["appConfigs"] as? [[String: Any]] ?? []).compactMap { $0["bundleIdentifier"] as? String }
            let urls = (mode["urlConfigs"] as? [[String: Any]] ?? []).compactMap { $0["url"] as? String }
            for key in apps + urls {
                #expect(seen[key] == nil, "\(key) is in both \(seen[key] ?? "") and \(name)")
                seen[key] = name
            }
        }
    }

    @Test
    func everyPolishedPromptCarriesTheMeaningRules() throws {
        for prompt in try PersonalVoiceFiles.prompts() {
            let text = try #require(prompt["promptText"] as? String).lowercased()
            let title = prompt["title"] as? String ?? "?"
            #expect(text.contains("negation"), "\(title)")
            #expect(text.contains("never add") || text.contains("do not add"), "\(title)")
        }
    }

    @Test
    func promptExamplesPassTheMeaningGuard() throws {
        // The few-shot examples teach the model; they must model guard-safe behavior.
        for prompt in try PersonalVoiceFiles.prompts() {
            let text = try #require(prompt["promptText"] as? String)
            for (input, output) in examples(in: text) {
                let result = MeaningGuard.check(original: input, polished: output)
                #expect(result.isPreserved, "\(prompt["title"] ?? "?"): \(result.violations)")
            }
        }
    }

    private func examples(in prompt: String) -> [(String, String)] {
        guard let start = prompt.range(of: "<EXAMPLES>"), let end = prompt.range(of: "</EXAMPLES>") else { return [] }
        let body = prompt[start.upperBound..<end.lowerBound]
        return body.components(separatedBy: "Input:").dropFirst().compactMap { chunk in
            let parts = chunk.components(separatedBy: "Output:")
            guard parts.count == 2 else { return nil }
            return (
                parts[0].trimmingCharacters(in: .whitespacesAndNewlines),
                parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }
}

struct TechnicalDictionaryTests {
    /// Ordinary English phrases that must never be rewritten.
    static let ordinaryPhrases: Set<String> = [
        "read me", "home brew", "pull request", "no code", "get up", "co pilot", "cloud storage", "swift code",
    ]

    /// Sources allowed to differ from their replacement by more than spacing/casing. Mirrors
    /// PHONETIC_ALIASES in PersonalVoice/generate_config.py; each needs a stated reason there.
    static let phoneticAliases: Set<String> = [
        "get hub", "claud code", "clawed code", "cloud code", "node js", "dot env",
    ]

    @Test
    func replacementsOnlyFixSpacingOrCasingUnlessApproved() throws {
        for (source, replacement) in try PersonalVoiceFiles.replacements() {
            let isSpellingFix = squashed(source) == squashed(replacement)
            #expect(isSpellingFix || Self.phoneticAliases.contains(source), "\(source) -> \(replacement)")
        }
    }

    @Test
    func replacementsNeverTouchNegationsOrNumbers() throws {
        for (source, replacement) in try PersonalVoiceFiles.replacements() {
            for side in [source, replacement] {
                #expect(MeaningGuard.negationCount(in: side) == 0, "\(side)")
                let hasDigit = side.contains { $0.isNumber }
                #expect(!hasDigit, "\(side)")
            }
        }
    }

    @Test
    func replacementsAreMultiWordAndNotOrdinaryEnglish() throws {
        for source in try PersonalVoiceFiles.replacements().keys {
            let variants = WordReplacementVariants.parse(source)
            #expect(!variants.isEmpty)
            for variant in variants {
                #expect(variant.contains(" "), "Single-word source \(variant) could match normal speech")
                #expect(!Self.ordinaryPhrases.contains(variant.lowercased()), "\(variant)")
            }
        }
    }

    @Test
    func replacementsAreAcyclic() throws {
        let records = try PersonalVoiceFiles.replacements().map { (originalText: $0.key, replacementText: $0.value) }
        var detector = WordReplacementVariants.CycleDetector(records: [])
        for record in records {
            let inserted = detector.insertIfAcyclic(source: record.originalText, destination: record.replacementText)
            #expect(inserted, "\(record.originalText) -> \(record.replacementText) creates a cycle")
        }
    }

    @Test
    func corpusContainsNoReplacementSources() throws {
        // So the dictionary cannot rewrite any corpus instruction.
        let sources = try PersonalVoiceFiles.replacements().keys
        for instruction in TechnicalCorpus.instructions {
            for source in sources {
                #expect(instruction.range(of: "\\b\(source)\\b", options: [.regularExpression, .caseInsensitive]) == nil,
                        "\(source) appears in: \(instruction)")
            }
        }
    }

    @Test
    func standaloneDictionaryMatchesSettingsFile() throws {
        let dictionary = try PersonalVoiceFiles.json(PersonalVoiceFiles.dictionaryURL)
        #expect(dictionary["format"] as? String == "voiceink.dictionary")
        let vocabulary = (dictionary["vocabulary"] as? [[String: Any]] ?? []).compactMap { $0["term"] as? String }
        let settingsVocabulary = (try PersonalVoiceFiles.settings()["vocabularyWords"] as? [[String: Any]] ?? [])
            .compactMap { $0["word"] as? String }
        #expect(vocabulary == settingsVocabulary)

        var replacements: [String: String] = [:]
        for entry in dictionary["replacements"] as? [[String: Any]] ?? [] {
            for source in entry["sources"] as? [String] ?? [] {
                replacements[source] = entry["replacement"] as? String
            }
        }
        #expect(replacements == (try PersonalVoiceFiles.replacements()))
    }

    private func squashed(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter }
    }
}
