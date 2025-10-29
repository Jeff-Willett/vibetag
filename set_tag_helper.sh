#!/bin/bash
# Helper script to set tags via xattr
# Usage: ./set_tag_helper.sh <file_path> <tag1> <tag2> ...

file_path="$1"
shift
tags=("$@")

# Build XML plist
plist='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>'

for tag in "${tags[@]}"; do
    plist="${plist}<string>${tag}</string>"
done

plist="${plist}</array>
</plist>"

# Convert to hex and write
echo "$plist" | xxd -p | tr -d '\n' | xargs -I {} xattr -wx com.apple.metadata:_kMDItemUserTags {} "$file_path"

exit $?
