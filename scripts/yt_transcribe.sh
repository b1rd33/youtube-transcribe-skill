#!/bin/bash
# yt_transcribe.sh - Full YouTube to transcript pipeline
# Uses yt-dlp + ffmpeg + FluidAudio for local transcription
#
# Usage:
#   ./yt_transcribe.sh "YOUTUBE_URL" [OPTIONS]
#
# Options:
#   --output DIR       Output directory (default: ~/Downloads/yt-transcripts)
#   --lang LANG        Subtitle language code (default: en)
#   --model VERSION    FluidAudio model: v2 (English) or v3 (multilingual, default)
#   --diarize          Also run speaker diarization
#   --subs-only        Skip FluidAudio, only download YouTube subtitles
#   --keep-audio       Keep intermediate audio files (mp3/wav)
#   --playlist         Process entire playlist
#   --chunk MINUTES    Split audio into chunks of N minutes (default: auto)
#   --no-chunk         Disable chunking even for long videos
#   --help             Show this help message

set -e

# ============================================================
# Configuration
# ============================================================
FLUIDAUDIO_HOME="${FLUIDAUDIO_HOME:-$HOME/Projects/FluidAudio}"
OUTPUT_DIR="$HOME/Downloads/yt-transcripts"
LANG="en"
MODEL="v3"
DIARIZE=false
SUBS_ONLY=false
KEEP_AUDIO=false
PLAYLIST=false
CHUNK_MINUTES=0       # 0 = auto (chunk if >30 min)
NO_CHUNK=false
AUTO_CHUNK_THRESHOLD=1800  # 30 minutes in seconds
DEFAULT_CHUNK_SIZE=600     # 10 minutes per chunk (sweet spot for context)
URL=""

# ============================================================
# Parse arguments
# ============================================================
show_help() {
    sed -n '2,14p' "$0" | sed 's/^# *//'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)    OUTPUT_DIR="$2"; shift 2 ;;
        --lang)      LANG="$2"; shift 2 ;;
        --model)     MODEL="$2"; shift 2 ;;
        --diarize)   DIARIZE=true; shift ;;
        --subs-only) SUBS_ONLY=true; shift ;;
        --keep-audio) KEEP_AUDIO=true; shift ;;
        --playlist)  PLAYLIST=true; shift ;;
        --chunk)     CHUNK_MINUTES="$2"; shift 2 ;;
        --no-chunk)  NO_CHUNK=true; shift ;;
        --help|-h)   show_help ;;
        -*)          echo "Unknown option: $1"; show_help ;;
        *)           URL="$1"; shift ;;
    esac
done

if [ -z "$URL" ]; then
    echo "Error: YouTube URL is required."
    echo ""
    show_help
fi

# ============================================================
# Verify dependencies
# ============================================================
check_dep() {
    if ! command -v "$1" &>/dev/null; then
        echo "Error: $1 not found. Install with: brew install $1"
        exit 1
    fi
}

check_dep yt-dlp
check_dep ffmpeg

if ! command -v swift &> /dev/null; then
    echo "Error: swift not found. Install Xcode Command Line Tools: xcode-select --install"
    exit 1
fi

if [ ! -d "$FLUIDAUDIO_HOME" ]; then
    echo "Error: FluidAudio not found at $FLUIDAUDIO_HOME"
    echo "Clone it: git clone https://github.com/FluidInference/FluidAudio.git $FLUIDAUDIO_HOME"
    echo "Then build: cd $FLUIDAUDIO_HOME && swift build -c release"
    exit 1
fi

# ============================================================
# Setup
# ============================================================
mkdir -p "$OUTPUT_DIR"

# Get video title for filenames
echo "Fetching video info..."
if [ "$PLAYLIST" = true ]; then
    TITLE=$(yt-dlp --get-filename -o "%(playlist_title)s" --playlist-items 1 "$URL" 2>/dev/null || echo "playlist")
else
    TITLE=$(yt-dlp --get-filename -o "%(title)s" "$URL" 2>/dev/null || echo "video")
fi

# Sanitize filename
SAFE_TITLE=$(echo "$TITLE" | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 100)
echo "Video: $TITLE"
echo "Output: $OUTPUT_DIR/"
echo ""

# ============================================================
# Step 1: Download YouTube subtitles (always try as fallback)
# ============================================================
echo "=== Step 1/4: Downloading YouTube subtitles ==="
yt-dlp --write-auto-subs --write-subs \
    --sub-langs "$LANG" \
    --convert-subs srt \
    --skip-download \
    -o "$OUTPUT_DIR/${SAFE_TITLE}" \
    "$URL" 2>/dev/null || echo "  (No subtitles available)"

# Check if we got subtitles
SUBS_FILE=$(ls "$OUTPUT_DIR/${SAFE_TITLE}"*.srt 2>/dev/null | head -1)
if [ -n "$SUBS_FILE" ]; then
    echo "  Subtitles saved: $SUBS_FILE"
else
    echo "  No subtitles found on YouTube"
