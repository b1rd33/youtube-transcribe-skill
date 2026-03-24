---
name: youtube-transcribe
description: |
  Download YouTube videos, extract audio, transcribe with FluidAudio (local macOS Neural Engine), and summarize. Full pipeline from URL to transcript to insights. Works with any YouTube video, supports 25+ languages.
  MANDATORY TRIGGERS: youtube transcribe, youtube transcript, youtube summary, summarize youtube, youtube audio, download youtube, youtube to text, video transcript, video summary, summarize video, youtube summarize, yt transcribe, yt summary, youtube notes, video notes, lecture notes from youtube, podcast from youtube, youtube podcast
---

# YouTube Transcribe Skill

Download YouTube videos, extract audio, transcribe locally with FluidAudio, and summarize — all from a single URL.

## Prerequisites

```bash
# Install required tools (macOS)
brew install yt-dlp ffmpeg

# FluidAudio must be built (one-time)
cd $FLUIDAUDIO_HOME  # or wherever FluidAudio is cloned
swift build -c release
```

## Quick Start

```bash
# Full pipeline: YouTube URL → transcript
~/.claude/skills/youtube-transcribe/scripts/yt_transcribe.sh "https://www.youtube.com/watch?v=VIDEO_ID"

# With options
~/.claude/skills/youtube-transcribe/scripts/yt_transcribe.sh "URL" --lang en --model v2 --output ~/Documents
```

## Pipeline Overview

```
YouTube URL
  → yt-dlp (download audio only, best quality)
  → ffmpeg (convert to 16kHz mono WAV for speech recognition)
  → Auto-chunk if >30min (split into 10min segments)
  → FluidAudio (local transcription via Apple Neural Engine)
  → Output: transcript chunk files + manifest, ready for summarization
```

## Step-by-Step Manual Workflow

### Step 1: Download Audio from YouTube

```bash
# Download best audio, extract as MP3
yt-dlp -x -f "bestaudio/best" --audio-format mp3 --audio-quality 0 \
  -o "%(title)s.%(ext)s" "YOUTUBE_URL"

# Optional: Also grab YouTube's auto-generated subtitles as fallback
yt-dlp --write-auto-subs --write-subs --sub-langs "en" --convert-subs srt \
  --skip-download -o "%(title)s" "YOUTUBE_URL"
```

### Step 2: Convert to WAV for FluidAudio

```bash
# Convert to 16kHz mono WAV (optimal for speech recognition)
ffmpeg -i "video_title.mp3" -acodec pcm_s16le -ac 1 -ar 16000 "video_title.wav"
```

### Step 3: Transcribe with FluidAudio

```bash
# English content (highest accuracy)
cd $FLUIDAUDIO_HOME
swift run -c release fluidaudiocli transcribe "video_title.wav" --model-version v2 > transcript.txt 2>&1

# Multilingual content (25 languages)
swift run -c release fluidaudiocli transcribe "video_title.wav" > transcript.txt 2>&1

# With speaker diarization (who said what)
swift run -c release fluidaudiocli process "video_title.wav" --mode offline --threshold 0.6 > diarization.json 2>&1
swift run -c release fluidaudiocli transcribe "video_title.wav" --model-version v2 > transcript.txt 2>&1
```

### Step 4: Summarize

Once you have the transcript, ask Claude to summarize, extract key points, create notes, etc.

## Reference Documentation

| Topic | File | Use When |
|-------|------|----------|
| Download Options | [download.md](references/download.md) | Configuring yt-dlp for different scenarios |
| Audio Conversion | [audio.md](references/audio.md) | ffmpeg conversion options and formats |
| Transcription | [transcription.md](references/transcription.md) | FluidAudio ASR settings and models |
| Troubleshooting | [troubleshooting.md](references/troubleshooting.md) | Common issues and fixes |

## Smart Chunking (Context Window Protection)

Long videos produce massive transcripts that can overwhelm Claude's context window. The skill auto-chunks to prevent this.

**How it works:**
- Videos **under 30 minutes** → transcribed as one file (no chunking)
- Videos **over 30 minutes** → automatically split into **10-minute chunks**, each transcribed separately
- A **manifest file** (`{title}_chunks.txt`) maps each chunk to its time range
- Claude reads chunks one at a time for summarization instead of loading the entire transcript

**Manual control:**

```bash
# Force 15-minute chunks
yt_transcribe.sh "URL" --chunk 15

# Force 5-minute chunks (for very detailed analysis)
yt_transcribe.sh "URL" --chunk 5

# Disable chunking entirely
yt_transcribe.sh "URL" --no-chunk
```

**Chunked output structure:**

```
output_dir/
├── Video_Title_chunks.txt              # Manifest: chunk → time range mapping
├── Video_Title_chunk001_transcript.txt  # 00:00 → 10:00
├── Video_Title_chunk002_transcript.txt  # 10:00 → 20:00
├── Video_Title_chunk003_transcript.txt  # 20:00 → 30:00
└── ...
```

**Context-aware summarization workflow:**

For chunked videos, Claude should:
1. Read the manifest file first to understand the structure
2. Read and summarize each chunk individually
3. Combine chunk summaries into a final cohesive summary
4. Never load all chunks into context at once for long videos

| Video Length | Chunks | ~Transcript Size per Chunk |
|-------------|--------|---------------------------|
| < 30 min | 1 (no split) | ~3,000-5,000 words |
| 30-60 min | 3-6 | ~3,000-5,000 words each |
| 1-2 hours | 6-12 | ~3,000-5,000 words each |
| 2-3 hours | 12-18 | ~3,000-5,000 words each |
| 3+ hours | 18+ | ~3,000-5,000 words each |

## Common Use Cases

| Use Case | Command Flags |
|----------|---------------|
| English lecture/podcast | `--model v2` (English-optimized) |
| Non-English video | `--model v3` (default, 25 languages) |
| Meeting with speakers | Add `--diarize` flag |
| Subtitles fallback only | `--subs-only` (skip FluidAudio, use YouTube captions) |
| Batch process playlist | `--playlist` flag |
| Long lecture (2h+) | `--chunk 10` (default auto-chunks at 30min) |
| Short podcast | `--no-chunk` (keep as single transcript) |

## Output

The pipeline creates these files in the output directory:

| File | Description |
|------|-------------|
| `{title}.mp3` | Downloaded audio (cleaned up unless `--keep-audio`) |
| `{title}.wav` | Converted WAV (cleaned up unless `--keep-audio`) |
| `{title}_transcript.txt` | Full transcript (short videos) |
| `{title}_chunk00N_transcript.txt` | Chunk transcripts (long videos) |
| `{title}_chunks.txt` | Chunk manifest with time ranges |
| `{title}_diarization.json` | Speaker segments (if `--diarize`) |
| `{title}.en.srt` | YouTube subtitles (if available) |

## Tips

| Tip | Detail |
|-----|--------|
| **Always save output to files** | `> transcript.txt 2>&1` — prevents terminal freezing |
| **Use v2 for English** | Much higher accuracy for English-only content |
| **YouTube subs as fallback** | If FluidAudio fails, YouTube auto-subs are decent |
| **Long videos auto-chunk** | >30min videos split into 10min chunks automatically |
| **Adjust chunk size** | `--chunk 5` for detailed, `--chunk 20` for broad summaries |
| **Playlists** | yt-dlp natively supports playlist URLs |
| **Clean up WAV files** | They're large; auto-deleted unless `--keep-audio` |
