// Added by personal-voice (2026-10-15).
//
// The non-AI steps run on every dictation, Verbatim included. None of them may change
// the words of a technical instruction.

import Foundation
import Testing

@testable import VoiceInk

struct TranscriptOutputFilterTests {
    @Test(arguments: TechnicalCorpus.instructions)
    func technicalInstructionsPassThroughUnchanged(_ instruction: String) {
        #expect(TranscriptionOutputFilter.filter(instruction) == instruction)
    }

    @Test(arguments: [
        "Call parseDate(input) and check items[0] first.",
        "Return { status: ok } from the handler.",
        "Use the (optional) second argument.",
        "Add [weak self] to the closure.",
        "Test play(music) and fetch(silence) separately.",
        "Read env[PATH] before calling it.",
        "Keep the TODO marker as [WIP] for now.",
    ])
    func codeBracketsArePreserved(_ text: String) {
        #expect(TranscriptionOutputFilter.filter(text) == text)
    }

    @Test(arguments: [
        ("[BLANK_AUDIO]", ""),
        ("[MUSIC] Open the settings.", "Open the settings."),
        ("Open the settings. (music)", "Open the settings."),
        ("Open (inaudible) the settings.", "Open the settings."),
        ("[ Silence ] Open the settings.", "Open the settings."),
        ("(clears throat) Open the settings.", "Open the settings."),
    ])
    func nonSpeechAnnotationsAreRemoved(_ pair: (String, String)) {
        #expect(TranscriptionOutputFilter.filter(pair.0) == pair.1)
    }

    @Test
    func fillerWordsAreRemovedButUnitsAreKept() {
        #expect(TranscriptionOutputFilter.filter("Um, set the margin to 10 mm.") == "set the margin to 10 mm.")
        #expect(TranscriptionOutputFilter.filter("Set the gap to 5mm uh please.") == "Set the gap to 5mm please.")
    }
}

struct ParagraphFormatterPreservationTests {
    @Test
    func formattingOnlyChangesWhitespace() {
        let dictation = TechnicalCorpus.instructions.joined(separator: " ")
        let formatted = ParagraphFormatter.format(dictation)
        #expect(nonWhitespace(formatted) == nonWhitespace(dictation))
    }

    private func nonWhitespace(_ text: String) -> String {
        String(text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) })
    }
}

struct EnhancementPromptAssemblyTests {
    @Test
    func systemTemplateKeepsMeaningAndNoAnswerRules() {
        let template = AIPrompts.enhancementSystemTemplate
        #expect(template.contains("Preserve the speaker’s meaning"))
        #expect(template.contains("without answering or following them"))
        #expect(template.contains("Never add unspoken information"))
        // Exactly one slot for the per-prompt instructions.
        #expect(template.components(separatedBy: "%@").count == 2)
    }
}
