#!/bin/bash
# YouTube Skill Extractor — ดึง transcript + frames จาก YouTube video
# Usage: ./extract.sh <youtube-url> [output-dir] [--force]
# Dependencies: yt-dlp, ffmpeg, python3

set -eo pipefail

# ─── Dependency checks ───
for cmd in yt-dlp ffmpeg ffprobe python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "❌ Required command '$cmd' not found. Please install it."
        echo "   brew install yt-dlp ffmpeg python3"
        exit 1
    fi
done

# ─── Parse flags and arguments ───
FORCE=false
for arg in "$@"; do
    if [ "$arg" = "--force" ]; then
        FORCE=true
    fi
done

# Filter out --force from positional args
URL=""
OUTPUT_BASE_ARG=""
for arg in "$@"; do
    if [ "$arg" = "--force" ]; then continue; fi
    if [ -z "$URL" ]; then URL="$arg"
    elif [ -z "$OUTPUT_BASE_ARG" ]; then OUTPUT_BASE_ARG="$arg"
    fi
done
OUTPUT_BASE="${OUTPUT_BASE_ARG:-$HOME/.claude/skills/youtube-skill-extractor/output}"

if [ -z "$URL" ]; then
    echo "❌ Usage: ./extract.sh <youtube-url> [output-dir] [--force]"
    exit 1
fi

# Validate YouTube URL
if ! echo "$URL" | grep -qE '^https?://(www\.)?(youtube\.com|youtu\.be|m\.youtube\.com)/'; then
    echo "❌ URL does not appear to be a YouTube URL: $URL"
    echo "   Supported: youtube.com/watch?v=..., youtu.be/..., youtube.com/shorts/..."
    exit 1
fi

# Extract video ID — try multiple patterns for cross-platform compatibility
VIDEO_ID=""
# Pattern 1: PCRE (works on GNU grep / Linux)
VIDEO_ID=$(echo "$URL" | grep -oP '(?:v=|youtu\.be/|shorts/)\K[a-zA-Z0-9_-]{11}' 2>/dev/null | head -1) || true
# Pattern 2: sed fallbacks for macOS (BSD grep lacks -P)
if [ -z "$VIDEO_ID" ]; then
    VIDEO_ID=$(echo "$URL" | sed -n 's/.*[?&]v=\([a-zA-Z0-9_-]\{11\}\).*/\1/p')
fi
if [ -z "$VIDEO_ID" ]; then
    VIDEO_ID=$(echo "$URL" | sed -n 's/.*youtu\.be\/\([a-zA-Z0-9_-]\{11\}\).*/\1/p')
fi
if [ -z "$VIDEO_ID" ]; then
    VIDEO_ID=$(echo "$URL" | sed -n 's/.*shorts\/\([a-zA-Z0-9_-]\{11\}\).*/\1/p')
fi
if [ -z "$VIDEO_ID" ]; then
    echo "❌ Cannot extract video ID from URL: $URL"
    exit 1
fi

OUTPUT_DIR="$OUTPUT_BASE/$VIDEO_ID"
mkdir -p "$OUTPUT_DIR/frames"

# ─── Duplicate detection ───
if [ "$FORCE" = false ] && [ -f "$OUTPUT_DIR/frame_index.json" ]; then
    echo "⚠️ Video $VIDEO_ID was already extracted."
    echo "   Output: $OUTPUT_DIR"
    echo "   Use --force to re-extract."
    exit 0
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎬 YouTube Skill Extractor"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📹 Video ID: $VIDEO_ID"
echo "📁 Output:   $OUTPUT_DIR"
echo ""

# ─── Step 1: Get video metadata ───
echo "📋 Step 1/4: Getting video metadata..."
if [ -f "$OUTPUT_DIR/metadata.json" ] && [ "$FORCE" = false ]; then
    echo "   ⏭️ Metadata already exists, skipping..."
else
    yt-dlp --dump-json --no-download "$URL" 2>/dev/null | OUTPUT_DIR="$OUTPUT_DIR" python3 -c '
import sys, json, os

