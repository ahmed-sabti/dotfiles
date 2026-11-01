#!/bin/bash

TMP_COVER="/tmp/waybar-cover.jpg"
FALLBACK=""

FILE_URL=$(playerctl -p feishin metadata xesam:url 2>/dev/null)

if [[ -z "$FILE_URL" ]]; then
    echo "$FALLBACK"
    exit
fi

FILE_PATH="${FILE_URL#file://}"
FILE_PATH=$(printf '%b' "${FILE_PATH//%/\\x}")

if [[ -f "$FILE_PATH" ]]; then
    ffmpeg -i "$FILE_PATH" -an -vcodec copy -vframes 1 -y "$TMP_COVER" &> /dev/null
    
    if [[ -f "$TMP_COVER" ]]; then
        echo "$TMP_COVER"
    else
        echo "$FALLBACK"
    fi
else
    echo "$FALLBACK"
fi
