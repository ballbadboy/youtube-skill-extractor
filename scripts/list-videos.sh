#!/bin/bash
# List all extracted videos and their status
# Usage: ./list-videos.sh [output-dir]

OUTPUT_BASE="${1:-$HOME/.claude/skills/youtube-skill-extractor/output}"

if [ ! -d "$OUTPUT_BASE" ]; then
    echo "📭 No videos extracted yet."
    echo "   Output directory: $OUTPUT_BASE"
    exit 0
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Extracted Videos"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

COUNT=0
for dir in "$OUTPUT_BASE"/*/; do
    [ -d "$dir" ] || continue
    VIDEO_ID=$(basename "$dir")
    COUNT=$((COUNT + 1))

    # Read title from metadata
    TITLE="(no metadata)"
    if [ -f "$dir/metadata.json" ]; then
        TITLE=$(META_FILE="$dir/metadata.json" python3 -c 'import json,os; d=json.load(open(os.environ["META_FILE"])); print(d.get("title","Unknown"))' 2>/dev/null || echo "Unknown")
    fi

    # Check status of each component
    HAS_META="❌"
    HAS_TRANSCRIPT="❌"
    HAS_FRAMES="❌"
    HAS_ANALYSIS="❌"
    HAS_SKILL="❌"
    FRAME_COUNT=0
    TRANSCRIPT_LANGS=""

    [ -f "$dir/metadata.json" ] && HAS_META="✅"

    # Count transcripts and languages
    for tf in "$dir"/transcript_*.txt; do
        [ -f "$tf" ] || continue
        HAS_TRANSCRIPT="✅"
        lang=$(basename "$tf" | sed 's/transcript_//;s/\.txt//')
        TRANSCRIPT_LANGS="${TRANSCRIPT_LANGS}${lang} "
    done

    if ls "$dir"/frames/*.jpg 1>/dev/null 2>&1; then
        HAS_FRAMES="✅"
        FRAME_COUNT=$(ls "$dir"/frames/*.jpg 2>/dev/null | wc -l | tr -d ' ')
    fi

    [ -f "$dir/analysis.md" ] && HAS_ANALYSIS="✅"
    [ -f "$dir/SKILL.md" ] && HAS_SKILL="✅"

    echo "📹 $VIDEO_ID"
    echo "   Title: $TITLE"
    echo "   Meta: $HAS_META | Transcript: $HAS_TRANSCRIPT ($TRANSCRIPT_LANGS) | Frames: $HAS_FRAMES ($FRAME_COUNT) | Analysis: $HAS_ANALYSIS | SKILL: $HAS_SKILL"
    echo ""
done

if [ "$COUNT" -eq 0 ]; then
    echo "📭 No videos found in $OUTPUT_BASE"
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Total: $COUNT videos"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi
