# personal-voice: attribution and modifications

personal-voice is a modified version of **VoiceInk** by Prakash Joshi (Pax),
https://github.com/Beingpax/VoiceInk, forked at upstream commit
`6a14368a2285acfdf79045a9feaf1b625e9bc397` on 2026-10-15.

VoiceInk and this fork are licensed under the **GNU General Public License v3.0**.
The upstream `LICENSE` file is kept unchanged; the complete license text is in
[`COPYING`](COPYING). All upstream copyright notices, credits, and the
acknowledgments in [`README.md`](README.md) are preserved. VoiceInk is a
trademark of its author; this fork is a personal build and is not affiliated
with or endorsed by the VoiceInk project.

## Modifications (GPL-3.0 section 5a)

| Date | File | Change |
|---|---|---|
| 2026-10-15 | `VoiceInk/Features/Recording/Processing/TranscriptionOutputFilter.swift` | Only strips known non-speech labels such as `[BLANK_AUDIO]` and `(music)`. Upstream deleted every `()`, `[]` and `{}` span, which erased dictated code like `items[0]`. Filler words right after a number (like `10 mm`) are kept. |
| 2026-10-15 | `VoiceInk/Core/Enhancement/MeaningGuard.swift` (new) | A fixed-rule check that AI-polished text kept every protected technical token and negation. |
| 2026-10-15 | `VoiceInk/Features/Recording/Workflows/TranscriptionPipeline.swift` | If polished text fails `MeaningGuard`, the verbatim transcript is pasted instead and a warning is shown. |
| 2026-10-15 | `PersonalVoice/` (new) | Importable settings: the Verbatim and Polished Prompt modes, the ChatGPT, Claude Code, Gmail and Messages profiles, and the technical dictionary. |
| 2026-10-15 | `Tests/VoiceInkTests/`, `Package.swift` (new) | Regression tests that check technical instructions keep their meaning, plus a SwiftPM harness so they run without Xcode. |
| 2026-10-15 | `.github/workflows/personal-voice-checks.yml` (new) | CI for the tests above. |
| 2026-10-15 | `README.md`, `PERSONAL_VOICE.md`, `NOTICE.md`, `COPYING` | Fork notice, setup guide, attribution, full license text. |

Everything else is upstream VoiceInk, unchanged.
