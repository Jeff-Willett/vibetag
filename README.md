# TagManager

A macOS application for tagging video files in IINA with Finder tags. TagManager automatically detects the currently playing video in IINA and allows you to quickly apply custom tags without interrupting playback.

## Features

- **Auto-Detection**: Automatically detects the currently playing video in IINA
- **Auto-Refresh**: Monitors IINA every 2 seconds and updates when you change videos
- **Non-Intrusive**: Uses `lsof` to detect files - no Finder windows popping up
- **Global Shortcut**: Press `Cmd+Shift+T` to toggle the TagManager window
- **Custom Tags**: Pre-configured tags (Arc, KP, TMP, PRG, HW-SGR, RPLY, Other1)
- **Tag Search**: Filter tags with the built-in search functionality
- **Visual Feedback**: See which tags are applied at a glance
- **Manual Selection**: Select files manually if needed via file picker
- **Persistent Storage**: Tags are stored using macOS Finder extended attributes

## Requirements

- macOS (tested on macOS Sequoia 15.0+)
- IINA media player
- Xcode (for building from source)

## Installation

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/Jeff-Willett/tagmanager.git
cd tagmanager/TagManager
```

2. Open the project in Xcode:
```bash
open TagManager.xcodeproj
```

3. Build and run the project (Cmd+R)

### Permissions Required

The app requires the following permissions to function:

- **Full Disk Access**: Required to read/write Finder tags on video files
  - Go to System Settings → Privacy & Security → Full Disk Access
  - Add TagManager.app and enable it

- **Accessibility**: Required for the global keyboard shortcut
  - Go to System Settings → Privacy & Security → Accessibility
  - Add TagManager.app and enable it

## Usage

### Basic Workflow

1. **Launch IINA** and open a video file
2. **Press `Cmd+Shift+T`** to show the TagManager window
3. **Auto-refresh is enabled by default** (green circular arrow icon)
4. The app will display the current video filename and any existing tags
5. **Click tags** to apply or remove them
6. **Change videos in IINA** - TagManager will automatically detect and update

### Controls

- **`Cmd+Shift+T`**: Toggle TagManager window
- **`Cmd+R`**: Manual refresh (if auto-refresh is disabled)
- **Circular Arrow Icon**: Toggle auto-refresh on/off
- **Search Field**: Filter available tags
- **Select File Button**: Manually choose a video file

### Auto-Refresh Feature

The auto-refresh feature (enabled by default) checks IINA every 2 seconds for file changes. When you:
- Navigate to the next/previous video
- Open a new video file
- Change playlists

TagManager will automatically detect the change and load the new file's tags.

**Toggle auto-refresh**: Click the circular arrow icon in the bottom-left corner
- Green (filled) = Auto-refresh ON
- Gray (outline) = Auto-refresh OFF

## Technical Details

### Architecture

The app consists of several key components:

- **IINAConnector**: Detects currently playing files using `lsof` system calls
- **FinderTagManager**: Reads/writes Finder tags using `xattr` commands
- **ShortcutManager**: Registers and handles global keyboard shortcuts
- **WindowManager**: Manages window positioning and behavior
- **ContentView**: Main UI with tag management interface

### How File Detection Works

TagManager uses `lsof` (list open files) to detect what video files IINA currently has open. This approach:
- Requires no UI interaction or AppleScript
- Doesn't steal focus or show Finder windows
- Works reliably without special permissions
- Updates quickly (typically <100ms)

The helper script (`get_iina_file.sh`) queries open files and filters for common video formats:
- mp4, mkv, avi, mov, m4v, flv, wmv, webm
- ts, m2ts, mpg, mpeg, 3gp, ogv

### Tag Storage

Tags are stored using macOS extended file attributes (`com.apple.metadata:_kMDItemUserTags`). This means:
- Tags persist across renames and moves
- Tags are visible in Finder
- Tags can be searched using Spotlight
- No external database required

## Customizing Tags

To customize the available tags, edit the `availableTags` array in `ContentView.swift`:

```swift
private let availableTags = ["Arc", "KP", "TMP", "PRG", "HW-SGR", "RPLY", "Other1"]
```

Replace with your own tag names, rebuild, and run.

## Troubleshooting

### Tags aren't saving
- Ensure Full Disk Access is granted in System Settings
- Check that the video file isn't on a read-only volume

### IINA not detected
- Make sure IINA is actually playing a video file (not a stream)
- Check that auto-refresh is enabled (green icon)
- Try clicking the manual "Refresh" button

### Global shortcut not working
- Ensure Accessibility permission is granted
- Check if another app is using `Cmd+Shift+T`
- Try restarting the app

### Finder windows popping up
This should NOT happen with the current version (using lsof). If you see Finder windows:
- You may be running an older version
- Pull the latest changes from the repository

## Development

### Project Structure

```
TagManager/
├── TagManager.xcodeproj/          # Xcode project file
├── TagManager/                       # Source code
│   ├── TagManagerApp.swift          # App entry point
│   ├── ContentView.swift         # Main UI
│   ├── IINAConnector.swift       # IINA integration
│   ├── FinderTagManager.swift    # Tag management
│   ├── ShortcutManager.swift     # Keyboard shortcuts
│   ├── WindowManager.swift       # Window management
│   └── TagManager.entitlements      # App permissions
├── get_iina_file.sh              # Helper script for file detection
├── set_tag_helper.sh             # Helper script for tag writing
└── README.md                     # This file
```

### Building for Distribution

The app is currently configured for development. To distribute:

1. Disable sandbox in TagManager.entitlements (already done)
2. Configure code signing with your Developer ID
3. Notarize the app for distribution
4. Create a DMG or use an installer

## Known Limitations

- Only works with local video files (not streaming URLs)
- Requires IINA media player (doesn't work with other players)
- Auto-refresh interval is fixed at 2 seconds
- Tags are limited to macOS Finder tags (no custom metadata)

## Future Enhancements

Potential improvements for future versions:

- Configurable auto-refresh interval
- Support for other media players
- Tag presets and quick-apply shortcuts
- Batch tagging for multiple files
- Tag statistics and history
- Export/import tag configurations
- Dark mode theme option

## Contributing

Contributions are welcome! Feel free to:
- Report bugs via GitHub Issues
- Suggest features via GitHub Issues
- Submit pull requests with improvements

## License

This project is available under the MIT License. See LICENSE file for details.

## Credits

- Built with Swift and SwiftUI
- Uses [IINA](https://iina.io) media player
- Inspired by the need for better video organization workflows

## Changelog

### v1.0.0 (Current)
- Initial release
- Auto-refresh functionality with lsof-based detection
- Global keyboard shortcut (Cmd+Shift+T)
- Tag search and filtering
- Manual file selection
- Non-intrusive file detection (no Finder windows)
- Real-time tag updates

---

**Repository**: https://github.com/Jeff-Willett/tagmanager

For questions or support, please open an issue on GitHub.
