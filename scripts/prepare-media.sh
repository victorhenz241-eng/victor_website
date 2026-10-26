#!/bin/sh
# prepare-media.sh — turn original photos and videos into small web versions
# that go in static/media/. macOS only: it uses tools that come with the system
# (sips, and Swift through scripts/media.swift). Nothing to install.
#
# Run it from the project folder:
#
#   scripts/prepare-media.sh photo ~/Desktop/IMG_1234.HEIC about-running.jpg
#       A photo (JPEG, HEIC, PNG...): long edge at most 1600 px, JPEG quality 80,
#       turned upright, and ALL metadata removed (GPS position, phone model, date).
#
#   scripts/prepare-media.sh video ~/Desktop/demo.mov my-demo.mp4 [kbps]
#       A demo with sound, for a case-study page: 720p H.264 + AAC, "fast start".
#       kbps is the video bitrate (default 700). Aim for 12 MB or less.
#
#   scripts/prepare-media.sh clip ~/Desktop/demo.mov my-card.mp4 START [SECONDS]
#       A short silent loop for a project card: SECONDS long (default 8),
#       starting START seconds into the original, no sound.
#
#   scripts/prepare-media.sh poster ~/Desktop/demo.mov my-poster.jpg SECOND
#       The frame at SECOND, as a JPEG: shown before a video plays, and instead
#       of it when someone asks their system for less motion.
#
# The last argument names the file inside static/media/. Use lowercase letters,
# digits and dashes only: no spaces (a space in a web address becomes %20, and
# it's easy to get wrong).
#
# Why not plain `sips` for photos? `sips -s format jpeg -s formatOptions 80 -Z 1600`
# resizes nicely, but it keeps the metadata, GPS position included. We still use
# sips at the end, to print the result's size and prove the metadata is gone.

set -eu   # stop at the first error (-e), and on an unset variable (-u)

here=$(cd "$(dirname "$0")" && pwd)       # the scripts/ folder
media="$here/../static/media"
mkdir -p "$media"

usage() {
  sed -n '2,30p' "$0"                     # print the comment above
  exit 1
}

[ $# -ge 3 ] || usage
job=$1
source=$2
name=$3

case "$name" in
  *[!a-z0-9.-]*) echo "Use lowercase letters, digits, dots and dashes in the name: $name"; exit 1 ;;
esac
[ -f "$source" ] || { echo "No such file: $source"; exit 1; }
out="$media/$name"

case "$job" in
  photo)
    swift "$here/media.swift" photo "$source" "$out" --max 1600 --quality 0.8
    ;;
  video)
    swift "$here/media.swift" video "$source" "$out" --height 720 --kbps "${4:-700}"
    ;;
  clip)
    [ $# -ge 4 ] || usage
    swift "$here/media.swift" video "$source" "$out" --height 720 --kbps 600 \
      --start "$4" --duration "${5:-8}" --no-audio
    ;;
  poster)
    [ $# -ge 4 ] || usage
    swift "$here/media.swift" frame "$source" "$out" --start "$4" --max 1280
    ;;
  *) usage ;;
esac
# The video writer can leave a temporary copy next to the file ("name.mp4.sb-…").
rm -f "$out".sb-*

# Check the result. For pictures, sips lists every property it can read: there
# should be no GPS, make, model or date lines.
case "$out" in
  *.jpg)
    sips -g pixelWidth -g pixelHeight "$out" | tail -n 2
    if sips -g all "$out" | grep -i -E "gps|make|model|creation" ; then
      echo "WARNING: some metadata is still in $out"
      exit 1
    fi
    echo "  metadata: none (no GPS, no camera, no date)"
    ;;
esac
ls -lh "$out" | awk '{ print "  size: " $5 }'
echo "Done. Rebuild the site: sbcl --script make.lisp"
