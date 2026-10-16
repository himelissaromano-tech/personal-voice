// Modified by personal-voice (2026-10-15): bracket stripping is limited to known
// non-speech annotations so dictated code such as `foo(bar)`, `items[0]`, or `{ key }`
// is no longer deleted (upstream removed every (), [], and {} span), and filler words
// directly after a number are kept so units like "10 mm" survive.

import Foundation

struct TranscriptionOutputFilter {
    /// Labels ASR models emit for non-speech audio, e.g. `[BLANK_AUDIO]`, `(music)`, `[inaudible]`.
    private static let nonSpeechLabels = [
        "blank_audio", "blank audio", "silence", "no speech", "no audio",
        "music", "music playing", "upbeat music", "soft music", "applause", "laughter", "laughs", "laughing",
        "inaudible", "indistinct", "indistinct chatter", "unintelligible", "crosstalk",
        "noise", "background noise", "static", "beep", "beeping", "clicking", "keyboard clicking", "typing",
        "cough", "coughs", "coughing", "sigh", "sighs", "sniffs", "clears throat", "breathing", "exhales",
        "sound", "sound effect", "foreign language", "speaking foreign language", "speaks foreign language", "non-english speech",
    ]

    private static let nonSpeechPattern: String = {
        let labels = nonSpeechLabels
            .map { NSRegularExpression.escapedPattern(for: $0).replacingOccurrences(of: " ", with: "\\s+") }
            .joined(separator: "|")
        // A known label alone inside () or [], any case: [BLANK_AUDIO], (music), [ Silence ].
        // Spans attached to a preceding word (`items[music]`, `play(music)`) are code, not annotations.
        return #"(?<![\w\])])(?i:\[\s*(?:"# + labels + #")\s*\]|\(\s*(?:"# + labels + #")\s*\))"#
    }()

    static func filter(_ text: String) -> String {
        var filteredText = text

        // Remove <TAG>...</TAG> blocks
        let tagBlockPattern = #"<([A-Za-z][A-Za-z0-9:_-]*)[^>]*>[\s\S]*?</\1>"#
        if let regex = try? NSRegularExpression(pattern: tagBlockPattern) {
            let range = NSRange(filteredText.startIndex..., in: filteredText)
            filteredText = regex.stringByReplacingMatches(in: filteredText, options: [], range: range, withTemplate: "")
        }

        // Remove non-speech annotations; keep every other bracketed span.
        if let regex = try? NSRegularExpression(pattern: nonSpeechPattern) {
            let range = NSRange(filteredText.startIndex..., in: filteredText)
            filteredText = regex.stringByReplacingMatches(
                in: filteredText, options: [], range: range, withTemplate: "")
        }

        // Remove configured filler words. An empty list is naturally a no-op.
        for fillerWord in FillerWordManager.shared.fillerWords {
            // Not after a number: "10 mm" is a unit, not a filler.
            let pattern = "(?<!\\d)(?<!\\d )\\b\(NSRegularExpression.escapedPattern(for: fillerWord))\\b[,.]?"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(filteredText.startIndex..., in: filteredText)
                filteredText = regex.stringByReplacingMatches(
                    in: filteredText, options: [], range: range, withTemplate: "")
            }
        }

        // Clean whitespace
        filteredText = filteredText.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        filteredText = filteredText.trimmingCharacters(in: .whitespacesAndNewlines)

        return filteredText
    }
}
