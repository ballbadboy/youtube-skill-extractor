#!/bin/bash
# Extract all videos from a YouTube playlist
# Usage: ./playlist-extract.sh <playlist-url> [--force]
# Dependencies: yt-dlp

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BATCH_SCRIPT="$SCRIPT_DIR/batch-extract.sh"

# Check dependencies
if ! command -v yt-dlp >/dev/null 2>&1; then
    echo "❌ Required command 'yt-dlp' not found. Please install it."
    exit 1
fi

# Parse args
PLAYLIST_URL=""
FORCE_FLAG=""
for arg in "$@"; do
    if [ "$arg" = "--force" ]; then
        FORCE_FLAG="--force"
    elif [ -z "$PLAYLIST_URL" ]; then
        PLAYLIST_URL="$arg"
    fi
done

if [ -z "$PLAYLIST_URL" ]; then
    echo "❌ Usage: ./playlist-extract.sh <playlist-url> [--force]"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Playlist Extractor"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔗 Playlist: $PLAYLIST_URL"
echo ""
echo "📥 Fetching video list from playlist..."

# Get all video URLs from playlist
URLS=$(yt-dlp --flat-playlist --print url "$PLAYLIST_URL" 2>/dev/null)

if [ -z "$URLS" ]; then
    echo "❌ No videos found in playlist (or invalid URL)"
    exit 1
fi

VIDEO_COUNT=$(echo "$URLS" | wc -l | tr -d ' ')
echo "📹 Found $VIDEO_COUNT videos in playlist"
echo ""

# Pass all URLs to batch-extract
# shellcheck disable=SC2086
"$BATCH_SCRIPT" $URLS $FORCE_FLAG
