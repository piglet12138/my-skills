#!/usr/bin/env bash
# gen-hero.sh — call LuckyAPI gpt-image-2 to generate a per-article
# hero illustration OR paper-bg texture (every post should have its own,
# not reuse another article's asset).
# Downloads to /root/blog/public/images/<slug>/{hero.png|paper-bg.jpg} on DO,
# and saves a local thumbnail for agent self-check.
#
# Usage:
#   bash gen-hero.sh --slug <SLUG> --kind <hero|paper-bg> \
#                    --mood <MOOD> --concept "<CONCEPT>" [--size 1536x1024]
#
# Env:
#   LUCKYAPI_KEY  - long-term LuckyAPI key
#   DO_SSH        - ssh alias for the blog server (default: do)
#
# Args:
#   --kind        hero | paper-bg (default: hero)
#   --mood        warm-engineering | literary-personal | somber-critical |
#                 clinical-bright | mystic-dark  (default: warm-engineering)
#   --concept     central metaphor for hero, or background concept for paper-bg.
#                 Required for hero. For paper-bg, can be empty (mood drives it).
#
# Hero + paper-bg pair: call this script TWICE per article with the SAME --mood
# so the two outputs share palette and tonal coherence.
#
# Notes:
# - gpt-image-2 model ID is literally "(按次)gpt-image-2" (Chinese prefix required).
# - `-d` mangles UTF-8 in some shells; we POST via --data-binary @file.
# - Cloudflare 524 timeouts happen ~20% of calls; we auto-retry once.

set -eu

SLUG=""
KIND="hero"
MOOD="warm-engineering"
CONCEPT=""
SIZE=""
LUCKYAPI_KEY="${LUCKYAPI_KEY:-sk-jrheAkxb0gNVW7nzCfJbyw28eGepS78qP9HubCgSkc6SyxtS}"
DO_SSH="${DO_SSH:-do}"

while [ $# -gt 0 ]; do
  case "$1" in
    --slug) SLUG="$2"; shift 2 ;;
    --kind) KIND="$2"; shift 2 ;;
    --mood) MOOD="$2"; shift 2 ;;
    --concept) CONCEPT="$2"; shift 2 ;;
    --size) SIZE="$2"; shift 2 ;;
    --style) KIND="$2"; shift 2 ;;   # backward-compat alias
    -h|--help)
      grep -E '^#' "$0" | sed 's/^# \?//'
      exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$SLUG" ]; then
  echo "usage: $0 --slug <SLUG> --kind <hero|paper-bg> --mood <MOOD> --concept '...'" >&2
  exit 2
fi
if [ "$KIND" = "hero" ] && [ -z "$CONCEPT" ]; then
  echo "hero requires --concept (the central metaphor, e.g. 'a wooden desk by a window at sunset...')" >&2
  exit 2
fi

# Default size per kind
[ -z "$SIZE" ] && case "$KIND" in
  hero)     SIZE="1536x1024" ;;
  paper-bg) SIZE="1536x1024" ;;
  *)        SIZE="1024x1024" ;;
esac

# Mood-specific style anchors (kept consistent between hero and paper-bg)
case "$MOOD" in
  warm-engineering)
    HERO_STYLE="vintage paper engraving with hand-tinted color, warm cream and rust palette, subtle ink crosshatching, soft paper texture, 19th century technical manual aesthetic"
    BG_STYLE="aged 19th-century engineering blueprint paper, cream and light beige with subtle ink stains, brown fiber flecks, faint sepia drafting compass marks at edges"
    ;;
  literary-personal)
    HERO_STYLE="soft watercolor wash over hand-drawn pencil lines, cream paper, dusty rust accent, sage green secondary tone, still and contemplative, Andrew Wyeth quietude"
    BG_STYLE="warm cream paper with very subtle watercolor wash, faint sage green and dusty rose hints at edges, like a personal journal page"
    ;;
  somber-critical)
    HERO_STYLE="vintage scientific diagram style, cream paper going slightly grayer at edges, hand-drawn cross-hatching, deep red and muted teal accents, Vesalius / Kircher-like, hidden meaning"
    BG_STYLE="aged paper in muted greyed cream, very faint cross-hatching pattern, dark ink stains scattered subtly, hints of deep red and teal at corners"
    ;;
  clinical-bright)
    HERO_STYLE="clean modern infographic, white or off-white background, crisp blue and orange accents, thin geometric lines, minimal flat shading, Edward Tufte aesthetic"
    BG_STYLE="near-white background with extremely subtle pale-grey grid suggesting graph paper / technical drafting sheet"
    ;;
  mystic-dark)
    HERO_STYLE="woodblock print style, deep ink-black background, gold and dim purple accents, heavy contrast, slightly mis-registered color layers like old multi-block printing, Ukiyo-e night scene"
    BG_STYLE="near-black background with subtle ink texture, very faint gold leaf flecks scattered randomly, heavy paper grain, midnight altar cloth mood"
    ;;
  *)
    echo "unknown mood: $MOOD" >&2; exit 2 ;;
