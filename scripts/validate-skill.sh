#!/bin/bash
# Validate a generated SKILL.md against quality standards
# Usage: ./validate-skill.sh <path-to-skill.md>
# Returns: exit 0 if valid, exit 1 if issues found

set -eo pipefail

SKILL_FILE="$1"

if [ -z "$SKILL_FILE" ] || [ ! -f "$SKILL_FILE" ]; then
    echo "❌ Usage: ./validate-skill.sh <path-to-skill.md>"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 SKILL.md Quality Validator"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📄 File: $SKILL_FILE"
echo ""

PASS=0
FAIL=0
WARN=0

check_pass() { echo "   ✅ $1"; PASS=$((PASS + 1)); }
check_fail() { echo "   ❌ $1"; FAIL=$((FAIL + 1)); }
check_warn() { echo "   ⚠️  $1"; WARN=$((WARN + 1)); }

# ─── 1. Frontmatter Check ───
echo "📋 Frontmatter:"
if head -1 "$SKILL_FILE" | grep -q "^---"; then
    check_pass "Has frontmatter"
else
    check_fail "Missing frontmatter (---)"
fi

if grep -q "^name:" "$SKILL_FILE"; then
    check_pass "Has 'name' field"
else
    check_fail "Missing 'name' field"
fi

if grep -q "^description:" "$SKILL_FILE"; then
    check_pass "Has 'description' field"
else
    check_fail "Missing 'description' field"
fi

# ─── 2. Required Sections ───
echo ""
echo "📑 Required Sections:"

SECTIONS=("Quick Reference" "Knowledge Base:Core Concepts" "Step-by-Step:Workflows" "UI Navigation" "Common Issues:Solutions" "Pro Tips" "Source Attribution")
SECTION_PATTERNS=("Quick Reference|## Quick" "Core Concepts|Knowledge Base" "Step-by-Step|Workflow" "UI Navigation|Navigation Guide|Menu Structure" "Common Issues|Solutions|Troubleshooting" "Pro Tips|Tips" "Source Attribution|Source|Attribution")

for i in "${!SECTIONS[@]}"; do
    SECTION="${SECTIONS[$i]}"
    PATTERN="${SECTION_PATTERNS[$i]}"
    if grep -qiE "$PATTERN" "$SKILL_FILE"; then
        check_pass "Has '$SECTION' section"
    else
        check_fail "Missing '$SECTION' section"
    fi
done

# ─── 3. Actionability Check ───
echo ""
echo "🎯 Actionability:"

# Check for step-by-step instructions (Step 1, Step 2, etc.)
STEP_COUNT=$(grep -ciE "(step [0-9]|#### step|### step)" "$SKILL_FILE" || true)
if [ "$STEP_COUNT" -gt 0 ]; then
    check_pass "Has step-by-step instructions ($STEP_COUNT steps found)"
else
    check_fail "No step-by-step instructions found"
fi

# Check for UI location references
UI_REFS=$(grep -ciE "(เมนู|ปุ่ม|menu|button|click|กด|ไปที่|navigate|tab|sidebar|toolbar)" "$SKILL_FILE" || true)
if [ "$UI_REFS" -gt 2 ]; then
    check_pass "Has UI location references ($UI_REFS found)"
elif [ "$UI_REFS" -gt 0 ]; then
    check_warn "Few UI location references ($UI_REFS found, recommend more)"
else
    check_fail "No UI location references found"
fi

# ─── 4. Attribution Check ───
echo ""
echo "📝 Attribution:"

if grep -qiE "(youtube\.com|youtu\.be)" "$SKILL_FILE"; then
    check_pass "Has YouTube source link"
else
    check_fail "Missing YouTube source link"
fi

if grep -qiE "(channel|ช่อง)" "$SKILL_FILE"; then
    check_pass "Has channel/instructor credit"
else
    check_fail "Missing channel/instructor credit"
fi

# ─── 5. Completeness Check ───
echo ""
echo "📊 Completeness:"

WORD_COUNT=$(wc -w < "$SKILL_FILE" | tr -d ' ')
if [ "$WORD_COUNT" -gt 500 ]; then
    check_pass "Content length: $WORD_COUNT words (sufficient)"
elif [ "$WORD_COUNT" -gt 200 ]; then
    check_warn "Content length: $WORD_COUNT words (might be thin)"
else
    check_fail "Content length: $WORD_COUNT words (too short)"
fi

TABLE_COUNT=$(grep -c "|.*|.*|" "$SKILL_FILE" || true)
if [ "$TABLE_COUNT" -gt 2 ]; then
    check_pass "Has tables for structured data ($TABLE_COUNT rows)"
else
    check_warn "Few tables ($TABLE_COUNT rows) — consider adding more structured data"
fi

# ─── Summary ───
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
TOTAL=$((PASS + FAIL + WARN))
echo "📊 Results: $PASS passed, $FAIL failed, $WARN warnings (of $TOTAL checks)"

if [ "$FAIL" -eq 0 ]; then
    echo "✅ SKILL.md passes quality standards!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
else
    echo "❌ SKILL.md needs improvements ($FAIL issues found)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi
