# Audio Conversion Reference

## Convert to WAV for Speech Recognition

FluidAudio works best with 16kHz mono WAV files.

```bash
# Standard conversion (16kHz mono, 16-bit PCM)
ffmpeg -i input.mp3 -acodec pcm_s16le -ac 1 -ar 16000 output.wav

# With overwrite flag
ffmpeg -y -i input.mp3 -acodec pcm_s16le -ac 1 -ar 16000 output.wav
```

## Parameter Reference

| Parameter | Flag | Recommended Value | Purpose |
|-----------|------|-------------------|---------|
| Codec | `-acodec` | `pcm_s16le` | 16-bit signed little-endian PCM |
| Channels | `-ac` | `1` | Mono (single channel) |
| Sample rate | `-ar` | `16000` | 16kHz (standard for ASR) |

## Alternative Sample Rates

| Rate | Use Case |
|------|----------|
| 8000 Hz | Telephone quality (not recommended) |
| 16000 Hz | Standard for speech recognition (recommended) |
| 22050 Hz | Higher quality ASR |
| 44100 Hz | CD quality (unnecessary for ASR) |
| 48000 Hz | Studio quality (unnecessary for ASR) |

## Batch Conversion

```bash
# Convert all MP3s in a directory
for f in *.mp3; do
    ffmpeg -y -i "$f" -acodec pcm_s16le -ac 1 -ar 16000 "${f%.mp3}.wav"
done
```

## Audio Info

```bash
# Get audio file details
ffprobe -show_format -show_streams input.mp3 2>/dev/null

# Get duration only
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 input.mp3
```

## Trim Audio

```bash
# Extract first 5 minutes
ffmpeg -i input.wav -t 300 -acodec pcm_s16le -ac 1 -ar 16000 first_5min.wav

# Extract from 10:00 to 20:00
ffmpeg -i input.wav -ss 600 -to 1200 -acodec pcm_s16le -ac 1 -ar 16000 segment.wav
```

## Normalize Audio Volume

```bash
# Detect volume level
ffmpeg -i input.wav -af volumedetect -f null /dev/null 2>&1 | grep max_volume

# Normalize to -3dB
ffmpeg -i input.wav -af "loudnorm=I=-16:TP=-3:LRA=11" -acodec pcm_s16le -ac 1 -ar 16000 normalized.wav
```
