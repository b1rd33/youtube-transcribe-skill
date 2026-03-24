# YouTube Download Reference

## Installation

```bash
brew install yt-dlp ffmpeg
```

## Basic Audio Download

```bash
# Best quality audio as MP3
yt-dlp -x -f "bestaudio/best" --audio-format mp3 --audio-quality 0 \
  -o "%(title)s.%(ext)s" "URL"
```

## Format Options

| Format | Flag | Best For |
|--------|------|----------|
| MP3 | `--audio-format mp3` | Universal, good for storage |
| M4A | `--audio-format m4a` | Apple ecosystem |
| FLAC | `--audio-format flac` | Lossless (largest files) |
| Opus | `--audio-format opus` | Small file, good quality |
| WAV | `--audio-format wav` | Direct to speech recognition |

## Subtitle Download

```bash
# Auto-generated subtitles (YouTube's speech recognition)
yt-dlp --write-auto-subs --sub-langs "en" --convert-subs srt --skip-download "URL"

# Official subtitles (creator-provided)
yt-dlp --write-subs --sub-langs "en" --convert-subs srt --skip-download "URL"

# Both official and auto-generated
yt-dlp --write-subs --write-auto-subs --sub-langs "en" --convert-subs srt --skip-download "URL"

# All available languages
yt-dlp --write-auto-subs --sub-langs "all" --convert-subs srt --skip-download "URL"

# List available subtitles
yt-dlp --list-subs "URL"
```

## Playlist Download

```bash
# Entire playlist audio
yt-dlp -x -f "bestaudio/best" --audio-format mp3 \
  -o "%(playlist_index)03d_%(title)s.%(ext)s" "PLAYLIST_URL"

# Specific range
yt-dlp -x -f "bestaudio/best" --audio-format mp3 \
  --playlist-items 1-5 "PLAYLIST_URL"

# Download playlist metadata only
yt-dlp --flat-playlist -j "PLAYLIST_URL"
```

## Useful Flags

| Flag | Purpose |
|------|---------|
| `-o "TEMPLATE"` | Output filename template |
| `--restrict-filenames` | Sanitize filenames (ASCII only) |
| `--no-overwrites` | Don't overwrite existing files |
| `--download-archive done.txt` | Track downloaded videos |
| `--cookies-from-browser chrome` | Use browser cookies for age-restricted content |
| `--limit-rate 5M` | Limit download speed |
| `--proxy URL` | Use proxy |

## Output Templates

| Template | Result |
|----------|--------|
| `%(title)s.%(ext)s` | `Video Title.mp3` |
| `%(upload_date)s_%(title)s.%(ext)s` | `20240115_Video Title.mp3` |
| `%(channel)s/%(title)s.%(ext)s` | `ChannelName/Video Title.mp3` |
| `%(playlist_index)03d_%(title)s.%(ext)s` | `001_Video Title.mp3` |

## Get Video Info Without Downloading

```bash
# Get title
yt-dlp --get-title "URL"

# Get duration
yt-dlp --get-duration "URL"

# Get full JSON metadata
yt-dlp -j "URL"

# Get available formats
yt-dlp -F "URL"
```