fi

if [ "$SUBS_ONLY" = true ]; then
    if [ -n "$SUBS_FILE" ]; then
        echo ""
        echo "=== Done (subs-only mode) ==="
        echo "Subtitles: $SUBS_FILE"
        exit 0
    else
        echo "  No subtitles available, falling back to full transcription..."
        SUBS_ONLY=false
    fi
fi

# ============================================================
# Step 2: Download audio
# ============================================================
echo ""
echo "=== Step 2/4: Downloading audio ==="

YT_DLP_OPTS=(-x -f "bestaudio/best" --audio-format mp3 --audio-quality 0)
if [ "$PLAYLIST" = true ]; then
    YT_DLP_OPTS+=(-o "$OUTPUT_DIR/%(playlist_index)03d_%(title)s.%(ext)s")
else
    YT_DLP_OPTS+=(-o "$OUTPUT_DIR/${SAFE_TITLE}.%(ext)s")
fi

yt-dlp "${YT_DLP_OPTS[@]}" "$URL"

echo "  Audio downloaded."

# ============================================================
# Step 3: Convert to WAV (16kHz mono for speech recognition)
# ============================================================
echo ""
echo "=== Step 3/4: Converting to WAV ==="

# Find all downloaded MP3 files
MP3_FILES=$(find "$OUTPUT_DIR" -name "${SAFE_TITLE}*.mp3" -o -name "*.mp3" 2>/dev/null | head -5)

if [ -z "$MP3_FILES" ]; then
    # Fallback: find any recent mp3
    MP3_FILES=$(find "$OUTPUT_DIR" -name "*.mp3" -mmin -5 | sort)
fi

WAV_FILES=""
while IFS= read -r mp3; do
    [ -z "$mp3" ] && continue
    wav="${mp3%.mp3}.wav"
    echo "  Converting: $(basename "$mp3") → $(basename "$wav")"
    ffmpeg -y -i "$mp3" -acodec pcm_s16le -ac 1 -ar 16000 "$wav" 2>/dev/null
    WAV_FILES="$WAV_FILES $wav"
done <<< "$MP3_FILES"

echo "  Conversion complete."

# ============================================================
# Step 4: Chunk long audio (if needed)
# ============================================================
echo ""
echo "=== Step 4/5: Checking duration & chunking ==="

FINAL_WAV_FILES=""

