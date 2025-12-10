# FAQ

## General

### Is SystemMonitor Pro free?

Yes, completely free and open source. No ads, no subscriptions, no tracking.

### Does it work on Intel Macs?

Yes. It runs on both Apple Silicon (M1/M2/M3) and Intel Macs with macOS 14.0 or later.

### Why does it need macOS 14.0?

The app uses SwiftUI features that require macOS Sonoma. Supporting older versions would mean rewriting significant parts of the UI.

### Does it run in the background?

Yes, it sits in your menu bar. It uses very little CPU (around 1%) and minimal memory.

---

## CPU & Temperature

### Why is the temperature an estimate?

Reading actual CPU temperature requires access to the SMC (System Management Controller). This needs special entitlements that aren't available to regular apps without disabling System Integrity Protection.

The estimate is calculated based on CPU load and gives a reasonable approximation.

### My CPU shows high usage but nothing is running

Check Activity Monitor for background processes. Common culprits:
- Spotlight indexing (mds_stores)
- Photos face recognition
- Time Machine backups
- Browser tabs running JavaScript

---

## Memory

### It says I'm using 14GB of 16GB. Is that bad?

Not necessarily. macOS aggressively uses available RAM for caching. What matters is memory pressure:
- **Green**: You're fine
- **Yellow**: Getting tight
- **Red**: Your Mac is struggling

### Should I use a memory cleaner?

Generally, no. macOS manages memory automatically. "Memory cleaner" apps can actually hurt performance by forcing the system to reload data it had cached.

---

## Disk & Cleaning

### Is it safe to clean caches?

Yes. Cache files are temporary by design. Apps recreate them as needed. You might notice:
- Websites loading slightly slower initially
- Apps taking a moment longer to open

Your data, passwords, and settings aren't affected.

### Why can't I clean some files?

Some cache directories are protected by macOS. The app skips files it can't access rather than asking for admin permissions.

### Will cleaning break my apps?

No. The cleaner only removes files that apps expect to be temporary. Configuration files and user data are left alone.

---

## App Uninstaller

### Why doesn't it show all my apps?

The uninstaller shows apps from:
- /Applications
- ~/Applications

It doesn't show system apps (Safari, Mail, etc.) because those can't be safely removed.

### I removed an app but it's still there

Some apps install helper tools or login items. Check:
- System Settings → General → Login Items
- /Library/LaunchAgents and ~/Library/LaunchAgents

---

## Network

### The speeds seem wrong

The monitor shows all network traffic, including:
- Background app updates
- Cloud syncing
- System services

If you're not actively downloading anything, you might still see activity from these sources.

### It shows 0 B/s even though I'm online

This means no data is being transferred right now. The connection is fine - there's just no active traffic.

---

## Privacy

### Does the app send any data?

No. Everything runs locally on your Mac. There's no analytics, no telemetry, no network connections except for system API calls.

### Why does it need Full Disk Access?

It doesn't require it. The cache cleaner works with standard user permissions. Some protected files might be skipped, but core functionality works fine without special access.
