# personal-voice: setup and testing on a Mac

personal-voice is VoiceInk set up for two dictation modes plus four app profiles.
Transcription runs on your Mac, polishing runs through Ollama on localhost, and
nothing presses Return for you. See [NOTICE.md](NOTICE.md) for what changed from
upstream VoiceInk.

## What you get

| Mode / profile | Turns on when | What it does |
|---|---|---|
| **Verbatim** (default) | Any app with no profile, or its shortcut | Parakeet transcript with dictionary fixes only. No AI, no reformatting. |
| **Polished Prompt** | Its shortcut | Cleans and structures your dictation into a prompt using Ollama on localhost. |
| **ChatGPT** | ChatGPT app, chatgpt.com, chat.openai.com | Polished Prompt. |
| **Claude Code** | Terminal, iTerm2, Ghostty, Warp, Claude desktop app, claude.ai/code | Polished Prompt (Claude Code variant: plain text, keeps `/commands` and `@files`). |
| **Gmail** | mail.google.com | Polished Email: keeps names, dates, amounts and negations; adds no subject or sign-off. |
| **Messages** | Messages app | Verbatim. |

A mode shortcut always wins over the app profile. For example, pressing the
Verbatim shortcut inside ChatGPT gives you the raw transcript.

**Safety net:** if polished text loses a protected token (a number, path, flag,
`code_identifier`, URL, or acronym) or loses a "not / never / don't", personal-voice
pastes the verbatim transcript instead and shows *"Polished text changed a
technical detail."* The polished version stays in History if you want it.

## What already existed vs. what was added

| Need | Upstream VoiceInk | Done here |
|---|---|---|
| Local transcription | Yes (Parakeet, Whisper) | Every mode pinned to Parakeet V3 |
| Local AI polish, free | Yes (Ollama; VoiceInk Refine needs 16 GB RAM and ignores custom prompts) | Ollama + 3 custom prompts |
| App-specific profiles | Yes (Modes with app/URL triggers) | 6 modes, configuration only |
| Technical dictionary | Yes (vocabulary + replacements) | 43 terms, 18 checked replacements |
| No auto-submit | Yes ("Finish and send" key, off by default) | Kept off; every mode set to paste only |
| Import config | Yes (Settings > Import Settings) | `PersonalVoice/PersonalVoice-Settings.json` |
| Keep dictated code | **No**: `()`/`[]`/`{}` content was deleted | Fixed in `TranscriptionOutputFilter` |
| Guard against meaning drift | **No** | `MeaningGuard` + pipeline fallback |
| Tests | **No** (unit test target was empty) | 34 tests + opt-in live Ollama eval |

---

## 1. One-time setup

All commands run in Terminal. On this Mac the repo is already at `~/personal-voice`.

### 1a. Get the code

On a different Mac, clone it first:

```bash
git clone https://github.com/himelissaromano-tech/personal-voice.git ~/personal-voice
```

Then, on any Mac:

```bash
cd ~/personal-voice && git checkout main && git pull
```

### 1b. Run the regression tests (no Xcode needed)

```bash
cd ~/personal-voice && swift test
```

Expected result: `Test run with 34 tests passed` (one live-eval test shows as skipped).

### 1c. Install Xcode (needed to build the app)

1. Install **Xcode** from the Mac App Store (free, about 15 GB).
2. Point the command line tools at it and accept the license (asks for your password):

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

```bash
sudo xcodebuild -license accept
```

```bash
xcodebuild -runFirstLaunch
```

### 1d. Install Ollama and a model (free, runs locally)

Download Ollama from https://ollama.com/download/mac, open it once, and leave it
running in the menu bar. Then pull the model the profiles use:

```bash
ollama pull qwen2.5:3b-instruct
```

This Mac has 8 GB of memory, so the 3B model is the right size. On a Mac with
16 GB or more, `qwen2.5:7b-instruct` gives better polish. To switch, change
`AI_MODEL` in `PersonalVoice/generate_config.py`, run
`python3 PersonalVoice/generate_config.py`, and import again (step 3). You can
also pick the model per mode in the app.

Check that Ollama is running (it should list the model):

```bash
curl -s http://localhost:11434/api/tags
```

### 1e. Build the app

```bash
cd ~/personal-voice && make local
```

The first build compiles whisper.cpp and downloads Swift packages, so it can take
10 to 20 minutes. When it finishes, the app is at `~/Downloads/VoiceInk.app`.
Move it to Applications:

```bash
rm -rf /Applications/VoiceInk.app && mv ~/Downloads/VoiceInk.app /Applications/
```

```bash
open /Applications/VoiceInk.app
```

Local builds count as licensed and have no iCloud sync or auto-update. If you have
no Apple Development certificate, the build is ad-hoc signed and macOS may ask for
permissions again after each rebuild.

## 2. First launch

1. Go through onboarding. Grant **Microphone** and **Accessibility** (Accessibility is
   what lets it paste). When asked about starter modes, pick only **Dictation**. The
   import in step 3 replaces them.
2. **AI Models** > download **Parakeet V3**. It is the local model every mode uses.
3. **AI Models** > AI provider **Ollama**: confirm the base URL is
   `http://localhost:11434` and that `qwen2.5:3b-instruct` is listed.
