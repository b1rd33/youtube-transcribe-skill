# Transcription Reference

## FluidAudio Transcription

FluidAudio runs locally on macOS using Apple Neural Engine. ~190x faster than real-time on M4 Pro.

### Basic Transcription

```bash
cd $FLUIDAUDIO_HOME

# English (highest accuracy)
swift run -c release fluidaudiocli transcribe audio.wav --model-version v2 > transcript.txt 2>&1

# Multilingual (25 languages)
swift run -c release fluidaudiocli transcribe audio.wav > transcript.txt 2>&1

# Multiple files in parallel
swift run -c release fluidaudiocli multi-stream file1.wav file2.wav file3.wav > transcripts.txt 2>&1
```

### Models

| Model | Languages | Best For | Speed |
|-------|-----------|----------|-------|
| v3 (default) | 25 European | Multilingual content | ~190x real-time |
| v2 | English only | Highest English accuracy | ~190x real-time |

### Supported Languages (v3)

English, German, French, Spanish, Italian, Portuguese, Dutch, Polish, Russian, Czech, Slovak, Hungarian, Romanian, Bulgarian, Croatian, Serbian, Slovenian, Ukrainian, Greek, Turkish, Finnish, Swedish, Norwegian, Danish, Catalan

### Speaker Diarization

Identify who spoke when in multi-speaker audio:

```bash
# Offline mode (most accurate)
swift run -c release fluidaudiocli process audio.wav --mode offline --threshold 0.6 > diarization.json 2>&1

# Streaming mode (lower latency)
swift run -c release fluidaudiocli process audio.wav --mode streaming --threshold 0.7 > diarization.json 2>&1

# Export speaker embeddings
swift run -c release fluidaudiocli process audio.wav --export-embeddings embeddings.json > diarization.json 2>&1
```

### Output Format

**Transcription:**
```json
{
  "text": "Hello, this is a test.",
  "segments": [
    {"text": "Hello,", "start": 0.0, "end": 0.5},
    {"text": "this is a test.", "start": 0.6, "end": 2.1}
  ]
}
```

**Diarization:**
```json
{
  "segments": [
    {"speaker": "SPEAKER_00", "start": 0.0, "end": 5.2},
    {"speaker": "SPEAKER_01", "start": 5.5, "end": 12.3}
  ]
}
```

## YouTube Subtitles as Fallback

If FluidAudio is unavailable, YouTube's auto-generated subtitles work as a fallback:

```bash
# Download auto-generated subs
yt-dlp --write-auto-subs --sub-langs "en" --convert-subs srt --skip-download "URL"
```

### Quality Comparison

| Method | Accuracy | Speed | Languages | Offline |
|--------|----------|-------|-----------|---------|
| FluidAudio v2 | Excellent (English) | ~190x real-time | English | Yes |
| FluidAudio v3 | Very Good | ~190x real-time | 25 languages | Yes |
| YouTube Auto-Subs | Good | Instant | Many | No |

### SRT to Plain Text

```bash
# Strip timestamps from SRT file to get plain text
sed '/^[0-9]*$/d; /^[0-9][0-9]:[0-9][0-9]/d; /^$/d' subtitles.srt > plain_text.txt
```

## Tips

- **Always redirect to file:** `> transcript.txt 2>&1` — prevents terminal freezing
- **English content:** Use `--model-version v2` for best accuracy
- **Long videos:** FluidAudio handles them fine; no need to split
- **Noisy audio:** Consider normalizing volume before transcription
- **Multiple speakers:** Use diarization + transcription together
