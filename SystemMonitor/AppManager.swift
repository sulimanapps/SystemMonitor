import Foundation
import AppKit

// MARK: - App Info Model
struct InstalledApp: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let bundleID: String?
    let size: UInt64
    let icon: NSImage?
    let isSystemApp: Bool
    let isRunning: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - App Manager
class AppManager: ObservableObject {
    @Published var installedApps: [InstalledApp] = []
    @Published var isScanning = false
    @Published var isUninstalling = false
    @Published var uninstallProgress: Double = 0
    @Published var currentAppBeingUninstalled: String = ""

    // System apps that should NEVER be uninstalled
    private let systemAppNames: Set<String> = [
        "Safari", "Mail", "App Store", "System Preferences", "System Settings",
        "Finder", "Terminal", "Utilities", "Activity Monitor", "Console",
        "Disk Utility", "Font Book", "Keychain Access", "Migration Assistant",
        "Screenshot", "Preview", "TextEdit", "Time Machine", "Siri",
        "FaceTime", "Messages", "Calendar", "Contacts", "Reminders", "Notes",
        "Books", "News", "Stocks", "Home", "Voice Memos", "Photos",
        "Music", "Podcasts", "TV", "Maps", "Weather", "Clock",
        "Calculator", "Dictionary", "Archive Utility", "Bluetooth File Exchange",
        "Boot Camp Assistant", "ColorSync Utility", "Digital Color Meter",
        "Directory Utility", "Grapher", "MIDI Audio Setup", "Script Editor",
        "System Information", "VoiceOver Utility", "Automator", "Image Capture",
        "Launchpad", "Mission Control", "Stickies", "Chess", "DVD Player",
        "Photo Booth", "QuickTime Player", "AirPort Utility", "Audio MIDI Setup"
    ]

    private let systemBundleIDPrefixes: Set<String> = [
        "com.apple."
    ]