output_dir = os.environ["OUTPUT_DIR"]
data = json.load(sys.stdin)
info = {
    "title": data.get("title", "Unknown"),
    "channel": data.get("channel", data.get("uploader", "Unknown")),
    "duration": data.get("duration", 0),
    "duration_string": data.get("duration_string", "Unknown"),
    "description": data.get("description", "")[:500],
    "view_count": data.get("view_count", 0),
    "upload_date": data.get("upload_date", "Unknown"),
    "language": data.get("language", "unknown"),
    "tags": data.get("tags", [])[:10],
    "categories": data.get("categories", [])
}
with open(os.path.join(output_dir, "metadata.json"), "w") as f:
    json.dump(info, f, ensure_ascii=False, indent=2)

dur_min = info["duration"] // 60
dur_sec = info["duration"] % 60
title = info["title"]
channel = info["channel"]
view_count = info["view_count"]
print(f"   Title:    {title}")
print(f"   Channel:  {channel}")
print(f"   Duration: {dur_min}m {dur_sec}s")
print(f"   Views:    {view_count:,}")
' || echo "   ⚠️ Metadata extraction failed"
fi

if [ ! -f "$OUTPUT_DIR/metadata.json" ]; then
    echo "   ❌ Failed to create metadata.json — video may be unavailable"
    exit 1
fi

# ─── Step 2: Download transcript/subtitles ───
echo ""
echo "📝 Step 2/4: Extracting transcript..."

if ls "$OUTPUT_DIR"/transcript_*.txt 1>/dev/null 2>&1 && [ "$FORCE" = false ]; then
    echo "   ⏭️ Transcript already exists, skipping..."
else
    TRANSCRIPT_OK=false

    # Try Thai subtitles
    yt-dlp --write-auto-sub --sub-lang th --skip-download --sub-format vtt \
        -o "$OUTPUT_DIR/subs" "$URL" 2>/dev/null && TRANSCRIPT_OK=true

    # Try English subtitles
    yt-dlp --write-auto-sub --sub-lang en --skip-download --sub-format vtt \
        -o "$OUTPUT_DIR/subs" "$URL" 2>/dev/null && TRANSCRIPT_OK=true

    # Try any available subtitles
    if [ "$TRANSCRIPT_OK" = false ]; then
        yt-dlp --write-auto-sub --skip-download --sub-format vtt \
            -o "$OUTPUT_DIR/subs" "$URL" 2>/dev/null && TRANSCRIPT_OK=true
    fi

    # Convert VTT to clean text
    if ls "$OUTPUT_DIR"/subs*.vtt 1>/dev/null 2>&1; then
    OUTPUT_DIR="$OUTPUT_DIR" python3 -c '
import glob, re, os

output_dir = os.environ["OUTPUT_DIR"]
vtt_files = glob.glob(os.path.join(output_dir, "subs*.vtt"))

for vtt_file in vtt_files:
    lang = "unknown"
    parts = vtt_file.rsplit(".", 2)
    if len(parts) >= 3:
        lang = parts[-2]

    with open(vtt_file, "r", encoding="utf-8") as f:
        content = f.read()

    lines = content.split("\n")
    text_lines = []
    seen = set()

    for line in lines:
        line = line.strip()
        if not line or line.startswith("WEBVTT") or line.startswith("Kind:") or line.startswith("Language:"):
            continue
        if "-->" in line:
            continue
        if line.isdigit():
            continue
        line = re.sub(r"<[^>]+>", "", line)
        if line not in seen:
            seen.add(line)
            text_lines.append(line)

    clean_text = "\n".join(text_lines)
    out_file = os.path.join(output_dir, f"transcript_{lang}.txt")
    with open(out_file, "w", encoding="utf-8") as f:
        f.write(clean_text)

    print(f"   ✅ Transcript ({lang}): {len(text_lines)} lines")
'

    # Generate timestamp mapping from VTT
    OUTPUT_DIR="$OUTPUT_DIR" python3 -c '
import glob, re, os, json

output_dir = os.environ["OUTPUT_DIR"]
vtt_files = glob.glob(os.path.join(output_dir, "subs*.vtt"))
all_entries = []

