#!/bin/bash
# YouTube Skill Extractor — ดึง transcript + frames จาก YouTube video
# Usage: ./extract.sh <youtube-url> [output-dir]
# Dependencies: yt-dlp, ffmpeg

set -e

URL="$1"
OUTPUT_BASE="${2:-$HOME/.claude/skills/youtube-skill-extractor/output}"

if [ -z "$URL" ]; then
    echo "❌ Usage: ./extract.sh <youtube-url> [output-dir]"
    exit 1
fi

# Extract video ID
VIDEO_ID=$(echo "$URL" | grep -oP '(?:v=|youtu\.be/|shorts/)([a-zA-Z0-9_-]{11})' | head -1 | sed 's/.*[=/]//')
if [ -z "$VIDEO_ID" ]; then
    # Try alternative pattern for macOS (no -P in grep)
    VIDEO_ID=$(echo "$URL" | sed -n 's/.*[?&]v=\([a-zA-Z0-9_-]\{11\}\).*/\1/p')
fi
if [ -z "$VIDEO_ID" ]; then
    VIDEO_ID=$(echo "$URL" | sed -n 's/.*youtu\.be\/\([a-zA-Z0-9_-]\{11\}\).*/\1/p')
fi
if [ -z "$VIDEO_ID" ]; then
    echo "❌ Cannot extract video ID from URL: $URL"
    exit 1
fi

OUTPUT_DIR="$OUTPUT_BASE/$VIDEO_ID"
mkdir -p "$OUTPUT_DIR/frames"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎬 YouTube Skill Extractor"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📹 Video ID: $VIDEO_ID"
echo "📁 Output:   $OUTPUT_DIR"
echo ""

# ─── Step 1: Get video metadata ───
echo "📋 Step 1/4: Getting video metadata..."
yt-dlp --dump-json --no-download "$URL" 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
info = {
    'title': data.get('title', 'Unknown'),
    'channel': data.get('channel', data.get('uploader', 'Unknown')),
    'duration': data.get('duration', 0),
    'duration_string': data.get('duration_string', 'Unknown'),
    'description': data.get('description', '')[:500],
    'view_count': data.get('view_count', 0),
    'upload_date': data.get('upload_date', 'Unknown'),
    'language': data.get('language', 'unknown'),
    'tags': data.get('tags', [])[:10],
    'categories': data.get('categories', [])
}
with open('$OUTPUT_DIR/metadata.json', 'w') as f:
    json.dump(info, f, ensure_ascii=False, indent=2)

