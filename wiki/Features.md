# Features

## CPU Monitoring

Shows how much processing power your Mac is using.

**What you see:**
- Overall CPU usage percentage
- Load across all cores
- Temperature estimate (based on CPU load)

**Understanding the numbers:**
- 0-30%: Light usage, your Mac is mostly idle
- 30-70%: Normal workload
- 70-90%: Heavy usage, fans might spin up
- 90%+: Very high load, check which apps are busy

The temperature shown is an estimate. For exact readings, you'd need SMC access which requires special permissions.

---

## Memory (RAM)

Tracks how your Mac uses its memory.

**What you see:**
- Used vs. available memory
- Memory pressure indicator
- Breakdown by type:
  - **Active** - Currently in use by apps
  - **Wired** - Reserved by the system, can't be freed
  - **Compressed** - Squeezed to save space

**When to worry:**
- Memory pressure turns yellow/red
- Swap usage is high (your Mac is using disk as extra RAM)
- Apps become sluggish

macOS manages memory automatically. High usage isn't always bad - unused RAM is wasted RAM.

---

## Disk Space

Shows storage usage across all volumes.

**What you see:**
- Used and free space for each drive
- Visual bar showing capacity
- Purgeable space (files macOS can delete if needed)

**Volumes shown:**
- Your main drive (Macintosh HD)
- External drives
- Network volumes (if mounted)

**Tip:** Keep at least 10-15% free on your boot drive. macOS needs this space for virtual memory and updates.

---

## Network Speed

Monitors your internet and network traffic.

**What you see:**
- Download speed (arrow down)
- Upload speed (arrow up)
- Current rates in KB/s, MB/s, or GB/s

The speeds update every second. They show all network traffic, not just browser activity - this includes:
- Background app updates
- Cloud sync (iCloud, Dropbox, etc.)
- System services

---

## Cache Cleaner

Frees up disk space by removing temporary files.

**What it cleans:**
- Browser caches (Safari, Chrome, Firefox)
- App caches
- Xcode DerivedData and Archives
- System logs
- Temporary files in /tmp

**What it doesn't touch:**
- Your documents and files
- App preferences
- iCloud data
- System files

**Safe to use:**
The cleaner only removes files that apps will recreate when needed. Your logins, bookmarks, and settings stay intact.

After cleaning, apps might take slightly longer to open the first time as they rebuild their caches.

---

## App Uninstaller

Removes apps along with their associated files.

**What it finds:**
- The app itself
- Preferences files
- Application Support folders
- Cache files
- Saved states

**How to use:**
1. Open the Uninstaller tab
2. Select an app from the list
3. Review what will be deleted
4. Confirm removal

**Why use this instead of just trashing the app?**

When you delete an app normally, it leaves behind:
- Preference files in ~/Library/Preferences
- Support files in ~/Library/Application Support
- Cached data in ~/Library/Caches

These leftovers can add up to gigabytes over time. The uninstaller finds and removes them.

---

## Process Manager

View and control running processes.

**What you see:**
- Top processes by CPU usage
- Memory consumption per process
- Process ID (PID)

**What you can do:**
- Sort by CPU or memory
- Kill unresponsive processes

**Be careful:** Only kill processes you recognize. Killing system processes can cause instability.
