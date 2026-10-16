// Added by personal-voice (2026-10-15).
//
// Runs only inside the Xcode VoiceInkTests target (hosted by the app), where the real
// BackupFile/DictionaryArchive decoders and the SwiftData-backed WordReplacementService
// are available. `swift test` skips this file.

#if !SWIFT_PACKAGE
    import Foundation
    import SwiftData
    import Testing

    @testable import VoiceInk

    @MainActor
    struct AppIntegrationTests {
        @Test
        func settingsFileDecodesWithTheAppBackupFormat() throws {
            let data = try Data(contentsOf: PersonalVoiceFiles.settingsURL)
            let backup = try JSONDecoder().decode(BackupFile.self, from: data)

            #expect(backup.modeConfigs.map(\.name) == [
                "Verbatim", "Polished Prompt", "ChatGPT", "Claude Code", "Gmail", "Messages",
            ])
            let promptIds = Set(backup.customPrompts.map(\.id.uuidString))
            for mode in backup.modeConfigs where mode.isAIEnhancementEnabled {
                #expect(promptIds.contains(mode.selectedPrompt ?? ""), "\(mode.name) points at a missing prompt")
                #expect(mode.selectedAIProvider == AIProvider.ollama.rawValue)
            }
            #expect(backup.generalSettings?.finishAndSendKey == FinishAndSendKey.none.rawValue)
            #expect(backup.modeConfigs.allSatisfy { $0.outputMode == .paste })
        }

        @Test
        func ollamaDefaultsToLocalhost() {
            let key = "ollamaBaseURL"
            let saved = UserDefaults.standard.string(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
            defer { UserDefaults.standard.set(saved, forKey: key) }
            #expect(AIProvider.ollama.baseURL.hasPrefix("http://localhost"))
        }

        @Test
        func dictionaryFileDecodesWithTheAppArchiveFormat() throws {
            let data = try Data(contentsOf: PersonalVoiceFiles.dictionaryURL)
            let archive = try DictionaryImportExportService.decodeArchiveData(data).archive
            #expect(!archive.vocabulary.isEmpty)
            #expect(!archive.replacements.isEmpty)
        }

        @Test
        func shippedReplacementsLeaveTechnicalInstructionsIntact() throws {
            let context = try replacementContext()
            for instruction in TechnicalCorpus.instructions {
                let output = WordReplacementService.shared.applyReplacements(to: instruction, using: context)
                #expect(output == instruction)
            }
        }

        @Test(arguments: [
            ("push it to git hub and open chat gpt", "push it to GitHub and open ChatGPT"),
            ("ask cloud code to fix the x code build", "ask Claude Code to fix the Xcode build"),
            ("don't commit the dot env file", "don't commit the .env file"),
        ])
        func shippedReplacementsFixKnownMishearings(_ pair: (String, String)) throws {
            let context = try replacementContext()
            let output = WordReplacementService.shared.applyReplacements(to: pair.0, using: context)
            #expect(output == pair.1)
            #expect(MeaningGuard.negationCount(in: output) == MeaningGuard.negationCount(in: pair.0))
        }

        private func replacementContext() throws -> ModelContext {
            let container = try ModelContainer(
                for: WordReplacement.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let context = ModelContext(container)
            for (source, replacement) in try PersonalVoiceFiles.replacements() {
                context.insert(WordReplacement(originalText: source, replacementText: replacement))
            }
            try context.save()
            return context
        }
    }
#endif
