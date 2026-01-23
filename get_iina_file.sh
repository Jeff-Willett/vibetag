#!/bin/bash
# Helper script to get currently playing file from IINA
# Uses lsof to find all open video files and picks the one with the most recent access time.

LOGfile="/tmp/vibetag_debug.log"
echo "--- $(date) ---" >> "$LOGfile"

# Check if IINA is running
PID=$(pgrep -x "IINA")
if [ -z "$PID" ]; then
    echo "ERROR: IINA is not running" >&2
    echo "ERROR: IINA is not running" >> "$LOGfile"
    exit 1
fi

echo "IINA PID: $PID" >> "$LOGfile"

# Get all open files for IINA
# -p: PID
# -F n: Output only file names (prefixed with 'n')
# We need to clean the 'n' prefix
FILES=$(lsof -p "$PID" -F n 2>/dev/null | grep '^n/' | sed 's/^n//')

# Function to check if a file has a video extension
is_video_file() {
    local file="$1"
    case "$file" in
        *.mp4|*.mkv|*.avi|*.mov|*.m4v|*.flv|*.wmv|*.webm|*.ts|*.m2ts|*.mpg|*.mpeg|*.3gp|*.ogv)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

LATEST_FILE=""
LATEST_ACCESS_TIME=0

# Iterate over files (handling spaces requires setting IFS)
IFS=$'\n'
for file in $FILES; do
    if is_video_file "$file"; then
        echo "Candidate video: $file" >> "$LOGfile"
        if [ -f "$file" ]; then
            # Get access time (seconds since epoch)
            ACCESS_TIME=$(stat -f %a "$file" 2>/dev/null)
            echo "  Access Time: $ACCESS_TIME" >> "$LOGfile"
            
            if [ -n "$ACCESS_TIME" ] && [ "$ACCESS_TIME" -gt "$LATEST_ACCESS_TIME" ]; then
                LATEST_ACCESS_TIME=$ACCESS_TIME
                LATEST_FILE="$file"
                echo "  -> New Best Candidate" >> "$LOGfile"
            fi
        else
            echo "  [FAIL] File not found on disk" >> "$LOGfile"
        fi
    fi
done
unset IFS

if [ -z "$LATEST_FILE" ]; then
    echo "ERROR: No video file currently open in IINA" >&2
    echo "ERROR: No video file found" >> "$LOGfile"
    exit 1
fi

# Return the file path
echo "Selected: $LATEST_FILE" >> "$LOGfile"
echo "$LATEST_FILE"