    func scanApps() {
        isScanning = true
        installedApps = []

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var apps: [InstalledApp] = []
            let fileManager = FileManager.default

            // Get running apps
            let runningApps = NSWorkspace.shared.runningApplications
            let runningBundleIDs = Set(runningApps.compactMap { $0.bundleIdentifier })

            // Scan /Applications
            let systemAppsPath = "/Applications"
            if let contents = try? fileManager.contentsOfDirectory(atPath: systemAppsPath) {
                for item in contents {
                    if item.hasSuffix(".app") {
                        let fullPath = "\(systemAppsPath)/\(item)"
                        if let app = self.createAppInfo(from: fullPath, runningBundleIDs: runningBundleIDs) {
                            apps.append(app)
                        }
                    }
                }
            }

            // Scan ~/Applications
            let userAppsPath = NSHomeDirectory() + "/Applications"
            if let contents = try? fileManager.contentsOfDirectory(atPath: userAppsPath) {
                for item in contents {
                    if item.hasSuffix(".app") {
                        let fullPath = "\(userAppsPath)/\(item)"
                        if let app = self.createAppInfo(from: fullPath, runningBundleIDs: runningBundleIDs) {
                            apps.append(app)
                        }
                    }
                }
            }

            // Sort by size (largest first)
            apps.sort { $0.size > $1.size }

            DispatchQueue.main.async {
                self.installedApps = apps
                self.isScanning = false
            }
        }
    }

    private func createAppInfo(from path: String, runningBundleIDs: Set<String>) -> InstalledApp? {
        let appName = (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")

        // Skip SystemMonitor itself
        if appName == "SystemMonitor" {
            return nil
        }

        // Get bundle info
        let bundle = Bundle(path: path)
        let bundleID = bundle?.bundleIdentifier

        // Check if system app
        let isSystemApp = systemAppNames.contains(appName) ||
            (bundleID != nil && systemBundleIDPrefixes.contains(where: { bundleID!.hasPrefix($0) }))

        // Check if running
        let isRunning = bundleID != nil && runningBundleIDs.contains(bundleID!)

        // Get size
        let size = getDirectorySize(path: path)

        // Get icon
        let icon = NSWorkspace.shared.icon(forFile: path)

        return InstalledApp(
            name: appName,
            path: path,
            bundleID: bundleID,
            size: size,
            icon: icon,
            isSystemApp: isSystemApp,
            isRunning: isRunning
        )
    }

    private func getDirectorySize(path: String) -> UInt64 {
        let fileManager = FileManager.default
        var totalSize: UInt64 = 0

        guard let enumerator = fileManager.enumerator(atPath: path) else {
            return 0
        }

        while let file = enumerator.nextObject() as? String {
            let fullPath = (path as NSString).appendingPathComponent(file)
            if let attributes = try? fileManager.attributesOfItem(atPath: fullPath),
               let size = attributes[.size] as? UInt64 {
                totalSize += size
            }
        }

        return totalSize
    }

    func uninstallApps(_ apps: [InstalledApp], completion: @escaping (Int, UInt64) -> Void) {
        guard !apps.isEmpty else {
            completion(0, 0)
            return
        }

        // Filter out system apps and SystemMonitor
        let safeApps = apps.filter { !$0.isSystemApp && $0.name != "SystemMonitor" }

        guard !safeApps.isEmpty else {
            completion(0, 0)
            return
        }

        isUninstalling = true
        uninstallProgress = 0

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let fileManager = FileManager.default
            var uninstalledCount = 0
            var freedSize: UInt64 = 0
            let totalApps = safeApps.count

            for (index, app) in safeApps.enumerated() {
                DispatchQueue.main.async {
                    self.currentAppBeingUninstalled = app.name
                    self.uninstallProgress = Double(index) / Double(totalApps)
                }

                // Check if app is running - skip if so
                if app.isRunning {
                    continue
                }

                var appFreedSize: UInt64 = app.size

                // Move app to Trash
                do {
                    try fileManager.trashItem(at: URL(fileURLWithPath: app.path), resultingItemURL: nil)
                    uninstalledCount += 1

                    // Clean up leftover files
                    if let bundleID = app.bundleID {
                        appFreedSize += self.cleanupAppLeftovers(appName: app.name, bundleID: bundleID)
                    }

                    freedSize += appFreedSize
                } catch {
                    print("Failed to uninstall \(app.name): \(error)")
                }
            }

            DispatchQueue.main.async {
                self.isUninstalling = false
                self.uninstallProgress = 1.0
                self.currentAppBeingUninstalled = ""
                self.scanApps() // Refresh list
                completion(uninstalledCount, freedSize)
            }
        }
    }

    private func cleanupAppLeftovers(appName: String, bundleID: String) -> UInt64 {
        let fileManager = FileManager.default
        let homeDir = NSHomeDirectory()
        var cleanedSize: UInt64 = 0

        // Paths to check for leftover files
        let leftoverPaths = [
            "\(homeDir)/Library/Application Support/\(appName)",
            "\(homeDir)/Library/Application Support/\(bundleID)",
            "\(homeDir)/Library/Caches/\(bundleID)",
            "\(homeDir)/Library/Caches/\(appName)",
            "\(homeDir)/Library/Preferences/\(bundleID).plist",
            "\(homeDir)/Library/Saved Application State/\(bundleID).savedState",
            "\(homeDir)/Library/Logs/\(appName)",
            "\(homeDir)/Library/Logs/\(bundleID)",
            "\(homeDir)/Library/Containers/\(bundleID)",
            "\(homeDir)/Library/Group Containers/\(bundleID)",
            "\(homeDir)/Library/WebKit/\(bundleID)"
        ]

        for path in leftoverPaths {
            if fileManager.fileExists(atPath: path) {
                // Get size before deleting
                let size = getDirectorySize(path: path)

                do {
                    try fileManager.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
                    cleanedSize += size
                } catch {
                    // Silently continue if we can't delete some files
                }
            }
        }

        return cleanedSize
    }

    func terminateApp(_ app: InstalledApp) {
        guard let bundleID = app.bundleID else { return }

        let runningApps = NSWorkspace.shared.runningApplications
        for runningApp in runningApps {
            if runningApp.bundleIdentifier == bundleID {
                runningApp.terminate()
            }
        }

        // Refresh running status after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.scanApps()
        }
    }
}
