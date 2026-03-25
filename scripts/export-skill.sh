#!/bin/bash
# Export a generated skill as a shareable package
# Usage: ./export-skill.sh <video-id> [output-dir] [--include-frames]
# Creates: <skill-name>.skill.zip containing SKILL.md + metadata

set -eo pipefail

OUTPUT_BASE="${HOME}/.claude/skills/youtube-skill-extractor/output"

# Parse args
VIDEO_ID=""
EXPORT_DIR=""
INCLUDE_FRAMES=false
for arg in "$@"; do
    if [ "$arg" = "--include-frames" ]; then
        INCLUDE_FRAMES=true
    elif [ -z "$VIDEO_ID" ]; then
        VIDEO_ID="$arg"
    elif [ -z "$EXPORT_DIR" ]; then
        EXPORT_DIR="$arg"
    fi
done

EXPORT_DIR="${EXPORT_DIR:-.}"

if [ -z "$VIDEO_ID" ]; then
    echo "❌ Usage: ./export-skill.sh <video-id> [output-dir] [--include-frames]"
    exit 1
fi

SOURCE_DIR="$OUTPUT_BASE/$VIDEO_ID"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ Video not found: $VIDEO_ID"
    echo "   Expected: $SOURCE_DIR"
    exit 1
fi

if [ ! -f "$SOURCE_DIR/SKILL.md" ]; then
    echo "❌ No SKILL.md found for video $VIDEO_ID"
    echo "   Run generate first: /youtube-skill-extractor generate $VIDEO_ID"
    exit 1
fi

# Get skill name from SKILL.md frontmatter
SKILL_NAME=$(grep "^name:" "$SOURCE_DIR/SKILL.md" 2>/dev/null | head -1 | sed 's/^name:[[:space:]]*//' || echo "$VIDEO_ID")
SKILL_NAME=$(echo "$SKILL_NAME" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]//g')
if [ -z "$SKILL_NAME" ]; then
    SKILL_NAME="$VIDEO_ID"
fi

PACKAGE_DIR=$(mktemp -d)
PACKAGE_NAME="${SKILL_NAME}.skill"
mkdir -p "$PACKAGE_DIR/$PACKAGE_NAME"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Skill Exporter"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📹 Video ID: $VIDEO_ID"
echo "📄 Skill:    $SKILL_NAME"
echo ""

# Copy SKILL.md
cp "$SOURCE_DIR/SKILL.md" "$PACKAGE_DIR/$PACKAGE_NAME/SKILL.md"
echo "   ✅ SKILL.md"

# Copy metadata if exists
if [ -f "$SOURCE_DIR/metadata.json" ]; then
    cp "$SOURCE_DIR/metadata.json" "$PACKAGE_DIR/$PACKAGE_NAME/metadata.json"
    echo "   ✅ metadata.json"
fi

# Copy analysis if exists
if [ -f "$SOURCE_DIR/analysis.md" ]; then
    cp "$SOURCE_DIR/analysis.md" "$PACKAGE_DIR/$PACKAGE_NAME/analysis.md"
    echo "   ✅ analysis.md"
fi

# Optionally include frames
if [ "$INCLUDE_FRAMES" = true ] && [ -d "$SOURCE_DIR/frames" ]; then
    mkdir -p "$PACKAGE_DIR/$PACKAGE_NAME/frames"
    cp "$SOURCE_DIR/frames/"*.jpg "$PACKAGE_DIR/$PACKAGE_NAME/frames/" 2>/dev/null
    FRAME_COUNT=$(ls "$PACKAGE_DIR/$PACKAGE_NAME/frames/"*.jpg 2>/dev/null | wc -l | tr -d ' ')
    echo "   ✅ frames/ ($FRAME_COUNT images)"
fi

# Create package manifest
EXPORT_DATE=$(date +%Y-%m-%d)
cat > "$PACKAGE_DIR/$PACKAGE_NAME/manifest.json" << MANIFEST_EOF
{
  "format": "youtube-skill-extractor-package",
  "version": "1.0",
  "skill_name": "$SKILL_NAME",
  "video_id": "$VIDEO_ID",
  "exported": "$EXPORT_DATE",
  "includes_frames": $INCLUDE_FRAMES
}
MANIFEST_EOF
echo "   ✅ manifest.json"

# Create zip
ZIP_FILE="$EXPORT_DIR/${PACKAGE_NAME}.zip"
(cd "$PACKAGE_DIR" && zip -r "$ZIP_FILE" "$PACKAGE_NAME" -x "*.DS_Store") > /dev/null 2>&1

# Cleanup temp dir
rm -rf "$PACKAGE_DIR"

ZIP_SIZE=$(du -h "$ZIP_FILE" | cut -f1 | tr -d ' ')

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Exported: $ZIP_FILE ($ZIP_SIZE)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📤 Share this file or import with:"
echo "   ./import-skill.sh $ZIP_FILE"
