// Added by personal-voice (2026-10-15).
//
// Opt-in evaluation of the real Polished Prompt against your local Ollama model.
// Skipped unless PERSONAL_VOICE_LIVE_OLLAMA=1. Talks only to localhost.
//
//   PERSONAL_VOICE_LIVE_OLLAMA=1 swift test --filter LiveOllamaEval
//   PERSONAL_VOICE_LIVE_OLLAMA=1 PERSONAL_VOICE_OLLAMA_MODEL=qwen2.5:7b-instruct swift test --filter LiveOllamaEval
//
// Each corpus instruction is polished exactly the way the app builds the request
// (VoiceInk system template + prompt text, transcript in <TRANSCRIPT>, same endpoint and options). Any output
// the MeaningGuard rejects is reported; in the app that dictation would fall back to
// the verbatim transcript, so a failure here means "the model needs a better prompt
// or a bigger model", not "wrong text was pasted".

import Foundation
import Testing

@testable import VoiceInk

struct LiveOllamaEvalTests {
    static let isEnabled = ProcessInfo.processInfo.environment["PERSONAL_VOICE_LIVE_OLLAMA"] == "1"

    @Test(.enabled(if: LiveOllamaEvalTests.isEnabled), arguments: ["Polished Prompt", "Polished Prompt (Claude Code)"])
    func polishedPromptKeepsTechnicalMeaning(_ promptTitle: String) async throws {
        let prompt = try #require(try PersonalVoiceFiles.prompts().first { $0["title"] as? String == promptTitle })
        let promptText = try #require(prompt["promptText"] as? String)
        let systemPrompt = String(format: AIPrompts.enhancementSystemTemplate, promptText)
        let mode = try PersonalVoiceFiles.mode(named: "Polished Prompt")
        let model =
            ProcessInfo.processInfo.environment["PERSONAL_VOICE_OLLAMA_MODEL"]
            ?? (mode["selectedAIModel"] as? String ?? "qwen2.5:3b-instruct")

        var rejected = 0
        for instruction in TechnicalCorpus.instructions {
            let polished = try await Self.chat(model: model, system: systemPrompt, transcript: instruction)
            let result = MeaningGuard.check(original: instruction, polished: polished)
            if !result.isPreserved {
                rejected += 1
                Issue.record("\(model) changed meaning\n  in:  \(instruction)\n  out: \(polished)\n  why: \(result.violations)")
            }
        }
        print("[\(promptTitle)] \(model): \(TechnicalCorpus.instructions.count - rejected)/\(TechnicalCorpus.instructions.count) kept meaning")
    }

    static func chat(model: String, system: String, transcript: String) async throws -> String {
        // Same request shape as OllamaService: /api/generate, temperature 0.3, thinking off.
        var request = URLRequest(url: URL(string: "http://localhost:11434/api/generate")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "stream": false,
            "think": false,
            "options": ["temperature": 0.3],
            "system": system,
            "prompt": "\n<TRANSCRIPT>\n\(transcript)\n</TRANSCRIPT>",
        ])
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let content = try #require(json["response"] as? String, "Ollama response: \(json)")
        return AIEnhancementOutputFilter.filter(content)
    }
}