esac

# Build prompt by kind
if [ "$KIND" = "hero" ]; then
  PROMPT="An illustration: ${CONCEPT}. Style: ${HERO_STYLE}. No people unless required by the concept. No text. No legible code or letters. Aspect ratio 16:9, banner composition. Tasteful, literary."
  OUT_NAME="hero.png"
elif [ "$KIND" = "paper-bg" ]; then
  EXTRA="$CONCEPT"
  [ -z "$EXTRA" ] || EXTRA=" Specific accent: ${EXTRA}."
  PROMPT="A seamless background texture: ${BG_STYLE}.${EXTRA} No central subject. No text. No drawings or legible content. The texture should tile cleanly. Aspect ratio 16:10, high resolution."
  OUT_NAME="paper-bg.jpg"
else
  echo "unknown kind: $KIND (use hero|paper-bg)" >&2
  exit 2
fi

WORK="${WORK:-/tmp/imgwork}"
mkdir -p "$WORK"

# Compose request body via jq (safe for UTF-8)
REQ_FILE="$WORK/hero_req.json"
python3 -c "
import json
body = {
    'model': '(按次)gpt-image-2',
    'prompt': '''$PROMPT''',
    'size': '$SIZE',
    'n': 1
}
with open('$REQ_FILE', 'w', encoding='utf-8') as f:
    json.dump(body, f, ensure_ascii=False)
" 2>/dev/null || {
  # Fallback if no python3
  printf '{"model":"(按次)gpt-image-2","prompt":%s,"size":"%s","n":1}' \
    "$(printf '%s' "$PROMPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$PROMPT")" \
    "$SIZE" > "$REQ_FILE"
}

echo "==> calling LuckyAPI gpt-image-2 (kind=$KIND mood=$MOOD size=$SIZE)"

attempt() {
  curl -fsS -X POST https://luckyapi.chat/v1/images/generations \
    -H "Authorization: Bearer $LUCKYAPI_KEY" \
    -H "Content-Type: application/json; charset=utf-8" \
    --data-binary "@$REQ_FILE"
}

RESPONSE=""
for i in 1 2; do
  RESPONSE=$(attempt 2>&1) && break
  echo "==> attempt $i failed, retrying in 5s..."
  sleep 5
done

if [ -z "$RESPONSE" ]; then
  echo "==> all attempts failed" >&2
  exit 1
fi

IMG_URL=$(printf '%s' "$RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data['data'][0].get('url') or '')
" 2>/dev/null || true)

if [ -z "$IMG_URL" ]; then
  echo "==> no image URL in response. Raw: $RESPONSE" >&2
  exit 1
fi

echo "==> image URL: $IMG_URL"
echo "==> downloading to DO server"

ssh "$DO_SSH" "mkdir -p /root/blog/public/images/$SLUG && curl -fsSL '$IMG_URL' -o /root/blog/public/images/$SLUG/$OUT_NAME && ls -la /root/blog/public/images/$SLUG/$OUT_NAME"

# Also pull a small preview locally for agent self-check
echo "==> pulling local preview for visual check"
PREVIEW="$WORK/${SLUG}_${OUT_NAME%.*}_preview.jpg"
curl -fsSL "$IMG_URL" -o "$WORK/$OUT_NAME"

# Shrink with sharp if available
if command -v node >/dev/null; then
  cat > "$WORK/_shrink.mjs" <<'JSEOF'
import sharp from "sharp";
const inp = process.argv[2];
const out = process.argv[3];
await sharp(inp).resize({width: 900}).jpeg({quality: 80}).toFile(out);
console.log("preview:", out);
JSEOF
  (cd "$WORK" && [ -d node_modules/sharp ] || npm install --silent sharp 2>/dev/null) || true
  (cd "$WORK" && node _shrink.mjs "$WORK/$OUT_NAME" "$PREVIEW") || {
    cp "$WORK/$OUT_NAME" "$PREVIEW"
    echo "==> sharp not available, copied original as preview"
  }
fi

echo ""
echo "================================================================"
echo "Hero generation done."
echo "  Server:  /root/blog/public/images/$SLUG/$OUT_NAME"
echo "  Local preview (for visual review): $PREVIEW"
echo ""
echo "Now read the preview file to verify composition matches intent."
echo "If unsatisfied, rerun with a refined --concept."
echo "================================================================"
