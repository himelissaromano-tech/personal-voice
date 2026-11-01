enum AutoLearnProviderPolicy {
    static func isSupported(_ provider: AIProvider) -> Bool {
        provider.supportsEnhancement
            && provider != .voiceInkRefine
    }
}
