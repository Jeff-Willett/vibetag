#!/bin/bash

# Create a dummy file with the complex name
FILENAME="EPORNER.COM - [gJW1HeKWwy2] Ivana Liquor, Laney Day  Mimi P - Flesh (1080).mp4"
touch "$FILENAME"

# Start a process that holds this file open
# We use 'tail -f' to keep it open
tail -f "$FILENAME" > /dev/null &
PID=$!

echo "Started dummy process $PID holding '$FILENAME'"

# Now try to detect it using the logic from get_iina_file.sh
echo "Running detection logic..."

# Extract from get_iina_file.sh logic:
FILES=$(lsof -p "$PID" -F n 2>/dev/null | grep '^n/' | sed 's/^n//')

IFS=$'\n'
for file in $FILES; do
    echo "Lsof found candidate path: '$file'"
    
    if [ -f "$file" ]; then
        echo "  [OK] File exists on disk."
        stat -f %a "$file" >/dev/null && echo "  [OK] stat successful."
    else
        echo "  [FAIL] File NOT found on disk (quoted check)."
    fi
done
unset IFS

# Cleanup
kill $PID
rm "$FILENAME"
