import Foundation
import AppKit

// MARK: - App Leftover File
struct AppLeftoverFile: Identifiable {
    let id = UUID()
    let path: String
    let name: String
    let size: UInt64
    let type: LeftoverType

    enum LeftoverType: String {
        case preferences = "Preferences"
        case cache = "Cache"
        case applicationSupport = "App Support"
        case savedState = "Saved State"
        case logs = "Logs"
        case containers = "Containers"
        case other = "Other"
    }
}

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
    let lastUsed: Date?
    var relatedFiles: [AppLeftoverFile]
    var relatedFilesLoaded: Bool

    init(name: String, path: String, bundleID: String?, size: UInt64, icon: NSImage?, isSystemApp: Bool, isRunning: Bool, lastUsed: Date? = nil, relatedFiles: [AppLeftoverFile] = [], relatedFilesLoaded: Bool = false) {
        self.name = name
        self.path = path
        self.bundleID = bundleID
        self.size = size
        self.icon = icon
        self.isSystemApp = isSystemApp
        self.isRunning = isRunning
        self.lastUsed = lastUsed
        self.relatedFiles = relatedFiles
        self.relatedFilesLoaded = relatedFilesLoaded
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.id == rhs.id
    }

    var totalSize: UInt64 {
        size + relatedFiles.reduce(0) { $0 + $1.size }
    }
}

// MARK: - App Manager
class AppManager: ObservableObject {
    @Published var installedApps: [InstalledApp] = []
    @Published var leftoverFiles: [AppLeftoverFile] = []
    @Published var isScanning = false
    @Published var isScanningLeftovers = false
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

