#!/usr/bin/env python3
"""Generates the personal-voice import files from one source of truth.

Edit the PROMPTS / MODES / VOCABULARY / REPLACEMENTS below, then run:

    python3 PersonalVoice/generate_config.py

Outputs (both are imported through VoiceInk's existing UI, no new app code):
  PersonalVoice/PersonalVoice-Settings.json   Settings > Backup > Import  (modes, prompts, dictionary, general)
  PersonalVoice/Technical-Dictionary.json     Dictionary > Import          (dictionary only, merge or replace)

`python3 PersonalVoice/generate_config.py --check` (run by CI) fails if the committed
JSON is out of date with this file. `swift test` checks the JSON's safety invariants.
"""

import json
import sys
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
APP_VERSION = "2.21"

# Local-only engines. Parakeet runs on-device through FluidAudio; Ollama runs on localhost.
TRANSCRIPTION_MODEL = "parakeet-tdt-0.6b-v3"
AI_PROVIDER = "Ollama"
# 3B fits an 8 GB Mac. On 16 GB+ use "qwen2.5:7b-instruct" for better polish.
AI_MODEL = "qwen2.5:3b-instruct"

# ---------------------------------------------------------------------------
# Prompts. useSystemInstructions=True wraps each in VoiceInk's own transcript-cleanup
# rules (preserve meaning, never answer the transcript, never add unspoken content).
# ---------------------------------------------------------------------------

SHARED_TECHNICAL_RULES = """\
- You are editing the speaker's words, not replying to them. Never answer, execute, evaluate, or comment on the request.
- Copy every technical detail exactly as dictated: commands, flags, file names, paths, URLs, code, identifiers, version numbers, numbers, units, error messages, and quoted text. Do not rename, re-case, translate, shorten, or "fix" them.
- Keep every negation, limit, and condition exactly (not, never, don't, only, must, unless, until, before, after, at most, at least). Never turn a prohibition into a permission or the reverse.
- Keep the speaker's order of steps. Do not merge, split, reorder, or drop requirements.
- Do not add requirements, assumptions, explanations, examples, greetings, or sign-offs that were not spoken.
- Remove filler words, stutters, and discarded self-corrections. Fix punctuation, capitalization, and grammar.
- If you are unsure whether a change alters meaning, keep the original wording."""

PROMPTS = [
    {
        "id": "20000000-0000-0000-0000-000000000001",
        "title": "Polished Prompt",
        "useSystemInstructions": True,
        "promptText": f"""\
<TASK>
Turn <TRANSCRIPT> into a clear, well-organized prompt that the speaker will paste into an AI assistant, review, and send themselves.
</TASK>

<RULES>
{SHARED_TECHNICAL_RULES}
- When the speaker gives several requirements or steps, format them as a numbered list in the spoken order. Otherwise use short paragraphs.
</RULES>

<EXAMPLES>
Input: um okay so in the auth service don't touch the login function just add a retry to fetchToken with three attempts and uh run npm test after
Output:
In the auth service:

1. Don't touch the login function.
2. Add a retry to fetchToken with 3 attempts.
3. Run npm test after.

Input: what's the difference between a process and a thread
Output: What's the difference between a process and a thread?
</EXAMPLES>""",
    },
    {
        "id": "20000000-0000-0000-0000-000000000002",
        "title": "Polished Prompt (Claude Code)",
        "useSystemInstructions": True,
        "promptText": f"""\
<TASK>
Turn <TRANSCRIPT> into a precise instruction for Claude Code, a coding agent in the terminal. The speaker will review it and press Return themselves.
</TASK>

<RULES>
{SHARED_TECHNICAL_RULES}
- Plain text only. No markdown headings, bold, or code fences. Numbered lists are allowed for multiple steps.
- Keep slash commands (such as /review or /clear) and @file mentions exactly as spoken, at the position spoken.
</RULES>

<EXAMPLES>
Input: so uh look at src/api/client.ts and don't change the public exports just make the timeout configurable default it to 30 seconds
Output:
Look at src/api/client.ts.

1. Don't change the public exports.
2. Make the timeout configurable, defaulting to 30 seconds.
</EXAMPLES>""",
    },
    {
        "id": "20000000-0000-0000-0000-000000000003",
        "title": "Polished Email",
        "useSystemInstructions": True,
        "promptText": """\
<TASK>
Clean <TRANSCRIPT> into a polished, readable email body. The speaker will review it and send it themselves.
</TASK>

<RULES>
- Keep names, dates, times, amounts, numbers, links, and commitments exactly as dictated. Never add facts, promises, or deadlines.
- Keep every negation and condition (not, never, don't, only, unless, until).
- Keep dictated greetings and sign-offs. Do not add any that were not spoken, and do not add a subject line.
- Keep the speaker's tone. Do not make it more formal, apologetic, or enthusiastic than spoken.
</RULES>

<EXAMPLES>
Input: hi maya thanks for sending the quote we can't do the twenty fourth but the twenty sixth works let me know if that's ok thanks melissa
Output:
Hi Maya,

Thanks for sending the quote. We can't do the 24th, but the 26th works. Let me know if that's OK.

Thanks,
Melissa
</EXAMPLES>""",
    },
]

