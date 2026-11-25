#!/usr/bin/env bash
# Re-fetch the baby-cry recordings from Wikimedia Commons, check each against
# the SHA-1 Commons publishes, and re-encode them into public/sounds/.
# Provenance and licenses are recorded in src/sounds.provenance.json.
# Needs: curl, sha1sum, ffmpeg (with libmp3lame).
set -euo pipefail
cd "$(dirname "$0")/.."

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
OUT=public/sounds
mkdir -p "$OUT"

# id | Commons path | SHA-1 published by Commons
SOURCES=(
  "newborn|2/2b/Crying_newborn_baby.ogg|16f95806c6425912c808ee52300a14502f862ce9"
  "hungry|c/cf/Baby_long_wanting_cry.ogg|c5b0bf176dea3e7b81495af06a8d92d8521575ab"
  "fussy|d/dc/Babys_disappointed_crying.oga|7b80bd9ad40ad6a72844b2ef3d4231f4d3a660da"
  "kunjappi|f/f7/Newborn_baby_crying_sounds_20190831_061900.wav|369e5e6bbde178cec389aaf78e4a4b0804ce29c7"
)

for entry in "${SOURCES[@]}"; do
  IFS='|' read -r id path sha1 <<<"$entry"
  src="$WORK/$(basename "$path")"
  curl -sSfL -A "baby-cry-alarm-build/1.0" -o "$src" "https://upload.wikimedia.org/wikipedia/commons/$path"
  echo "$sha1  $src" | sha1sum -c -
  ffmpeg -hide_banner -v error -y -i "$src" -map_metadata -1 \
    -af "loudnorm=I=-14:TP=-1.5:LRA=11" -ar 44100 -ac 1 \
    -c:a libmp3lame -b:a 128k "$OUT/$id.mp3"
  sleep 1
done

sha256sum "$OUT"/*.mp3
echo "Update the sha256 fields in src/sounds.provenance.json if they changed."
