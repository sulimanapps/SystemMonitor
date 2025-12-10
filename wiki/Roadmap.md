# Roadmap

Planned features and improvements. No promises on timing - this is a side project.

## In Progress

### Real CPU Temperature
Reading actual temperature from the SMC instead of estimates. Researching methods that work without disabling SIP.

---

## Planned

### GPU Monitoring
- GPU usage percentage
- Video memory
- Works with both integrated and discrete GPUs

### Battery Health
- Cycle count
- Maximum capacity
- Charging status
- Time remaining estimate

### Alerts & Notifications
- Notify when CPU/RAM exceeds threshold
- Low disk space warnings
- Custom alert rules

### Menu Bar Customization
- Choose what stats to show in the menu bar
- Mini graph in menu bar
- Color themes

### Widgets
- macOS widgets for desktop/notification center
- Quick glance without opening the app

### Historical Data
- Charts showing usage over time
- Daily/weekly trends
- Export to CSV

---

## Considering

These might happen, still evaluating:

### Fan Control
- Monitor fan speeds
- Manual fan speed override (requires SMC access)

### Startup Time
- Track how long your Mac takes to boot
- Identify slow login items

### Duplicate File Finder
- Find and remove duplicate files
- Similar photo detection

### Disk Health
- SMART status for drives
- Early warning for failing disks

---

## Not Planned

Things that won't be added:

### Windows/Linux Support
The app is built specifically for macOS using native APIs. Cross-platform would require a complete rewrite.

### iOS/iPad Version
Different platform, different needs. Maybe a separate project someday.

### Antivirus/Malware Scanner
Out of scope. Use dedicated security software for that.

---

## Suggest a Feature

Have an idea? [Open an issue](https://github.com/sulimanapps/SystemMonitor/issues) with the label "feature request".

Please include:
- What the feature does
- Why it's useful
- How you'd expect it to work