POLISHED_PROMPT_ID = PROMPTS[0]["id"]
CLAUDE_CODE_PROMPT_ID = PROMPTS[1]["id"]
EMAIL_PROMPT_ID = PROMPTS[2]["id"]


def app(bundle_id, name, uid):
    return {"id": uid, "bundleIdentifier": bundle_id, "appName": name}


def url(address, uid):
    return {"id": uid, "url": address}


def mode(uid, name, symbol, *, prompt_id=None, apps=(), urls=(), is_default=False):
    """Every mode: local Parakeet, paste only, no screen/clipboard/selection context."""
    polished = prompt_id is not None
    return {
        "id": uid,
        "name": name,
        "icon": {"kind": "symbol", "value": symbol},
        "appConfigs": list(apps) or None,
        "urlConfigs": list(urls) or None,
        "isAIEnhancementEnabled": polished,
        "selectedPrompt": prompt_id,
        "selectedTranscriptionModelName": TRANSCRIPTION_MODEL,
        "isRealtimeTranscriptionEnabled": True,
        "selectedLanguage": "en",
        # Paragraph formatting only re-flows whitespace; Verbatim keeps the raw line.
        "isTextFormattingEnabled": False,
        "useClipboardContext": False,
        "useSelectedTextContext": False,
        "useScreenCapture": False,
        "selectedAIProvider": AI_PROVIDER if polished else None,
        "selectedAIModel": AI_MODEL if polished else None,
        "outputMode": "paste",
        "isEnabled": True,
        "isDefault": is_default,
    }


MODES = [
    # The two dictation modes. Verbatim is the default everywhere no profile matches.
    mode("30000000-0000-0000-0000-000000000001", "Verbatim", "mic.fill", is_default=True),
    mode("30000000-0000-0000-0000-000000000002", "Polished Prompt", "sparkles", prompt_id=POLISHED_PROMPT_ID),
    # App profiles. Each picks one of the two dictation modes for that app.
    mode(
        "30000000-0000-0000-0000-000000000003", "ChatGPT", "bubble.left.and.text.bubble.right.fill",
        prompt_id=POLISHED_PROMPT_ID,
        apps=[app("com.openai.chat", "ChatGPT", "31000000-0000-0000-0000-000000000001")],
        urls=[
            url("chatgpt.com", "32000000-0000-0000-0000-000000000001"),
            url("chat.openai.com", "32000000-0000-0000-0000-000000000002"),
        ],
    ),
    mode(
        "30000000-0000-0000-0000-000000000004", "Claude Code", "apple.terminal.fill",
        prompt_id=CLAUDE_CODE_PROMPT_ID,
        apps=[
            app("com.apple.Terminal", "Terminal", "31000000-0000-0000-0000-000000000002"),
            app("com.googlecode.iterm2", "iTerm2", "31000000-0000-0000-0000-000000000003"),
            app("com.mitchellh.ghostty", "Ghostty", "31000000-0000-0000-0000-000000000004"),
            app("dev.warp.Warp-Stable", "Warp", "31000000-0000-0000-0000-000000000005"),
            app("com.anthropic.claudefordesktop", "Claude", "31000000-0000-0000-0000-000000000006"),
        ],
        urls=[url("claude.ai/code", "32000000-0000-0000-0000-000000000003")],
    ),
    mode(
        "30000000-0000-0000-0000-000000000005", "Gmail", "envelope.fill",
        prompt_id=EMAIL_PROMPT_ID,
        urls=[url("mail.google.com", "32000000-0000-0000-0000-000000000004")],
    ),
    mode(
        "30000000-0000-0000-0000-000000000006", "Messages", "phone.bubble.fill",
        apps=[app("com.apple.MobileSMS", "Messages", "31000000-0000-0000-0000-000000000007")],
    ),
]

