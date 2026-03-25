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
        echo "   ⚠️ No subtitles available — will rely on visual analysis only"
    fi
fi

# ─── Step 3: Download video + extract frames ───
echo ""
echo "🎞️  Step 3/4: Downloading video & extracting frames..."

EXISTING_FRAMES=$(ls "$OUTPUT_DIR/frames/"*.jpg 2>/dev/null | wc -l | tr -d ' ')
if [ "$EXISTING_FRAMES" -gt 0 ] && [ "$FORCE" = false ]; then
    echo "   ⏭️ Frames already exist ($EXISTING_FRAMES files), skipping..."
else
    # Download at 720p max to save space/time
    VIDEO_FILE="$OUTPUT_DIR/video.mp4"
    if [ ! -f "$VIDEO_FILE" ]; then
        yt-dlp -f "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720][ext=mp4]/best" \
            --merge-output-format mp4 \
            -o "$VIDEO_FILE" "$URL" 2>&1 | tail -3
    fi

    if [ ! -f "$VIDEO_FILE" ]; then
        echo "   ❌ Failed to download video"
        exit 1
    fi

    # Get video duration
    DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VIDEO_FILE" 2>/dev/null | cut -d. -f1)
    echo "   📹 Video downloaded: ${DURATION}s"

    # Strategy: Scene change detection + interval backup
    # Scene detection catches UI changes (menu clicks, page navigations)
    echo "   🔍 Detecting scene changes (UI transitions)..."

    # Scene change detection — captures when screen content changes significantly
    ffmpeg -i "$VIDEO_FILE" -vf "select='gt(scene,0.3)',showinfo" -vsync vfr \
        -frame_pts 1 "$OUTPUT_DIR/frames/scene_%04d.jpg" \
        2>&1 | grep "pts_time" | sed 's/.*pts_time:\([0-9.]*\).*/\1/' > "$OUTPUT_DIR/frames/scene_timestamps.txt" 2>/dev/null

    SCENE_COUNT=$(ls "$OUTPUT_DIR/frames/scene_"*.jpg 2>/dev/null | wc -l | tr -d ' ')
    echo "   📸 Scene changes detected: $SCENE_COUNT frames"

    # If too few scene changes (<10), add interval-based frames as backup
    if [ "$SCENE_COUNT" -lt 10 ]; then
        echo "   📸 Adding interval frames (every 15s) as backup..."
        INTERVAL=15
        if [ "$DURATION" -gt 1800 ]; then
            INTERVAL=30  # 30s for videos > 30min
        fi
        ffmpeg -i "$VIDEO_FILE" -vf "fps=1/$INTERVAL" \
            "$OUTPUT_DIR/frames/interval_%04d.jpg" 2>/dev/null
    fi

    # If too many frames (>80), keep only top 80 by selecting evenly
    TOTAL_FRAMES=$(ls "$OUTPUT_DIR/frames/"*.jpg 2>/dev/null | wc -l | tr -d ' ')
    if [ "$TOTAL_FRAMES" -gt 80 ]; then
        echo "   ✂️  Too many frames ($TOTAL_FRAMES), selecting top 80..."
        OUTPUT_DIR="$OUTPUT_DIR" python3 -c '
import os, glob

output_dir = os.environ["OUTPUT_DIR"]
frames = sorted(glob.glob(os.path.join(output_dir, "frames", "*.jpg")))
total = len(frames)
keep = 80
step = total / keep
keep_indices = set(int(i * step) for i in range(keep))
for i, f in enumerate(frames):
    if i not in keep_indices:
        os.remove(f)
print(f"   📸 Reduced to {len(keep_indices)} frames")
'
    fi

    # Clean up video file to save space (as per SKILL.md policy)
    echo "   🗑️  Cleaning up video file..."
    rm -f "$VIDEO_FILE"
fi

FINAL_COUNT=$(ls "$OUTPUT_DIR/frames/"*.jpg 2>/dev/null | wc -l | tr -d ' ')

# ─── Step 4: Generate frame index with timestamps ───
echo ""
echo "📊 Step 4/4: Building frame index..."

if [ -f "$OUTPUT_DIR/frame_index.json" ] && [ "$FORCE" = false ]; then
    echo "   ⏭️ Frame index already exists, skipping..."
else
    OUTPUT_DIR="$OUTPUT_DIR" python3 -c '
import os, glob, json

output_dir = os.environ["OUTPUT_DIR"]
frames = sorted(glob.glob(os.path.join(output_dir, "frames", "*.jpg")))

index = []
for f in frames:
    fname = os.path.basename(f)
    size_kb = os.path.getsize(f) / 1024
    index.append({
        "file": fname,
        "path": f,
        "size_kb": round(size_kb, 1)
    })

with open(os.path.join(output_dir, "frame_index.json"), "w") as f:
    json.dump(index, f, indent=2)

print(f"   ✅ Frame index: {len(index)} frames indexed")
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