4. Leave every cloud provider without an API key. Nothing in personal-voice needs one.

## 3. Import the personal-voice profiles

1. **Settings** > **Export Settings** > **Export**. This saves a backup of your
   current setup.
2. **Settings** > **Import Settings** > **Import**, then choose
   `~/personal-voice/PersonalVoice/PersonalVoice-Settings.json`.
3. Tick **General Settings**, **Custom Prompts**, **Modes**, **Dictionary** and click
   **Import**. Modes and prompts *replace* the current ones. Dictionary entries are
   *merged* in. If a "Version Mismatch" notice appears, it is harmless.
4. **Modes** should now list Verbatim (default), Polished Prompt, ChatGPT, Claude
   Code, Gmail, Messages.
5. Give the two dictation modes shortcuts: **Modes** > **Verbatim** > shortcut (for
   example ⌃⌥V), and **Modes** > **Polished Prompt** > shortcut (for example ⌃⌥P).
6. Browser profiles (Gmail, chatgpt.com, claude.ai/code) need to read the current tab's
   URL. The first time, macOS asks to let VoiceInk control Safari or Chrome. Click
   **Allow**.

### Customize the dictionary

- In the app: **Dictionary**. Add terms under Vocabulary and fixes under Replacements.
  Changes apply right away.
- As a file: edit `VOCABULARY` / `REPLACEMENTS` in `PersonalVoice/generate_config.py`,
  then run these two commands. The tests reject unsafe replacements, for example
  ones that touch digits or negations, or that rewrite ordinary English.

```bash
cd ~/personal-voice && python3 PersonalVoice/generate_config.py && swift test
```

  Then **Dictionary** > **Import** > `PersonalVoice/Technical-Dictionary.json` (Merge).

## 4. Testing checklist

Each test takes under a minute. If a result is wrong, check **History**: it shows the
raw transcript, the polished text, and which mode ran.

| # | Where | Dictate | Expect |
|---|---|---|---|
| 1 | TextEdit | "Run npm test and only commit if all forty two tests pass" | **Verbatim**: raw words, no rewording, nothing sent |
| 2 | TextEdit, Polished Prompt shortcut | "um so don't push to main just open a pull request against develop" | A clean prompt; "Don't" still present |
| 3 | ChatGPT app or chatgpt.com | "explain why use effect runs twice in react eighteen don't suggest removing strict mode" | ChatGPT profile; text pasted into the box; **not sent** |
| 4 | Terminal running `claude` | "look at src slash api slash client dot ts and don't change the public exports" | Claude Code profile; plain text; **Return not pressed** |
| 5 | Gmail compose | "hi maya we can't do the twenty fourth but the twenty sixth works thanks melissa" | Greeting, body, sign-off; "can't", 24th and 26th kept; not sent |
| 6 | Messages | "running ten minutes late" | Messages profile, verbatim, not sent |
| 7 | ChatGPT, Verbatim shortcut | anything | Verbatim wins over the ChatGPT profile |
| 8 | Any app | "push it to git hub" | Dictionary fixes it to "GitHub" |
| 9 | Any app, with Wi-Fi off | Polished Prompt test 2 | Still works, which shows nothing leaves the Mac |

**Network check (optional):** while you dictate, list VoiceInk's open connections.
You should only see `localhost:11434` (Ollama). The app may also contact
github.io for announcements and Hugging Face when you download a model.

```bash
lsof -nP -i -a -c VoiceInk
```

**Live meaning eval (optional):** with Ollama running, this sends the 25 technical
instructions in `Tests/VoiceInkTests/TechnicalCorpus.swift` through the real prompts
and reports any output the guard would reject. In the app, those dictations would be
pasted verbatim instead.

```bash
cd ~/personal-voice && PERSONAL_VOICE_LIVE_OLLAMA=1 swift test --filter LiveOllamaEval
```

**Full test suite in Xcode (optional):** adds 5 more tests that use the app's real
import decoders and dictionary engine.

```bash
cd ~/personal-voice && make setup && xcodebuild test -project VoiceInk.xcodeproj -scheme VoiceInk -destination 'platform=macOS' -only-testing:VoiceInkTests CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= -skipPackagePluginValidation -skipMacroValidation
```

## 5. Updating

Pull upstream VoiceInk changes, re-run the tests, and rebuild:

```bash
cd ~/personal-voice && git fetch https://github.com/Beingpax/VoiceInk.git main && git merge FETCH_HEAD && swift test && make local
```

## Limits to know

- The guard is deliberately strict. If you correct yourself out loud ("don't, actually
  do push"), the polished text drops a "don't", so you get the verbatim transcript.
  That is the intended trade-off.
- The guard checks exact tokens and negations. It cannot catch every rewording of
  plain words. That is why Verbatim is the default and Polished Prompt runs only in
  the AI-chat profiles.
- Filler words (um, uh, hmm) are removed in every mode. To change the list, go to
  **AI Models** > model settings > Filler Words.
- The Claude desktop app counts as Claude Code, because chat and Code share one app.
  Use the Verbatim shortcut for regular Claude chats, or remove the Claude app from
  the profile.