for vtt_file in vtt_files:
    with open(vtt_file, "r", encoding="utf-8") as f:
        content = f.read()

    lines = content.split("\n")
    seen = set()
    current_start = None
    current_end = None

    for line in lines:
        line_stripped = line.strip()
        if "-->" in line_stripped:
            # Parse timestamp line: 00:00:00.000 --> 00:00:03.500
            match = re.match(r"(\d+):(\d+):(\d+)\.(\d+)\s*-->\s*(\d+):(\d+):(\d+)\.(\d+)", line_stripped)
            if not match:
                # Try MM:SS.mmm format
                match = re.match(r"(\d+):(\d+)\.(\d+)\s*-->\s*(\d+):(\d+)\.(\d+)", line_stripped)
                if match:
                    g = match.groups()
                    current_start = int(g[0]) * 60 + int(g[1]) + int(g[2]) / (10 ** len(g[2]))
                    current_end = int(g[3]) * 60 + int(g[4]) + int(g[5]) / (10 ** len(g[5]))
            else:
                g = match.groups()
                current_start = int(g[0]) * 3600 + int(g[1]) * 60 + int(g[2]) + int(g[3]) / (10 ** len(g[3]))
                current_end = int(g[4]) * 3600 + int(g[5]) * 60 + int(g[6]) + int(g[7]) / (10 ** len(g[7]))
            continue

        if not line_stripped or line_stripped.startswith("WEBVTT") or line_stripped.startswith("Kind:") or line_stripped.startswith("Language:"):
            continue
        if line_stripped.isdigit():
            continue

        text = re.sub(r"<[^>]+>", "", line_stripped)
        if text and text not in seen and current_start is not None:
            seen.add(text)
            all_entries.append({
                "start": round(current_start, 2),
                "end": round(current_end, 2),
                "text": text
            })

out_file = os.path.join(output_dir, "transcript_timestamps.json")
with open(out_file, "w", encoding="utf-8") as f:
    json.dump(all_entries, f, ensure_ascii=False, indent=2)

print(f"   ✅ Timestamp map: {len(all_entries)} entries → transcript_timestamps.json")
'
    else
        # No VTT subtitles — try Whisper ASR as fallback
        echo "   🎙️  No subtitles found — trying Whisper ASR..."

        WHISPER_CMD=""
        if command -v whisper >/dev/null 2>&1; then
            WHISPER_CMD="cli"
        elif python3 -c "import whisper" 2>/dev/null; then
            WHISPER_CMD="python"
        fi

        if [ -n "$WHISPER_CMD" ]; then
            # Download audio only — much faster/smaller than full video
            echo "   📥 Downloading audio..."
            yt-dlp --extract-audio --audio-format mp3 --audio-quality 5 \
                -o "$OUTPUT_DIR/audio_tmp.%(ext)s" "$URL" 2>&1 | tail -2

            AUDIO_FILE=$(ls "$OUTPUT_DIR"/audio_tmp.* 2>/dev/null | head -1)

            if [ -n "$AUDIO_FILE" ] && [ -f "$AUDIO_FILE" ]; then
                echo "   🔄 Transcribing with Whisper (model: base)..."

                if [ "$WHISPER_CMD" = "cli" ]; then
                    whisper "$AUDIO_FILE" \
                        --output_dir "$OUTPUT_DIR" \
                        --output_format json \
                        --model base \
                        --verbose False 2>/dev/null || true
                    # Parse JSON → transcript_whisper.txt + transcript_timestamps.json
                    OUTPUT_DIR="$OUTPUT_DIR" AUDIO_FILE="$AUDIO_FILE" python3 << 'PYEOF'
import json, os

output_dir = os.environ["OUTPUT_DIR"]
audio_base = os.path.splitext(os.path.basename(os.environ["AUDIO_FILE"]))[0]
json_file = os.path.join(output_dir, audio_base + ".json")

if not os.path.exists(json_file):
    print("   ⚠️  Whisper JSON output not found")
else:
    with open(json_file) as f:
        data = json.load(f)

    # Plain text transcript
    txt_out = os.path.join(output_dir, "transcript_whisper.txt")
    with open(txt_out, "w", encoding="utf-8") as f:
        f.write(data.get("text", ""))

    # Timestamped segments
    segments = [
        {"start": round(s["start"], 2), "end": round(s["end"], 2), "text": s["text"].strip()}
        for s in data.get("segments", [])
    ]
    ts_out = os.path.join(output_dir, "transcript_timestamps.json")
    with open(ts_out, "w", encoding="utf-8") as f:
        json.dump(segments, f, ensure_ascii=False, indent=2)

    os.remove(json_file)
    word_count = len(data.get("text", "").split())
    print(f"   ✅ Whisper transcript: {word_count} words → transcript_whisper.txt")
    print(f"   ✅ Timestamp map: {len(segments)} segments → transcript_timestamps.json")
