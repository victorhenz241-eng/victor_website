#!/bin/sh
# make-og.sh — regenerate static/og.png, the link-preview picture, from scripts/og.html.
#
# Run it from the project folder:
#
#   scripts/make-og.sh
#
# It opens og.html in Google Chrome without a window (--headless) and saves a
# 1200 x 630 screenshot. Chrome must be installed in /Applications; it needs
# the internet once, to fetch the fonts from Google Fonts.
#   --hide-scrollbars         no scrollbar in the picture
#   --window-size=1200,630    the size LinkedIn, Slack and X expect
#   --virtual-time-budget     let the page "run" for up to 5 s first, so the
#                             fonts have arrived before the screenshot
#   --force-color-profile     plain sRGB, the colors every screen agrees on
# Then rebuild the site (sbcl --script make.lisp): the build copies static/ to public/.

set -eu

here=$(cd "$(dirname "$0")" && pwd)       # the scripts/ folder
out="$here/../static/og.png"
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$chrome" ] || { echo "Google Chrome not found at $chrome"; exit 1; }

# A throwaway Chrome profile, so this never touches your own browser's settings.
profile=$(mktemp -d)
trap 'rm -rf "$profile"' EXIT

"$chrome" --headless=new --hide-scrollbars --window-size=1200,630 \
  --force-device-scale-factor=1 --force-color-profile=srgb \
  --virtual-time-budget=5000 --user-data-dir="$profile" \
  --screenshot="$out" "file://$here/og.html" >/dev/null 2>&1

sips -g pixelWidth -g pixelHeight "$out" | tail -n 2
ls -lh "$out" | awk '{ print "  size: " $5 }'
echo "Done. Rebuild the site: sbcl --script make.lisp"