# ---------------------------------------------------------------------------
# Technical dictionary.
# VOCABULARY is spelling guidance for the AI step (and Whisper models).
# REPLACEMENTS run on every transcript, Verbatim included. Rules (enforced by tests):
#   * a replacement may only fix spacing/casing ("git hub" -> "GitHub"), unless the
#     source is listed in PHONETIC_ALIASES with a reason;
#   * no source or replacement may contain digits or negation words;
#   * no source may be a phrase that is also ordinary English ("read me", "home brew").
# ---------------------------------------------------------------------------

VOCABULARY = [
    "Claude Code", "Claude", "Anthropic", "ChatGPT", "OpenAI", "Ollama", "VoiceInk", "Parakeet", "Whisper",
    "GitHub", "GitHub Actions", "pull request", "Git", "README", "CLI", "API", "SDK", "MCP", "JSON", "YAML",
    "Xcode", "Swift", "SwiftUI", "SwiftData", "macOS", "iOS", "Homebrew", "localhost", "SSH",
    "TypeScript", "JavaScript", "Node.js", "npm", "pnpm", "Python", "pytest", "Docker", "PostgreSQL",
    "Gmail", "Google Drive", "Notion", "Shopify", "Zoho Books",
]

REPLACEMENTS = {
    "git hub": "GitHub",
    "get hub": "GitHub",
    "chat gpt": "ChatGPT",
    "claud code": "Claude Code",
    "clawed code": "Claude Code",
    "cloud code": "Claude Code",
    "open ai": "OpenAI",
    "o llama": "Ollama",
    "x code": "Xcode",
    "swift ui": "SwiftUI",
    "swift data": "SwiftData",
    "mac os": "macOS",
    "type script": "TypeScript",
    "java script": "JavaScript",
    "node js": "Node.js",
    "post gres": "Postgres",
    "voice ink": "VoiceInk",
    "dot env": ".env",
}

# Sources whose replacement is not a pure spacing/casing fix, each with why it is safe.
PHONETIC_ALIASES = {
    "get hub": "ASR mishearing of GitHub; 'get hub' is not a phrase used otherwise.",
    "claud code": "ASR mishearing of Claude Code.",
    "clawed code": "ASR mishearing of Claude Code.",
    "cloud code": "ASR mishearing of Claude Code. Remove this rule if you ever dictate about Google Cloud Code.",
    "node js": "Adds the dot in Node.js.",
    "dot env": "Spoken name of the .env file.",
}


def backup_file():
    return {
        "version": APP_VERSION,
        "customPrompts": PROMPTS,
        "modeConfigs": [{k: v for k, v in m.items() if v is not None} for m in MODES],
        "vocabularyWords": [{"word": w} for w in VOCABULARY],
        "wordReplacements": REPLACEMENTS,
        "generalSettings": {
            # No automated submissions: never press Return/Cmd+Return after pasting.
            "finishAndSendKey": "none",
            # Auto-Learn reviews corrections with an AI provider; keep it off so nothing leaves the Mac.
            "isAutoLearnDictionaryEnabled": False,
            "isTextFormattingEnabled": False,
            "restoreClipboardAfterPaste": True,
        },
    }


def dictionary_file():
    return {
        "format": "voiceink.dictionary",
        "schemaVersion": 1,
        "exportedAt": "2026-10-15T00:00:00Z",
        "appVersion": APP_VERSION,
        "vocabulary": [{"term": w} for w in VOCABULARY],
        "replacements": [{"sources": [src], "replacement": dst} for src, dst in REPLACEMENTS.items()],
    }


def render(obj):
    return json.dumps(obj, indent=2, ensure_ascii=False) + "\n"


OUTPUTS = {
    "PersonalVoice-Settings.json": backup_file,
    "Technical-Dictionary.json": dictionary_file,
}

if __name__ == "__main__":
    check_only = "--check" in sys.argv
    stale = []
    for name, build in OUTPUTS.items():
        path = HERE / name
        content = render(build())
        if check_only:
            if not path.exists() or path.read_text() != content:
                stale.append(name)
        else:
            path.write_text(content)
            print(f"wrote PersonalVoice/{name}")
    if stale:
        sys.exit("Out of date, run python3 PersonalVoice/generate_config.py: " + ", ".join(stale))