for wav in $WAV_FILES; do
    [ -z "$wav" ] && continue
    BASENAME=$(basename "$wav" .wav)

    # Get duration in seconds
    DURATION=$(ffprobe -v error -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$wav" 2>/dev/null | cut -d. -f1)
    DURATION=${DURATION:-0}
    DURATION_MIN=$((DURATION / 60))

    echo "  $(basename "$wav"): ${DURATION_MIN}m ${DURATION}s total"

    # Determine if we should chunk
    SHOULD_CHUNK=false
    CHUNK_SECONDS="$DEFAULT_CHUNK_SIZE"

    if [ "$NO_CHUNK" = true ]; then
        SHOULD_CHUNK=false
    elif [ "$CHUNK_MINUTES" -gt 0 ] 2>/dev/null; then
        # User explicitly set chunk size
        SHOULD_CHUNK=true
        CHUNK_SECONDS=$((CHUNK_MINUTES * 60))
    elif [ "$DURATION" -gt "$AUTO_CHUNK_THRESHOLD" ]; then
        # Auto-chunk: video longer than 30 minutes
        SHOULD_CHUNK=true
        CHUNK_SECONDS="$DEFAULT_CHUNK_SIZE"
    fi

    if [ "$SHOULD_CHUNK" = true ]; then
        CHUNK_MIN=$((CHUNK_SECONDS / 60))
        NUM_CHUNKS=$(( (DURATION + CHUNK_SECONDS - 1) / CHUNK_SECONDS ))
        echo "  Splitting into ${NUM_CHUNKS} chunks of ~${CHUNK_MIN}m each..."

        CHUNK_DIR="$OUTPUT_DIR/${BASENAME}_chunks"
        mkdir -p "$CHUNK_DIR"

        CHUNK_IDX=0
        OFFSET=0
        while [ "$OFFSET" -lt "$DURATION" ]; do
            CHUNK_IDX=$((CHUNK_IDX + 1))
            CHUNK_FILE="$CHUNK_DIR/${BASENAME}_chunk$(printf '%03d' $CHUNK_IDX).wav"

            # Calculate time labels for display
            START_MIN=$((OFFSET / 60))
            START_SEC=$((OFFSET % 60))
            END=$((OFFSET + CHUNK_SECONDS))
            [ "$END" -gt "$DURATION" ] && END="$DURATION"
            END_MIN=$((END / 60))
            END_SEC=$((END % 60))

            echo "    Chunk $CHUNK_IDX: $(printf '%02d:%02d' $START_MIN $START_SEC) → $(printf '%02d:%02d' $END_MIN $END_SEC)"
            ffmpeg -y -i "$wav" -ss "$OFFSET" -t "$CHUNK_SECONDS" \
                -acodec pcm_s16le -ac 1 -ar 16000 "$CHUNK_FILE" 2>/dev/null

            FINAL_WAV_FILES="$FINAL_WAV_FILES $CHUNK_FILE"
            OFFSET=$((OFFSET + CHUNK_SECONDS))
        done

        # Write a manifest so Claude knows the chunk order
        MANIFEST="$OUTPUT_DIR/${BASENAME}_chunks.txt"
        echo "# Chunk manifest for: $TITLE" > "$MANIFEST"
        echo "# Total duration: ${DURATION_MIN}m" >> "$MANIFEST"
        echo "# Chunk size: ${CHUNK_MIN}m" >> "$MANIFEST"
        echo "# Chunks: $NUM_CHUNKS" >> "$MANIFEST"
        echo "#" >> "$MANIFEST"
        echo "# Read transcripts in order (chunk001, chunk002, ...) for full content." >> "$MANIFEST"
        echo "# Each chunk transcript is small enough for Claude's context window." >> "$MANIFEST"
        echo "#" >> "$MANIFEST"
        CIDX=0
        COFF=0
        while [ "$COFF" -lt "$DURATION" ]; do
            CIDX=$((CIDX + 1))
            CS=$((COFF / 60))
            CEND=$((COFF + CHUNK_SECONDS))
            [ "$CEND" -gt "$DURATION" ] && CEND="$DURATION"
            CE=$((CEND / 60))
            echo "chunk$(printf '%03d' $CIDX)  ${CS}m-${CE}m  ${BASENAME}_chunk$(printf '%03d' $CIDX)_transcript.txt" >> "$MANIFEST"
            COFF=$((COFF + CHUNK_SECONDS))
        done
        echo "  Manifest: $MANIFEST"
    else
        echo "  Short enough — no chunking needed."
        FINAL_WAV_FILES="$FINAL_WAV_FILES $wav"
    fi
done

# ============================================================
# Step 5: Transcribe with FluidAudio
# ============================================================
echo ""
echo "=== Step 5/5: Transcribing with FluidAudio ==="

cd "$FLUIDAUDIO_HOME"

for wav in $FINAL_WAV_FILES; do
    [ -z "$wav" ] && continue
    BASENAME=$(basename "$wav" .wav)
    # Put chunk transcripts next to chunks, others in output dir
    if echo "$wav" | grep -q "_chunks/"; then
        TRANSCRIPT_FILE="$(dirname "$wav")/../${BASENAME}_transcript.txt"
    else
        TRANSCRIPT_FILE="$OUTPUT_DIR/${BASENAME}_transcript.txt"
    fi

    echo "  Transcribing: $(basename "$wav")"
    swift run -c release fluidaudiocli transcribe "$wav" --model-version "$MODEL" > "$TRANSCRIPT_FILE" 2>&1

    echo "  → $(basename "$TRANSCRIPT_FILE")"

    # Optional: Speaker diarization
    if [ "$DIARIZE" = true ]; then
        if echo "$wav" | grep -q "_chunks/"; then
            DIAR_FILE="$(dirname "$wav")/../${BASENAME}_diarization.json"
        else
            DIAR_FILE="$OUTPUT_DIR/${BASENAME}_diarization.json"
        fi
        echo "  Diarizing: $(basename "$wav")"
        swift run -c release fluidaudiocli process "$wav" \
            --mode offline \
            --threshold 0.6 \
            > "$DIAR_FILE" 2>&1 || true
        echo "  → $(basename "$DIAR_FILE")"
    fi
done

# ============================================================
# Cleanup
# ============================================================
if [ "$KEEP_AUDIO" = false ]; then
    echo ""
    echo "Cleaning up intermediate files..."
    # Remove original WAV files
    for wav in $WAV_FILES; do
        [ -f "$wav" ] && rm "$wav" && echo "  Removed: $(basename "$wav")"
    done
    # Remove chunk WAV files
    for wav in $FINAL_WAV_FILES; do
        [ -f "$wav" ] && rm "$wav" && echo "  Removed: $(basename "$wav")"
    done
    # Remove chunk directories if empty
    find "$OUTPUT_DIR" -name "*_chunks" -type d -empty -delete 2>/dev/null
    # Remove MP3 files
    for mp3 in $MP3_FILES; do
        [ -f "$mp3" ] && rm "$mp3" && echo "  Removed: $(basename "$mp3")"
    done
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "=========================================="
echo "  Pipeline Complete!"
echo "=========================================="
echo ""
echo "Output directory: $OUTPUT_DIR/"
echo ""
echo "Files:"
ls -1 "$OUTPUT_DIR/${SAFE_TITLE}"* 2>/dev/null | while read -r f; do
    SIZE=$(du -h "$f" | cut -f1)
    echo "  [$SIZE] $(basename "$f")"
done
echo ""
echo "Next: Open the transcript file and ask Claude to summarize!"
