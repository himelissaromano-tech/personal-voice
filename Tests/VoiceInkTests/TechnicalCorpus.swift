// Added by personal-voice (2026-10-15).
//
// Dictated technical instructions whose meaning must survive every processing step.
// Written the way Parakeet/Whisper transcribe speech: mostly lowercase, light punctuation,
// identifiers already tokenized. Add a line here whenever a real dictation goes wrong.

enum TechnicalCorpus {
    static let instructions: [String] = [
        "Don't push to main, open a pull request against the develop branch instead.",
        "Run npm test and only commit if all 42 tests pass.",
        "Never delete the migrations folder. Rename user_id to account_id in schema.sql only.",
        "Set the timeout to 30 seconds and the retry count to 3, not 5.",
        "In src/api/client.ts do not change the public exports, just make fetchToken retry on HTTP 503.",
        "Install with brew install ollama then run ollama pull qwen2.5:3b-instruct.",
        "Use the --dry-run flag first and don't pass --force unless the dry run is clean.",
        "Add MAX_RETRIES = 5 to config.py and read it from the environment variable PV_MAX_RETRIES.",
        "The bug is in items[0] when the array is empty, call guard items.count > 0 before indexing.",
        "Write a function parseDate(input) that returns nil instead of throwing.",
        "Bump the version from 2.21 to 2.22 in the Xcode project but don't touch the build number.",
        "Open http://localhost:11434/api/tags and check that the model is listed.",
        "Copy .env.example to .env and never commit the .env file.",
        "Pin swift-tools-version to 5.10 and keep the macOS deployment target at 15.0.",
        "Only refactor the ModeManager class, don't change ModeConfig or the JSON keys.",
        "Use git rebase -i HEAD~3 to squash the last three commits, but do not force push.",
        "Limit the query to at most 100 rows and sort by created_at descending.",
        "The padding should be 16 px on mobile and 24 px on desktop.",
        "Reply to ~/Documents/notes.md with the summary, not the full transcript.",
        "Make the test fail if the output is longer than 280 characters.",
        "Can you explain why useEffect runs twice in React 18 strict mode? Don't suggest removing StrictMode.",
        "Change the cron schedule to 0 9 * * 1-5 so it runs at 9 AM on weekdays only.",
        "Wrap the call in a do catch block and log the error with Logger, don't use print.",
        "Delete only the files in /tmp/build that are older than 7 days.",
        "Rename the branch to fix/meaning-guard and set upstream to origin.",
    ]
}