PYEOF
                else
                    # Python package
                    OUTPUT_DIR="$OUTPUT_DIR" AUDIO_FILE="$AUDIO_FILE" python3 << 'PYEOF'
import whisper, json, os

output_dir = os.environ["OUTPUT_DIR"]
audio_file = os.environ["AUDIO_FILE"]

model = whisper.load_model("base")
result = model.transcribe(audio_file)

txt_out = os.path.join(output_dir, "transcript_whisper.txt")
with open(txt_out, "w", encoding="utf-8") as f:
    f.write(result["text"])

segments = [
    {"start": round(s["start"], 2), "end": round(s["end"], 2), "text": s["text"].strip()}
    for s in result.get("segments", [])
]
ts_out = os.path.join(output_dir, "transcript_timestamps.json")
with open(ts_out, "w", encoding="utf-8") as f:
    json.dump(segments, f, ensure_ascii=False, indent=2)

word_count = len(result["text"].split())
print(f"   ✅ Whisper transcript: {word_count} words → transcript_whisper.txt")
print(f"   ✅ Timestamp map: {len(segments)} segments → transcript_timestamps.json")
PYEOF
                fi

                rm -f "$AUDIO_FILE"
            else
                echo "   ⚠️  Audio download failed — no transcript available"
            fi
        else
            echo "   ⚠️  No subtitles available. Install Whisper for ASR fallback:"
            echo "      pip install openai-whisper"
        fi
    fi
fi

# ─── Step 3: Extract frames via streaming (no full download) ───
echo ""
echo "🎞️  Step 3/4: Extracting frames (stream-based, no full download)..."

EXISTING_FRAMES=$(find "$OUTPUT_DIR/frames" -name "*.jpg" 2>/dev/null | wc -l | tr -d ' ')
if [ "$EXISTING_FRAMES" -gt 0 ] && [ "$FORCE" = false ]; then
    echo "   ⏭️ Frames already exist ($EXISTING_FRAMES files), skipping..."