            // Scan /Applications - quick scan without size
            let systemAppsPath = "/Applications"
            if let contents = try? fileManager.contentsOfDirectory(atPath: systemAppsPath) {
                for item in contents {
                    if item.hasSuffix(".app") {
                        let fullPath = "\(systemAppsPath)/\(item)"
                        if let app = self.createAppInfoFast(from: fullPath, runningBundleIDs: runningBundleIDs) {
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
                        if let app = self.createAppInfoFast(from: fullPath, runningBundleIDs: runningBundleIDs) {
                            apps.append(app)
                        }
                    }
                }
            }

            // Sort alphabetically first (size will be calculated later)
            apps.sort { $0.name.lowercased() < $1.name.lowercased() }

            DispatchQueue.main.async {
                self.installedApps = apps
                self.isScanning = false

                // Calculate sizes in background
                self.calculateSizesInBackground()
            }
        }
    }

    private func calculateSizesInBackground() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            for (index, app) in self.installedApps.enumerated() {
                let size = self.getAppSizeFast(path: app.path)

                DispatchQueue.main.async {
                    if index < self.installedApps.count {
                        // Preserve all existing data, only update size
                        let currentApp = self.installedApps[index]
                        let updatedApp = InstalledApp(
                            name: currentApp.name,
                            path: currentApp.path,
                            bundleID: currentApp.bundleID,
                            size: size,
                            icon: currentApp.icon,
                            isSystemApp: currentApp.isSystemApp,
                            isRunning: currentApp.isRunning,
                            lastUsed: currentApp.lastUsed,
                            relatedFiles: currentApp.relatedFiles,
                            relatedFilesLoaded: currentApp.relatedFilesLoaded
                        )
                        self.installedApps[index] = updatedApp
                    }
                }
            }
        }
    }

    private func createAppInfoFast(from path: String, runningBundleIDs: Set<String>) -> InstalledApp? {
        let appName = (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")

        // Skip SystemMonitor itself
        if appName == "SystemMonitor" || appName == "SystemMonitor Pro" {
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

        // Get icon
        let icon = NSWorkspace.shared.icon(forFile: path)

        // Get last used date
        let lastUsed = getLastUsedDate(path: path)

        return InstalledApp(
            name: appName,
            path: path,
            bundleID: bundleID,
            size: 0,  // Will be calculated later
            icon: icon,
            isSystemApp: isSystemApp,
            isRunning: isRunning,
            lastUsed: lastUsed
        )
    }

    private func getLastUsedDate(path: String) -> Date? {
        let url = URL(fileURLWithPath: path)
        if let resourceValues = try? url.resourceValues(forKeys: [.contentAccessDateKey]) {
            return resourceValues.contentAccessDate
        }
        return nil
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

        // Get size (quick estimate using allocatedSize)
        let size = getAppSizeFast(path: path)

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

    private func getAppSizeFast(path: String) -> UInt64 {
        // Use URLResourceKey.totalFileAllocatedSizeKey for fast size calculation
        let url = URL(fileURLWithPath: path)

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return 0
        }

        var totalSize: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey]),
                  resourceValues.isRegularFile == true,
                  let size = resourceValues.totalFileAllocatedSize else {
                continue
            }
            totalSize += UInt64(size)
        }

        return totalSize
    }

    private func getDirectorySize(path: String) -> UInt64 {
        return getAppSizeFast(path: path)
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

        // Check if any app is in /Applications (needs admin)
        let needsAdmin = safeApps.contains { $0.path.hasPrefix("/Applications/") }

        if needsAdmin {
            // Use AppleScript to request admin privileges
            uninstallWithAdminPrivileges(apps: safeApps, completion: completion)
        } else {
            // User apps in ~/Applications - no admin needed
            uninstallUserApps(apps: safeApps, completion: completion)
        }
    }

    private func uninstallWithAdminPrivileges(apps: [InstalledApp], completion: @escaping (Int, UInt64) -> Void) {
        // Filter out running apps
        let appsToDelete = apps.filter { !$0.isRunning }

        guard !appsToDelete.isEmpty else {
            DispatchQueue.main.async {
                self.isUninstalling = false
                completion(0, 0)
            }
            return
        }

        // Build shell command to move apps to Trash
        // Using mv to ~/.Trash instead of rm for safety
        let trashPath = NSHomeDirectory() + "/.Trash"
        let moveCommands = appsToDelete.map { app -> String in
            // Escape single quotes for shell AND backslashes/quotes for AppleScript
            let escapedPath = app.path
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "'", with: "'\\''")
            let appName = (app.path as NSString).lastPathComponent
            let escapedAppName = appName
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "'", with: "'\\''")
            // Add timestamp to avoid conflicts if same app name exists in trash
            let timestamp = Int(Date().timeIntervalSince1970)
            return "mv '\(escapedPath)' '\(trashPath)/\(escapedAppName)_\(timestamp)'"
        }.joined(separator: " && ")

        // AppleScript with administrator privileges - this WILL prompt for password/Touch ID
        // Escape the entire command for AppleScript string
        let escapedForAppleScript = moveCommands
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        do shell script "\(escapedForAppleScript)" with administrator privileges
        """

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.currentAppBeingUninstalled = appsToDelete.first?.name ?? ""

            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)

                if error == nil {
                    // Success - calculate freed space and clean up leftovers
                    DispatchQueue.global(qos: .userInitiated).async {
                        var freedSize: UInt64 = 0

                        for app in appsToDelete {
                            freedSize += app.size
                            if let bundleID = app.bundleID {
                                freedSize += self.cleanupAppLeftovers(appName: app.name, bundleID: bundleID)
                            }
                        }

                        DispatchQueue.main.async {
                            self.isUninstalling = false
                            self.uninstallProgress = 1.0
                            self.currentAppBeingUninstalled = ""
                            self.scanApps()
                            // Bring app back to front after admin dialog
                            NSApp.activate(ignoringOtherApps: true)
                            completion(appsToDelete.count, freedSize)
                        }
                    }
                } else {
                    // User cancelled or error occurred
                    self.isUninstalling = false
                    self.uninstallProgress = 0
                    self.currentAppBeingUninstalled = ""
                    // Bring app back to front after admin dialog (even if cancelled)
                    NSApp.activate(ignoringOtherApps: true)
                    completion(0, 0)
                }
            } else {
                self.isUninstalling = false
                completion(0, 0)
            }
        }
    }

    private func uninstallUserApps(apps: [InstalledApp], completion: @escaping (Int, UInt64) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let fileManager = FileManager.default
            var uninstalledCount = 0
            var freedSize: UInt64 = 0
            let totalApps = apps.count

            for (index, app) in apps.enumerated() {
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
                self.scanApps()
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

    // MARK: - Force Quit and Uninstall
    func forceQuitAndUninstall(_ apps: [InstalledApp], completion: @escaping (Int, UInt64) -> Void) {
        // First, terminate all running apps
        let runningAppsToKill = apps.filter { $0.isRunning }

        for app in runningAppsToKill {
            terminateAppSync(app)
        }

        // Wait for apps to close, then proceed with uninstall
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.uninstallApps(apps, completion: completion)
        }
    }

    private func terminateAppSync(_ app: InstalledApp) {
        guard let bundleID = app.bundleID else { return }

        let runningApps = NSWorkspace.shared.runningApplications
        for runningApp in runningApps {
            if runningApp.bundleIdentifier == bundleID {
                runningApp.forceTerminate()
            }
        }
    }

    // MARK: - Get Related Files for App
    func getRelatedFiles(for app: InstalledApp) -> [AppLeftoverFile] {
        let fileManager = FileManager.default
        let homeDir = NSHomeDirectory()
        var relatedFiles: [AppLeftoverFile] = []

        // Build list of paths to check
        var pathsToCheck: [(String, AppLeftoverFile.LeftoverType)] = []

        // Always check by app name
        pathsToCheck.append(contentsOf: [
            ("\(homeDir)/Library/Application Support/\(app.name)", .applicationSupport),
            ("\(homeDir)/Library/Caches/\(app.name)", .cache),
            ("\(homeDir)/Library/Logs/\(app.name)", .logs)
        ])

        // If bundle ID exists, add those paths too
        if let bundleID = app.bundleID {
            pathsToCheck.append(contentsOf: [
                ("\(homeDir)/Library/Application Support/\(bundleID)", .applicationSupport),
                ("\(homeDir)/Library/Caches/\(bundleID)", .cache),
                ("\(homeDir)/Library/Preferences/\(bundleID).plist", .preferences),
                ("\(homeDir)/Library/Saved Application State/\(bundleID).savedState", .savedState),
                ("\(homeDir)/Library/Logs/\(bundleID)", .logs),
                ("\(homeDir)/Library/Containers/\(bundleID)", .containers),
                ("\(homeDir)/Library/WebKit/\(bundleID)", .cache),
                ("\(homeDir)/Library/HTTPStorages/\(bundleID)", .cache),
                ("\(homeDir)/Library/Cookies/\(bundleID).binarycookies", .cache)
            ])

            // Check Group Containers with partial match
            let groupContainersPath = "\(homeDir)/Library/Group Containers"
            if let contents = try? fileManager.contentsOfDirectory(atPath: groupContainersPath) {
                for item in contents {
                    if item.contains(bundleID) || item.contains(app.name) {
                        pathsToCheck.append(("\(groupContainersPath)/\(item)", .containers))
                    }
                }
            }
        }

        // Also search Application Support for folders containing app name
        let appSupportPath = "\(homeDir)/Library/Application Support"
        if let contents = try? fileManager.contentsOfDirectory(atPath: appSupportPath) {
            for item in contents {
                if item.lowercased().contains(app.name.lowercased()) && item != app.name {
                    pathsToCheck.append(("\(appSupportPath)/\(item)", .applicationSupport))
                }
            }
        }

        for (path, type) in pathsToCheck {
            if fileManager.fileExists(atPath: path) {
                let size = getAppSizeFast(path: path)
                let name = (path as NSString).lastPathComponent
                // Don't add duplicates
                if !relatedFiles.contains(where: { $0.path == path }) {
                    relatedFiles.append(AppLeftoverFile(path: path, name: name, size: size, type: type))
                }
            }
        }

        // Sort by size descending
        relatedFiles.sort { $0.size > $1.size }

        return relatedFiles
    }

    // MARK: - Scan for Leftover Files (orphaned files from deleted apps)
    func scanLeftoverFiles() {
        isScanningLeftovers = true
        leftoverFiles = []

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let fileManager = FileManager.default
            let homeDir = NSHomeDirectory()
            var foundLeftovers: [AppLeftoverFile] = []

            // Get list of installed app bundle IDs
            let installedBundleIDs = Set(self.installedApps.compactMap { $0.bundleID })
            let installedAppNames = Set(self.installedApps.map { $0.name })

            // Directories to scan for orphaned files
            let dirsToScan: [(String, AppLeftoverFile.LeftoverType)] = [
                ("\(homeDir)/Library/Application Support", .applicationSupport),
                ("\(homeDir)/Library/Caches", .cache),
                ("\(homeDir)/Library/Preferences", .preferences),
                ("\(homeDir)/Library/Saved Application State", .savedState),
                ("\(homeDir)/Library/Containers", .containers),
                ("\(homeDir)/Library/Group Containers", .containers)
            ]

            for (dirPath, type) in dirsToScan {
                guard let contents = try? fileManager.contentsOfDirectory(atPath: dirPath) else { continue }

                for item in contents {
                    // Skip system items
                    if item.hasPrefix("com.apple.") || item.hasPrefix(".") { continue }

                    let fullPath = "\(dirPath)/\(item)"

                    // Check if this belongs to an installed app
                    let belongsToInstalledApp = installedBundleIDs.contains(where: { item.contains($0) }) ||
                                                installedAppNames.contains(where: { item.lowercased().contains($0.lowercased()) })

                    if !belongsToInstalledApp {
                        let size = self.getAppSizeFast(path: fullPath)
                        if size > 1024 { // Only include if > 1KB
                            foundLeftovers.append(AppLeftoverFile(path: fullPath, name: item, size: size, type: type))
                        }
                    }
                }
            }

            // Sort by size
            foundLeftovers.sort { $0.size > $1.size }

            DispatchQueue.main.async {
                self.leftoverFiles = foundLeftovers
                self.isScanningLeftovers = false
            }
        }
    }

    // MARK: - Clean Leftover Files
    func cleanLeftoverFiles(_ files: [AppLeftoverFile], completion: @escaping (Int, UInt64) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fileManager = FileManager.default
            var cleanedCount = 0
            var cleanedSize: UInt64 = 0

            for file in files {
                do {
                    try fileManager.trashItem(at: URL(fileURLWithPath: file.path), resultingItemURL: nil)
                    cleanedCount += 1
                    cleanedSize += file.size
                } catch {
                    // Continue on error
                }
            }

            DispatchQueue.main.async {
                self?.scanLeftoverFiles() // Refresh list
                completion(cleanedCount, cleanedSize)
            }
        }
    }

    // MARK: - Reset App (delete preferences and caches but keep app)
    func resetApp(_ app: InstalledApp, completion: @escaping (Bool, UInt64) -> Void) {
        guard let bundleID = app.bundleID else {
            completion(false, 0)
            return
        }

        // Terminate app first if running
        let wasRunning = app.isRunning
        if wasRunning {
            terminateAppSync(app)
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Wait for app to close if it was running
            if wasRunning {
                Thread.sleep(forTimeInterval: 1.0)
            }
            guard let self = self else { return }

            let fileManager = FileManager.default
            let homeDir = NSHomeDirectory()
            var freedSize: UInt64 = 0

            // Paths to delete for reset (not the app itself)
            var resetPaths = [
                "\(homeDir)/Library/Preferences/\(bundleID).plist",
                "\(homeDir)/Library/Caches/\(bundleID)",
                "\(homeDir)/Library/Caches/\(app.name)",
                "\(homeDir)/Library/Application Support/\(bundleID)",
                "\(homeDir)/Library/Application Support/\(app.name)",
                "\(homeDir)/Library/Saved Application State/\(bundleID).savedState",
                "\(homeDir)/Library/HTTPStorages/\(bundleID)",
                "\(homeDir)/Library/Cookies/\(bundleID).binarycookies",
                "\(homeDir)/Library/WebKit/\(bundleID)",
                "\(homeDir)/Library/Containers/\(bundleID)"
            ]

            // Also search for app name variations in Application Support
            let appSupportPath = "\(homeDir)/Library/Application Support"
            if let contents = try? fileManager.contentsOfDirectory(atPath: appSupportPath) {
                for item in contents {
                    if item.lowercased().contains(app.name.lowercased()) {
                        resetPaths.append("\(appSupportPath)/\(item)")
                    }
                }
            }

            for path in resetPaths {
                if fileManager.fileExists(atPath: path) {
                    let size = self.getAppSizeFast(path: path)
                    do {
                        try fileManager.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
                        freedSize += size
                    } catch {
                        // Try direct removal if trash fails
                        do {
                            try fileManager.removeItem(atPath: path)
                            freedSize += size
                        } catch {
                            // Continue on error
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                self.scanApps() // Refresh
                completion(true, freedSize)
            }
        }
    }

    // MARK: - Update Related Files for App
    func loadRelatedFiles(for index: Int) {
        guard index < installedApps.count else { return }

        let app = installedApps[index]

        // Don't reload if already loaded
        if app.relatedFilesLoaded { return }

        // Run in background to not block UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let relatedFiles = self.getRelatedFiles(for: app)

            DispatchQueue.main.async {
                // Find by ID since index might have changed
                if let currentIndex = self.installedApps.firstIndex(where: { $0.id == app.id }) {
                    self.installedApps[currentIndex].relatedFiles = relatedFiles
                    self.installedApps[currentIndex].relatedFilesLoaded = true
                }
            }
        }
    }
}
