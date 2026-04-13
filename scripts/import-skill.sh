#!/bin/bash
# Import a shared skill package
# Usage: ./import-skill.sh <package.skill.zip> [--install]
# Extracts and optionally installs to ~/.claude/skills/

set -eo pipefail

ZIP_FILE=""
AUTO_INSTALL=false
for arg in "$@"; do
    if [ "$arg" = "--install" ]; then
        AUTO_INSTALL=true
    elif [ -z "$ZIP_FILE" ]; then
        ZIP_FILE="$arg"
    fi
done

if [ -z "$ZIP_FILE" ] || [ ! -f "$ZIP_FILE" ]; then
    echo "❌ Usage: ./import-skill.sh <package.skill.zip> [--install]"
    exit 1
fi

# Check it's a zip
if ! file "$ZIP_FILE" | grep -qi "zip"; then
    echo "❌ File is not a zip archive: $ZIP_FILE"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📥 Skill Importer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Package: $ZIP_FILE"
echo ""

# Extract to temp dir
TEMP_DIR=$(mktemp -d)
unzip -q "$ZIP_FILE" -d "$TEMP_DIR"

# Find the .skill directory
SKILL_DIR=$(find "$TEMP_DIR" -name "*.skill" -type d | head -1)

if [ -z "$SKILL_DIR" ]; then
    echo "❌ Invalid package: no .skill directory found"
    rm -rf "$TEMP_DIR"
    exit 1
fi

SKILL_NAME=$(basename "$SKILL_DIR" .skill)

# Validate package
if [ ! -f "$SKILL_DIR/SKILL.md" ]; then
    echo "❌ Invalid package: missing SKILL.md"
    rm -rf "$TEMP_DIR"
    exit 1
fi

if [ ! -f "$SKILL_DIR/manifest.json" ]; then
    echo "❌ Invalid package: missing manifest.json"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Show package info
echo "📋 Package Info:"
if command -v python3 >/dev/null 2>&1; then
    MANIFEST="$SKILL_DIR/manifest.json" python3 -c '
import json, os
m = json.load(open(os.environ["MANIFEST"]))
print(f"   Name:     {m.get(\"skill_name\", \"unknown\")}")
print(f"   Video:    {m.get(\"video_id\", \"unknown\")}")
print(f"   Exported: {m.get(\"exported\", \"unknown\")}")
print(f"   Frames:   {\"yes\" if m.get(\"includes_frames\") else \"no\"}")
' 2>/dev/null || echo "   (could not read manifest)"
fi

# List contents
echo ""
echo "📄 Contents:"
[ -f "$SKILL_DIR/SKILL.md" ] && echo "   ✅ SKILL.md"
[ -f "$SKILL_DIR/metadata.json" ] && echo "   ✅ metadata.json"
[ -f "$SKILL_DIR/analysis.md" ] && echo "   ✅ analysis.md"
if [ -d "$SKILL_DIR/frames" ]; then
    FC=$(ls "$SKILL_DIR/frames/"*.jpg 2>/dev/null | wc -l | tr -d ' ')
    echo "   ✅ frames/ ($FC images)"
fi

# Install if requested
if [ "$AUTO_INSTALL" = true ]; then
    INSTALL_DIR="$HOME/.claude/skills/$SKILL_NAME"
    mkdir -p "$INSTALL_DIR"
    cp "$SKILL_DIR/SKILL.md" "$INSTALL_DIR/SKILL.md"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Installed to: $INSTALL_DIR"
    echo "   Restart Claude Code to use: /$SKILL_NAME"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📂 Extracted to: $SKILL_DIR"
    echo ""
    echo "To install, run:"
    echo "   ./import-skill.sh $ZIP_FILE --install"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

# Cleanup only if installed
if [ "$AUTO_INSTALL" = true ]; then
    rm -rf "$TEMP_DIR"
fi
