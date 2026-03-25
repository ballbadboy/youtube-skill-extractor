#!/bin/bash
# Check if extracted videos have been updated on YouTube
# Usage: ./check-update.sh [video-id] [--all]
# Compares stored metadata with current YouTube metadata

set -eo pipefail

OUTPUT_BASE="${HOME}/.claude/skills/youtube-skill-extractor/output"

# Check dependencies
if ! command -v yt-dlp >/dev/null 2>&1; then
    echo "❌ Required: yt-dlp (brew install yt-dlp)"
    exit 1
fi

CHECK_ALL=false
VIDEO_ID=""
for arg in "$@"; do
    if [ "$arg" = "--all" ]; then
        CHECK_ALL=true
    elif [ -z "$VIDEO_ID" ]; then
        VIDEO_ID="$arg"
    fi
done

if [ -z "$VIDEO_ID" ] && [ "$CHECK_ALL" = false ]; then
    echo "❌ Usage: ./check-update.sh <video-id> or ./check-update.sh --all"
    exit 1
fi

check_video() {
    local vid="$1"
    local dir="$OUTPUT_BASE/$vid"

    if [ ! -f "$dir/metadata.json" ]; then
        echo "   ⚠️  No metadata found for $vid"
        return
    fi

    # Get stored metadata
    local stored_title stored_views stored_duration
    stored_title=$(META="$dir/metadata.json" python3 -c 'import json,os; d=json.load(open(os.environ["META"])); print(d.get("title",""))' 2>/dev/null)
    stored_views=$(META="$dir/metadata.json" python3 -c 'import json,os; d=json.load(open(os.environ["META"])); print(d.get("view_count",0))' 2>/dev/null)
    stored_duration=$(META="$dir/metadata.json" python3 -c 'import json,os; d=json.load(open(os.environ["META"])); print(d.get("duration",0))' 2>/dev/null)

    # Get current metadata from YouTube
    local current_json
    current_json=$(yt-dlp --dump-json --no-download "https://www.youtube.com/watch?v=$vid" 2>/dev/null) || {
        echo "   ❌ Cannot fetch: $vid (video may be deleted or private)"
        return
    }

    local current_title current_views current_duration
    current_title=$(echo "$current_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("title",""))' 2>/dev/null)
    current_views=$(echo "$current_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("view_count",0))' 2>/dev/null)
    current_duration=$(echo "$current_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("duration",0))' 2>/dev/null)

    # Compare
    local changed=false

    if [ "$stored_title" != "$current_title" ]; then
        echo "   📝 Title changed: \"$stored_title\" → \"$current_title\""
        changed=true
    fi

    if [ "$stored_duration" != "$current_duration" ]; then
        echo "   ⏱️  Duration changed: ${stored_duration}s → ${current_duration}s (video re-uploaded?)"
        changed=true
    fi

    if [ "$changed" = false ]; then
        local view_diff=$((current_views - stored_views))
        echo "   ✅ No changes detected (views: +$view_diff since extraction)"
    else
        echo "   🔄 Re-extract recommended: /youtube-skill-extractor https://youtube.com/watch?v=$vid --force"
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Video Update Checker"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$CHECK_ALL" = true ]; then
    if [ ! -d "$OUTPUT_BASE" ]; then
        echo "📭 No videos extracted yet."
        exit 0
    fi

    COUNT=0
    for dir in "$OUTPUT_BASE"/*/; do
        [ -d "$dir" ] || continue
        vid=$(basename "$dir")
        COUNT=$((COUNT + 1))
        echo "📹 $vid"
        check_video "$vid"
        echo ""
    done

    if [ "$COUNT" -eq 0 ]; then
        echo "📭 No videos found."
    else
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📊 Checked $COUNT videos"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
else
    echo "📹 $VIDEO_ID"
    check_video "$VIDEO_ID"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi
