#!/usr/bin/env bash
# Turns a screen recording into the demo for the README and the landing page.
#
#   Scripts/make_demo.sh ~/Desktop/recording.mov
#
# It writes docs/assets/demo.mp4 (landing page), docs/assets/demo.gif (README, GitHub does not play
# a video file from the repository) and docs/assets/demo-poster.jpg, then points both pages at them.
#
# Environment:
#   POSTER_AT   second of the recording to use as the poster frame   (default: 3)
#   GIF_WIDTH   width of the GIF in pixels                           (default: 900)
#   GIF_FPS     frames per second of the GIF                         (default: 15)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT="${1:-}"
[[ -f "$INPUT" ]] || { echo "usage: Scripts/make_demo.sh <recording.mov>" >&2; exit 1; }
command -v ffmpeg >/dev/null || { echo "ERROR: ffmpeg not found. Install it with: brew install ffmpeg" >&2; exit 1; }

ASSETS="$ROOT/docs/assets"
FFMPEG=(ffmpeg -hide_banner -loglevel error -y)

echo "==> demo.mp4"
"${FFMPEG[@]}" -i "$INPUT" -an -vf "scale='min(1600,iw)':-2:flags=lanczos,fps=30" \
  -c:v libx264 -crf 23 -preset slow -pix_fmt yuv420p -movflags +faststart "$ASSETS/demo.mp4"

echo "==> demo-poster.jpg"
"${FFMPEG[@]}" -ss "${POSTER_AT:-3}" -i "$INPUT" -frames:v 1 -vf "scale='min(1600,iw)':-2:flags=lanczos" -q:v 3 "$ASSETS/demo-poster.jpg"

echo "==> demo.gif"
"${FFMPEG[@]}" -i "$INPUT" -vf "fps=${GIF_FPS:-15},scale=${GIF_WIDTH:-900}:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=160:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" \
  "$ASSETS/demo.gif"

python3 - "$ROOT" <<'PY'
import re, sys
root = sys.argv[1]

readme = open(f"{root}/README.md").read()
readme = re.sub(r'<img src="docs/assets/(search\.png|demo\.gif)"[^>]*/>',
                '<img src="docs/assets/demo.gif" width="90%" alt="A search for \'things you can wear\': the matches float up out of the pile, and a click copies the symbol name" />',
                readme, count=1)
open(f"{root}/README.md", "w").write(readme)

page = open(f"{root}/docs/index.html").read()
video = ('<video autoplay muted loop playsinline poster="assets/demo-poster.jpg" '
         'aria-label="A search for \'things you can wear\': the matches float up out of the pile, and a click copies the symbol name.">'
         '<source src="assets/demo.mp4" type="video/mp4"></video>')
page = re.sub(r'(<div class="shot">\s*)(<img[^>]*>|<video.*?</video>)', lambda m: m.group(1) + video, page, count=1, flags=re.S)
page = page.replace(".shot img {", ".shot img, .shot video {")
page = page.replace("assets/search.png\">", "assets/demo-poster.jpg\">")  # the og:image
open(f"{root}/docs/index.html", "w").write(page)
PY

ls -lh "$ASSETS"/demo.* "$ASSETS"/demo-poster.jpg | awk '{print "  " $5 "  " $9}'
GIF_BYTES=$(stat -f%z "$ASSETS/demo.gif")
if (( GIF_BYTES > 10000000 )); then
  echo "WARN: demo.gif is larger than 10 MB. GitHub may not show it. Record a shorter clip, or run with GIF_WIDTH=720 GIF_FPS=12."
fi
echo "==> Done. Check the pages, then: git add -A docs README.md && git commit -m 'Add the demo video' && git push"
