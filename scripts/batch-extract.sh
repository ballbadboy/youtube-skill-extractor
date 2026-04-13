#!/bin/bash
# Batch extract multiple YouTube videos
# Usage: ./batch-extract.sh <url1> <url2> [url3] ... [--force]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXTRACT_SCRIPT="$SCRIPT_DIR/extract.sh"

if [ $# -eq 0 ]; then
    echo "❌ Usage: ./batch-extract.sh <url1> <url2> [url3] ... [--force]"
    exit 1
fi

# Separate URLs from flags
URLS=()
FORCE_FLAG=""
for arg in "$@"; do
    if [ "$arg" = "--force" ]; then
        FORCE_FLAG="--force"
    else
        URLS+=("$arg")
    fi
done

if [ ${#URLS[@]} -eq 0 ]; then
    echo "❌ No URLs provided"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎬 Batch YouTube Skill Extractor"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📹 Videos: ${#URLS[@]}"
echo ""

TOTAL=${#URLS[@]}
SUCCESS=0
FAILED=0

for i in "${!URLS[@]}"; do
    NUM=$((i + 1))
    URL="${URLS[$i]}"
    echo "━━━ [$NUM/$TOTAL] $URL ━━━"

    if "$EXTRACT_SCRIPT" "$URL" "" $FORCE_FLAG; then
        SUCCESS=$((SUCCESS + 1))
        echo "   ✅ Success"
    else
        FAILED=$((FAILED + 1))
        echo "   ❌ Failed"
    fi
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Batch Complete: $SUCCESS success, $FAILED failed (of $TOTAL)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
