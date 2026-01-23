#!/bin/bash
# Helper script to get currently playing file from IINA
# Uses lsof to check what video files IINA has open - completely non-intrusive!

# Check if IINA is running
if ! pgrep -x "IINA" > /dev/null; then
    echo "ERROR: IINA is not running" >&2
    exit 1
fi

# Use lsof to find video files that IINA has open
# Look for common video file extensions
video_file=$(lsof -c IINA 2>/dev/null | \
    grep -E '\.(mp4|mkv|avi|mov|m4v|flv|wmv|webm|ts|m2ts|mpg|mpeg|3gp|ogv)$' | \
    grep ' REG ' | \
    awk '{for(i=9;i<=NF;i++) printf "%s ", $i; print ""}' | \
    sed 's/ $//' | \
    head -1)

if [ -z "$video_file" ]; then
    echo "ERROR: No video file currently open in IINA" >&2
    exit 1
fi

# Return the file path
echo "$video_file"
