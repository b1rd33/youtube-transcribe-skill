# Troubleshooting

## yt-dlp Issues

### "command not found"

```bash
# Install via Homebrew
brew install yt-dlp

# Or update if already installed
brew upgrade yt-dlp

# Verify installation
which yt-dlp
yt-dlp --version
```

### Download fails / HTTP 403 errors

```bash
# Update yt-dlp (YouTube frequently changes their API)
brew upgrade yt-dlp
# or
yt-dlp -U

# Try with browser cookies (for age-restricted or login-required videos)
yt-dlp --cookies-from-browser chrome "URL"

# Use a different format
yt-dlp -f "bestaudio" "URL"
```

### Slow downloads

```bash
# Try a different format (sometimes smaller formats download faster)
yt-dlp -f "worstaudio" "URL"

# Check available formats
yt-dlp -F "URL"
```

### Playlist not downloading

```bash
# Force playlist processing
yt-dlp --yes-playlist "URL"

# Check playlist info
yt-dlp --flat-playlist -j "URL" | head -5
```

## ffmpeg Issues

### "command not found"

```bash
brew install ffmpeg
which ffmpeg
ffmpeg -version
```

### Conversion fails

```bash
# Check input file info
ffprobe input.mp3

# Try with explicit input format
ffmpeg -f mp3 -i input.mp3 -acodec pcm_s16le -ac 1 -ar 16000 output.wav

# Verbose mode for debugging
ffmpeg -v debug -i input.mp3 -acodec pcm_s16le -ac 1 -ar 16000 output.wav
```

### Output file too large

WAV files are uncompressed and can be large. For a 1-hour video:
- MP3: ~60-100 MB
- WAV (16kHz mono): ~115 MB
- WAV (44.1kHz stereo): ~635 MB

Always use 16kHz mono (`-ar 16000 -ac 1`) for speech recognition.

## FluidAudio Issues

### "swift: command not found"

```bash
# Install Xcode command line tools
xcode-select --install

# Verify
swift --version
```

### Build fails

```bash
cd $FLUIDAUDIO_HOME
# Clean and rebuild
swift package clean
swift build -c release
```

### Transcription hangs or produces no output

```bash
# Check audio file is valid
ffprobe audio.wav

# Try with a shorter segment first
ffmpeg -i audio.wav -t 60 -acodec pcm_s16le -ac 1 -ar 16000 test_1min.wav
swift run -c release fluidaudiocli transcribe test_1min.wav --model-version v2 > test.txt 2>&1
```

### Wrong language detected

```bash
# Force English model
swift run -c release fluidaudiocli transcribe audio.wav --model-version v2 > transcript.txt 2>&1

# For non-English, ensure v3 model is used (default)
swift run -c release fluidaudiocli transcribe audio.wav > transcript.txt 2>&1
```

## Common Pipeline Errors

### "No such file or directory"

Check that filenames don't have special characters:
```bash
# Use --restrict-filenames with yt-dlp
yt-dlp --restrict-filenames -x -f "bestaudio/best" --audio-format mp3 "URL"
```

### Script permission denied

```bash
chmod +x ~/.claude/skills/youtube-transcribe/scripts/yt_transcribe.sh
```

### Disk space issues

```bash
# Check available space
df -h ~

# The pipeline needs roughly:
# - 1x video length as MP3 (~1.5 MB/min)
# - 1x video length as WAV (~1.9 MB/min at 16kHz mono)
# - Transcript is tiny (<1 KB/min)
```

## Quick Diagnostic

Run this to check all dependencies:

```bash
echo "=== Dependency Check ==="
echo -n "yt-dlp: " && (yt-dlp --version 2>/dev/null || echo "NOT FOUND")
echo -n "ffmpeg: " && (ffmpeg -version 2>/dev/null | head -1 || echo "NOT FOUND")
echo -n "swift:  " && (swift --version 2>/dev/null | head -1 || echo "NOT FOUND")
echo -n "FluidAudio: " && (ls ${FLUIDAUDIO_HOME:-$HOME/Projects/FluidAudio}/Package.swift 2>/dev/null && echo "FOUND" || echo "NOT FOUND")
echo ""
echo "Install missing dependencies:"
echo "  brew install yt-dlp ffmpeg"
echo "  xcode-select --install"
```
