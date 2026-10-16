// swift-tools-version:5.10
// Added by personal-voice (2026-10-15).
//
// Builds the app's pure text-processing files into a module that is also named
// `VoiceInk`, so the regression tests in Tests/VoiceInkTests run with `swift test`
// (Command Line Tools only, no Xcode) and unchanged inside the Xcode VoiceInkTests target.
// The app itself is still built only from VoiceInk.xcodeproj.

import PackageDescription

let package = Package(
    name: "PersonalVoiceChecks",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "VoiceInk",
            path: "VoiceInk",
            sources: [
                "Core/Enhancement/AIPrompts.swift",
                "Core/Enhancement/AIEnhancementOutputFilter.swift",
                "Core/Enhancement/MeaningGuard.swift",
                "Features/Enhancement/State/FillerWordManager.swift",
                "Features/Recording/Processing/TranscriptionOutputFilter.swift",
                "Features/Dictionary/Workflows/WordReplacementVariants.swift",
                "Infrastructure/TextProcessing/ParagraphFormatter.swift",
            ]
        ),
        .testTarget(
            name: "VoiceInkTests",
            dependencies: ["VoiceInk"],
            path: "Tests/VoiceInkTests"
        ),
    ]
)
