# Troubleshooting

## App Won't Open

### "App is damaged and can't be opened"

This happens because the app isn't notarized by Apple.

**Fix:**
1. Open Terminal
2. Run: `xattr -cr /Applications/SystemMonitor\ Pro.app`
3. Try opening the app again

### "App from unidentified developer"

1. Right-click the app in Finder
2. Select "Open"
3. Click "Open" in the dialog

You only need to do this once.

### App opens but nothing appears

The app runs in the menu bar, not as a regular window.

Look for the SystemMonitor icon in the top-right of your screen, near the clock.

If you have many menu bar icons, it might be hidden. Try:
- Closing other menu bar apps
- Hold Command and drag menu bar icons to rearrange

---

## High CPU Usage

### The app itself uses too much CPU

This was fixed in v2.0.2. If you're on an older version, update to the latest release.

If you're on the latest version and still see high usage, please [open an issue](https://github.com/sulimanapps/SystemMonitor/issues) with:
- Your macOS version
- Mac model
- Screenshot of Activity Monitor

### CPU reading stuck or not updating

Try:
1. Quit the app (click menu bar icon → Quit)
2. Reopen it

If the problem persists, restart your Mac.

---

## Memory Issues

### Memory info shows as 0 or incorrect

This can happen if the system call fails. Usually fixed by restarting the app.

### App using too much memory

The app typically uses 50-100 MB. If you see significantly more:
1. Quit and reopen the app
2. If it persists, [report it](https://github.com/sulimanapps/SystemMonitor/issues)

---

## Network Monitoring

### Network speeds always show 0

Make sure you have an active network connection. The monitor shows actual traffic, not connection capability.

If you're definitely transferring data and it still shows 0, the network interface might not be recognized. Report which Mac model and connection type you're using.

### Speeds seem inaccurate

The monitor updates every second and shows instantaneous rates. For average speeds, tools like `nettop` in Terminal give more detailed breakdowns.

---

## Cache Cleaner

### "Some files couldn't be deleted"

This is normal. Some files are:
- In use by running apps
- Protected by System Integrity Protection
- Owned by root

The cleaner skips these and cleans what it can.

### Cleaned space doesn't match what Finder shows

Finder's "available space" includes purgeable files. After cleaning, macOS might reallocate some space. Give it a few minutes to update.

### Browser data was deleted

The cleaner removes cache files, not:
- Bookmarks
- Passwords
- Browsing history
- Saved logins

If you lost browser data, it might have been stored unusually or a different app cleared it.

---

## App Uninstaller

### Can't find an app to uninstall

The uninstaller only shows apps from standard locations:
- /Applications
- ~/Applications

Apps installed via Homebrew, or in custom locations, won't appear.

### App still running after uninstall

Some apps have background processes. After uninstalling:
1. Open Activity Monitor
2. Search for the app name
3. Quit any remaining processes

Or just restart your Mac.

---

## General Fixes

### App crashes on launch

1. Delete the preferences file:
   ```
   rm ~/Library/Preferences/com.sulimanapps.SystemMonitor.plist
   ```
2. Try launching again

### Everything looks broken / wrong layout

Try resetting the window state:
1. Quit the app
2. Delete preferences (see above)
3. Relaunch

### Still having issues?

[Open a GitHub issue](https://github.com/sulimanapps/SystemMonitor/issues) with:
- macOS version (Apple menu → About This Mac)
- Mac model
- What you expected vs. what happened
- Steps to reproduce the problem
- Any error messages
