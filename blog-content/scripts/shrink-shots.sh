#!/usr/bin/env bash
# shrink-shots.sh — take a directory of user-provided screenshots,
# shrink them to web-friendly size, and copy to the blog's public dir.
# Filenames remain unchanged here — the agent (or user) renames them
# based on content after seeing the previews.
#
# Usage:
#   bash shrink-shots.sh --src <SRC_DIR> --slug <SLUG> [--width 900]
#
# What it does:
#   1. For each file in SRC_DIR that is a PNG/JPG/JPEG (even without extension):
#      - shrink to <WIDTH> px width via sharp
#      - save as /tmp/imgwork/preview-<basename>.jpg for agent review
#   2. Pause and let agent inspect previews
#   3. Agent renames + uploads to DO via separate scp commands
#
# This script intentionally does NOT rename or upload — that's a content
# decision (e.g. shot-pr-list.png vs shot-issue-list.png) that needs the
# agent to see what's actually in each screenshot.

set -eu

SRC=""
SLUG=""
WIDTH=900

while [ $# -gt 0 ]; do
  case "$1" in
    --src) SRC="$2"; shift 2 ;;
    --slug) SLUG="$2"; shift 2 ;;
    --width) WIDTH="$2"; shift 2 ;;
    -h|--help)
      grep -E '^#' "$0" | sed 's/^# \?//'
      exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -z "$SRC" ] || [ -z "$SLUG" ] && {
  echo "usage: $0 --src <SRC_DIR> --slug <SLUG> [--width 900]" >&2
  exit 2
}

[ -d "$SRC" ] || { echo "source dir not found: $SRC" >&2; exit 1; }

WORK="${WORK:-/tmp/imgwork}"
mkdir -p "$WORK"

# Ensure sharp is installed in WORK
if ! [ -d "$WORK/node_modules/sharp" ]; then
  echo "==> installing sharp for image processing"
  (cd "$WORK" && npm init -y >/dev/null 2>&1 && npm install --silent sharp 2>&1 | tail -3)
fi

# Find image files (by `file` magic, not extension — handles screenshots
# saved without extensions, like the test set at /home/yyh/tmp/fig/{1,2,3,4})
echo "==> scanning $SRC for images"
mapfile -t FILES < <(find "$SRC" -maxdepth 1 -type f -exec file --mime-type {} \; | \
  grep -E ': image/(png|jpeg|jpg)$' | cut -d: -f1 | sort)

if [ ${#FILES[@]} -eq 0 ]; then
  echo "==> no image files in $SRC" >&2
  exit 1
fi

echo "==> found ${#FILES[@]} image(s):"
for f in "${FILES[@]}"; do echo "    $f"; done

# Create shrink script
cat > "$WORK/_shrink_batch.mjs" <<'JSEOF'
import sharp from "sharp";
import path from "path";
const [, , width, ...files] = process.argv;
for (const f of files) {
  const base = path.basename(f);
  const out = path.join("/tmp/imgwork", `preview-${base}.jpg`);
  const info = await sharp(f).resize({ width: parseInt(width, 10) }).jpeg({ quality: 75 }).toFile(out);
  console.log(`  ${base} -> ${out} (${info.width}x${info.height}, ${info.size} bytes)`);
}
JSEOF

echo "==> shrinking to width ${WIDTH}px"
(cd "$WORK" && node _shrink_batch.mjs "$WIDTH" "${FILES[@]}")

echo ""
echo "================================================================"
echo "Previews ready in $WORK/preview-*.jpg"
echo ""
echo "NEXT STEPS (agent does, not this script):"
echo "  1. Read each preview file to understand its content"
echo "  2. Decide a meaningful filename:"
echo "       - shot-<descriptive-noun>.png"
echo "       - Example: shot-branches.png, shot-pr-list.png, shot-agent-comment.png"
echo "  3. scp each original to:"
echo "       do:/root/blog/public/images/$SLUG/<new-name>.png"
echo "  4. Record the (filename, alt, caption) tuple in the manifest's"
echo "     images: list (and reference it in body via <figure>)"
echo "================================================================"