else
    # Get duration from metadata (already fetched in Step 1)
    DURATION=$(python3 -c "
import json, sys
try:
    with open('$OUTPUT_DIR/metadata.json') as f:
        d = json.load(f)
    print(int(d.get('duration', 0)))
except Exception:
    print(0)
" 2>/dev/null)

    if [ -z "$DURATION" ] || [ "$DURATION" -eq 0 ]; then
        echo "   ❌ Could not determine video duration from metadata"
        exit 1
    fi

    echo "   ⏱️  Duration: ${DURATION}s ($(( DURATION / 60 ))m $(( DURATION % 60 ))s)"

    # Adaptive interval: target ~50 frames regardless of video length
    # Long videos get fewer frames per minute (content changes slower)
    if [ "$DURATION" -gt 7200 ]; then
        INTERVAL=150   # 1 frame/2.5min for > 2hr  (~48 frames)
    elif [ "$DURATION" -gt 3600 ]; then
        INTERVAL=90    # 1 frame/1.5min for > 1hr   (~40 frames)
    elif [ "$DURATION" -gt 1800 ]; then
        INTERVAL=45    # 1 frame/45s for > 30min    (~40 frames)
    elif [ "$DURATION" -gt 600 ]; then
        INTERVAL=20    # 1 frame/20s for > 10min    (~40 frames)
    else
        INTERVAL=10    # 1 frame/10s for < 10min    (~60 frames)
    fi

    echo "   ⏩ Interval: every ${INTERVAL}s"

    # Get direct stream URL — no download, just a URL for ffmpeg to seek into
    # Use 480p to reduce bandwidth; quality is sufficient for frame analysis
    echo "   🔗 Resolving stream URL..."
    STREAM_URL=$(yt-dlp -g \
        --format "bestvideo[height<=480][ext=mp4]/best[height<=480][ext=mp4]/best[height<=480]/best" \
        "$URL" 2>/dev/null | head -1)

    DOWNLOADED_FILE=""
    if [ -z "$STREAM_URL" ]; then
        echo "   ⚠️  Direct stream unavailable — downloading at lowest quality..."
        DOWNLOADED_FILE="$OUTPUT_DIR/video_tmp.mp4"
        yt-dlp -f "worstvideo[ext=mp4]+worstaudio/worst[ext=mp4]/worst" \
            --merge-output-format mp4 \
            -o "$DOWNLOADED_FILE" "$URL" 2>&1 | tail -3
        if [ ! -f "$DOWNLOADED_FILE" ]; then
            echo "   ❌ Download fallback also failed"
            exit 1
        fi
        STREAM_URL="$DOWNLOADED_FILE"
    fi

    # Extract one frame per interval using direct seek
    # -ss BEFORE -i forces keyframe seek (fast), then -vframes 1 grabs exactly 1 frame
    echo "   📸 Extracting frames..."
    FRAME_NUM=0
    FAILED=0
    for (( t=0; t<DURATION; t+=INTERVAL )); do
        PADDED=$(printf '%05d' "$FRAME_NUM")
        OUT="$OUTPUT_DIR/frames/frame_${PADDED}_t${t}.jpg"
        ffmpeg -ss "$t" -i "$STREAM_URL" \
            -vframes 1 -q:v 3 \
            -vf "scale=1280:720:force_original_aspect_ratio=decrease" \
            "$OUT" -y 2>/dev/null </dev/null
        if [ -f "$OUT" ]; then
            FRAME_NUM=$(( FRAME_NUM + 1 ))
        else
            FAILED=$(( FAILED + 1 ))
        fi
    done

    # Clean up temporary download if we fell back
    if [ -n "$DOWNLOADED_FILE" ] && [ -f "$DOWNLOADED_FILE" ]; then
        rm -f "$DOWNLOADED_FILE"
    fi

    FINAL_COUNT=$(find "$OUTPUT_DIR/frames" -name "*.jpg" 2>/dev/null | wc -l | tr -d ' ')
    echo "   ✅ Extracted $FINAL_COUNT frames${FAILED:+ ($FAILED failed seeks)}"
fi

FINAL_COUNT=$(find "$OUTPUT_DIR/frames" -name "*.jpg" 2>/dev/null | wc -l | tr -d ' ')

# ─── Step 4: Generate frame index with timestamps ───
echo ""
echo "📊 Step 4/4: Building frame index..."

if [ -f "$OUTPUT_DIR/frame_index.json" ] && [ "$FORCE" = false ]; then
    echo "   ⏭️ Frame index already exists, skipping..."
else
    OUTPUT_DIR="$OUTPUT_DIR" python3 -c '
import os, glob, json, re

output_dir = os.environ["OUTPUT_DIR"]
frames = sorted(glob.glob(os.path.join(output_dir, "frames", "*.jpg")))

index = []
for f in frames:
    fname = os.path.basename(f)
    size_kb = os.path.getsize(f) / 1024
    # Extract timestamp from filename: frame_00000_t120.jpg -> 120s
    ts_match = re.search(r"_t(\d+)\.jpg$", fname)
    timestamp_sec = int(ts_match.group(1)) if ts_match else None
    entry = {
        "file": fname,
        "path": f,
        "size_kb": round(size_kb, 1)
    }
    if timestamp_sec is not None:
        entry["timestamp_sec"] = timestamp_sec
        mins, secs = divmod(timestamp_sec, 60)
        entry["timestamp_str"] = f"{mins:02d}:{secs:02d}"
    index.append(entry)

with open(os.path.join(output_dir, "frame_index.json"), "w") as f:
    json.dump(index, f, indent=2)

print(f"   ✅ Frame index: {len(index)} frames indexed (with timestamps)")
'
fi

# ─── Summary ───
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Extraction Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 Output: $OUTPUT_DIR"
echo "📝 Transcripts: $(ls "$OUTPUT_DIR"/transcript_*.txt 2>/dev/null | wc -l | tr -d ' ') files"
echo "📸 Frames:      $FINAL_COUNT images"
echo "📋 Metadata:    metadata.json"
echo "📊 Index:       frame_index.json"
echo "🕐 Timestamps: transcript_timestamps.json"
echo ""
echo "🧠 Next: Claude will analyze frames + transcript → generate SKILL.md"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
