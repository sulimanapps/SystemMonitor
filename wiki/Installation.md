# Installation

## Download

Get the latest version from [GitHub Releases](https://github.com/sulimanapps/SystemMonitor/releases).

Download the `.zip` file (about 2 MB).

## Install

1. **Extract the zip** - Double-click the downloaded file
2. **Move to Applications** - Drag `SystemMonitor Pro.app` to your Applications folder
3. **First launch** - Double-click to open

### Gatekeeper Warning

Since the app isn't signed with an Apple Developer certificate, macOS will show a warning on first launch.

To open it:
1. Right-click (or Control-click) the app
2. Select "Open" from the menu
3. Click "Open" in the dialog

You only need to do this once.

## Launch at Login

To start SystemMonitor Pro automatically when you log in:

1. Open **System Settings**
2. Go to **General** → **Login Items**
3. Click the **+** button
4. Select `SystemMonitor Pro` from Applications
5. Click **Add**

## Uninstall

To remove the app:

1. Quit SystemMonitor Pro (click the menu bar icon → Quit)
2. Delete from Applications folder
3. Optionally, remove preferences:
   ```
   ~/Library/Preferences/com.sulimanapps.SystemMonitor.plist
   ```

## Build from Source

If you want to build it yourself:

```bash
git clone https://github.com/sulimanapps/SystemMonitor.git
cd SystemMonitor
open SystemMonitor.xcodeproj
```

Then build and run in Xcode (Cmd+R).

Requires Xcode 15+ and macOS 14.0 SDK.
