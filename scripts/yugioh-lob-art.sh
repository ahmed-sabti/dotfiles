#!/usr/bin/env bash
# Cache the cropped artwork of every monster from Yu-Gi-Oh! "Legend of Blue Eyes White Dragon"
# (YGOPRODeck API) as PNG in ~/.cache/yugioh-lob, for the fastfetch logo in zshrc.
# YGOPRODeck asks clients to store images locally instead of hotlinking; this runs once.
set -euo pipefail

dir="$HOME/.cache/yugioh-lob"
api="https://db.ygoprodeck.com/api/v7/cardinfo.php?cardset=Legend%20of%20Blue%20Eyes%20White%20Dragon"
mkdir -p "$dir"

# kitty's graphics protocol needs PNG; the API serves JPEG. Linux: install imagemagick.
if ! command -v sips >/dev/null && ! command -v magick >/dev/null && ! command -v convert >/dev/null; then
  echo "yugioh-lob-art: need sips (macOS) or ImageMagick to convert JPEG -> PNG" >&2
  exit 1
fi

curl -fsSL --max-time 30 "$api" | python3 -c '
import json, sys
for c in json.load(sys.stdin)["data"]:
    if "Monster" not in c["type"]:
        continue
    imgs = c["card_images"]
    img = next((i for i in imgs if i["id"] == c["id"]), imgs[0])
    print(c["id"], img["image_url_cropped"])
' | while read -r id url; do
  [[ -s "$dir/$id.png" ]] && continue
  tmp="$dir/$id.jpg.part"
  if curl -fsSL --max-time 30 -o "$tmp" "$url"; then
    if command -v sips >/dev/null; then
      sips -s format png "$tmp" --out "$dir/$id.png" >/dev/null 2>&1 || true
    elif command -v magick >/dev/null; then
      magick "$tmp" "$dir/$id.png" || true
    elif command -v convert >/dev/null; then # ImageMagick 6 (older Debian/Ubuntu)
      convert "$tmp" "$dir/$id.png" || true
    fi
  fi
  rm -f "$tmp"
  sleep 0.1 # stay far below the API's 20 requests/second limit
done

echo "$(find "$dir" -name '*.png' | wc -l | tr -d ' ') cards cached in $dir"
