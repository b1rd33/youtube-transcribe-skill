# YouTube Transcribe Skill for Claude Code

Download YouTube videos and transcribe them locally on your Mac — powered by [FluidAudio](https://github.com/b1rd33/fluidaudio-skill). 25 languages, auto-detected. Zero cloud dependencies.

## What This Is

A [Claude Code skill](https://docs.anthropic.com/en/docs/claude-code) that combines yt-dlp + ffmpeg + FluidAudio into a single pipeline: paste a YouTube URL, get a transcript.

```
YouTube URL → yt-dlp (download) → ffmpeg (16kHz WAV) → FluidAudio (transcribe) → transcript
```

## Features

- Transcribe any YouTube video in 25 languages (auto-detected)
- Smart chunking for long videos (auto-splits at 30min into 10min chunks)
- Speaker diarization (who said what)
- YouTube subtitle fallback when available
- Playlist support
- All processing runs locally on Apple Neural Engine

## Requirements

- **macOS 14+** with Apple Silicon (M1/M2/M3/M4)
- **Homebrew:** `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` ([brew.sh](https://brew.sh))
- **yt-dlp + ffmpeg:** `brew install yt-dlp ffmpeg`
- **Claude Code:** [Install guide](https://docs.anthropic.com/en/docs/claude-code)

## Installation

### 1. Install the FluidAudio skill (prerequisite)

```bash
git clone https://github.com/b1rd33/fluidaudio-skill.git ~/.claude/skills/fluidaudio
```

Then follow [fluidaudio-skill setup](https://github.com/b1rd33/fluidaudio-skill#installation) (clone FluidAudio, set `FLUIDAUDIO_HOME`).

### 2. Install this skill

```bash
git clone https://github.com/b1rd33/youtube-transcribe-skill.git ~/.claude/skills/youtube-transcribe
```

### 3. Use it

In Claude Code, just say:
- "Transcribe this YouTube video: https://youtube.com/watch?v=..."
- "Summarize this lecture: https://youtube.com/watch?v=..."
- "Download and transcribe this podcast episode"
- "Who is speaking in this YouTube interview?"

## How It Works

| Video Length | Behavior |
|-------------|----------|
| < 30 min | Transcribed as one file |
| 30-60 min | Auto-split into 10min chunks |
| 1-2 hours | 6-12 chunks, summarized individually |
| 2+ hours | 12+ chunks with manifest file |

## Common Options

| Use Case | Flag |
|----------|------|
| English content | `--model v2` (highest accuracy) |
| Non-English video | `--model v3` (default, 25 languages) |
| Meeting with speakers | `--diarize` |
| Use YouTube captions only | `--subs-only` |
| Short video, no splitting | `--no-chunk` |
| Custom chunk size | `--chunk 15` (minutes) |

## Related

- [fluidaudio-skill](https://github.com/b1rd33/fluidaudio-skill) — the speech-to-text engine this skill uses

## License

MIT — see [LICENSE](LICENSE)