# Human-readable summary
dur_min = info['duration'] // 60
dur_sec = info['duration'] % 60
print(f\"   Title:    {info['title']}\")
print(f\"   Channel:  {info['channel']}\")
print(f\"   Duration: {dur_min}m {dur_sec}s\")
print(f\"   Views:    {info['view_count']:,}\")
" 2>/dev/null || echo "   ⚠️ Metadata extraction partial"

# ─── Step 2: Download transcript/subtitles ───
echo ""
echo "📝 Step 2/4: Extracting transcript..."

# Try auto-generated subtitles first (most YouTube videos have these)
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
    python3 << 'PYEOF'
import glob, re, os

output_dir = os.path.expanduser("OUTPUT_DIR_PLACEHOLDER")
vtt_files = glob.glob(os.path.join(output_dir, "subs*.vtt"))

for vtt_file in vtt_files:
    lang = "unknown"
    # Extract language from filename
    parts = vtt_file.rsplit(".", 2)
    if len(parts) >= 3:
        lang = parts[-2]

    with open(vtt_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Remove VTT headers and timestamps
    lines = content.split('\n')
    text_lines = []
    seen = set()

    for line in lines:
        line = line.strip()
        # Skip headers, timestamps, and empty lines
        if not line or line.startswith('WEBVTT') or line.startswith('Kind:') or line.startswith('Language:'):
            continue
        if '-->' in line:
            continue
        if line.isdigit():
            continue
        # Remove HTML tags
        line = re.sub(r'<[^>]+>', '', line)
        # Remove duplicate lines (auto-subs repeat a lot)
        if line not in seen:
            seen.add(line)
            text_lines.append(line)

    clean_text = '\n'.join(text_lines)
    out_file = os.path.join(output_dir, f"transcript_{lang}.txt")
    with open(out_file, 'w', encoding='utf-8') as f:
        f.write(clean_text)

    print(f"   ✅ Transcript ({lang}): {len(text_lines)} lines → {out_file}")
PYEOF
    # Fix placeholder
    sed -i '' "s|OUTPUT_DIR_PLACEHOLDER|$OUTPUT_DIR|g" /dev/stdin 2>/dev/null || true

    # Actually run the python with correct path
    python3 -c "
import glob, re, os

output_dir = '$OUTPUT_DIR'
vtt_files = glob.glob(os.path.join(output_dir, 'subs*.vtt'))

for vtt_file in vtt_files:
    lang = 'unknown'
    parts = vtt_file.rsplit('.', 2)
    if len(parts) >= 3:
        lang = parts[-2]

    with open(vtt_file, 'r', encoding='utf-8') as f:
        content = f.read()

    lines = content.split('\n')
    text_lines = []
    seen = set()

    for line in lines:
        line = line.strip()
        if not line or line.startswith('WEBVTT') or line.startswith('Kind:') or line.startswith('Language:'):
            continue
        if '-->' in line:
            continue
        if line.isdigit():
            continue
        line = re.sub(r'<[^>]+>', '', line)
        if line not in seen:
            seen.add(line)
            text_lines.append(line)

    clean_text = '\n'.join(text_lines)
    out_file = os.path.join(output_dir, f'transcript_{lang}.txt')
    with open(out_file, 'w', encoding='utf-8') as f:
        f.write(clean_text)

    print(f'   ✅ Transcript ({lang}): {len(text_lines)} lines')
"
else
    echo "   ⚠️ No subtitles available — will rely on visual analysis only"
fi

# ─── Step 3: Download video + extract frames ───
echo ""
echo "🎞️  Step 3/4: Downloading video & extracting frames..."

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

# If too many scene changes (>100), keep only top 80 by selecting evenly
TOTAL_FRAMES=$(ls "$OUTPUT_DIR/frames/"*.jpg 2>/dev/null | wc -l | tr -d ' ')
if [ "$TOTAL_FRAMES" -gt 80 ]; then
    echo "   ✂️  Too many frames ($TOTAL_FRAMES), selecting top 80..."
    # Keep evenly spaced frames
    python3 -c "
import os, glob
frames = sorted(glob.glob('$OUTPUT_DIR/frames/*.jpg'))
total = len(frames)
keep = 80
step = total / keep
keep_indices = set(int(i * step) for i in range(keep))
for i, f in enumerate(frames):
    if i not in keep_indices:
        os.remove(f)
print(f'   📸 Reduced to {len(keep_indices)} frames')
"
fi

FINAL_COUNT=$(ls "$OUTPUT_DIR/frames/"*.jpg 2>/dev/null | wc -l | tr -d ' ')

# ─── Step 4: Generate frame index with timestamps ───
echo ""
echo "📊 Step 4/4: Building frame index..."

python3 -c "
import os, glob, json

output_dir = '$OUTPUT_DIR'
frames = sorted(glob.glob(os.path.join(output_dir, 'frames', '*.jpg')))

index = []
for f in frames:
    fname = os.path.basename(f)
    size_kb = os.path.getsize(f) / 1024
    index.append({
        'file': fname,
        'path': f,
        'size_kb': round(size_kb, 1)
    })

with open(os.path.join(output_dir, 'frame_index.json'), 'w') as f:
    json.dump(index, f, indent=2)

print(f'   ✅ Frame index: {len(index)} frames indexed')
"

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
echo ""
echo "🧠 Next: Claude will analyze frames + transcript → generate SKILL.md"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
