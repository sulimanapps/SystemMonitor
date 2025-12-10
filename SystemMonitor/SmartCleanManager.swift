import Foundation
import AppKit

// MARK: - Cleanable Item Model
struct CleanableItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: UInt64
    let category: CleanCategory
    let icon: String
    var isSelected: Bool = true
}

// MARK: - Clean Category
enum CleanCategory: String, CaseIterable {
    case systemCache = "System Cache"
    case browserCache = "Browser Cache"
    case appCache = "App Cache"
    case logs = "Logs"
    case tempFiles = "Temp Files"
    case downloads = "Old Downloads"
    case xcode = "Xcode Data"
    case leftovers = "App Leftovers"

    var icon: String {
        switch self {
        case .systemCache: return "internaldrive"
        case .browserCache: return "globe"
        case .appCache: return "app.badge.fill"
        case .logs: return "doc.text"
        case .tempFiles: return "clock.arrow.circlepath"
        case .downloads: return "arrow.down.circle"
        case .xcode: return "hammer"
        case .leftovers: return "trash"
        }
    }

    var color: String {
        switch self {
        case .systemCache: return "blue"
        case .browserCache: return "orange"
        case .appCache: return "purple"
        case .logs: return "gray"
        case .tempFiles: return "yellow"
        case .downloads: return "green"
        case .xcode: return "cyan"
        case .leftovers: return "red"
        }
    }

    var description: String {
        switch self {
        case .systemCache: return "macOS system caches"
        case .browserCache: return "Safari, Chrome, Firefox caches"
        case .appCache: return "Application caches"
        case .logs: return "Old log files"
        case .tempFiles: return "Temporary files"
        case .downloads: return "Old .dmg and .pkg files"
        case .xcode: return "DerivedData and build files"
        case .leftovers: return "Files from deleted apps"
        }
    }
}

// MARK: - Category Summary
struct CategorySummary: Identifiable {
    let id = UUID()
    let category: CleanCategory
    var size: UInt64
    var itemCount: Int
    var isSelected: Bool = true
}

// MARK: - Smart Clean Manager
class SmartCleanManager: ObservableObject {
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var scanProgress: Double = 0
    @Published var cleanProgress: Double = 0
    @Published var currentTask: String = ""

    @Published var categorySummaries: [CategorySummary] = []
    @Published var cleanableItems: [CleanableItem] = []

    @Published var cleanComplete = false
    @Published var totalCleaned: UInt64 = 0
    @Published var itemsCleaned: Int = 0

    // System cache directories to exclude
    private let excludedCacheDirectories: Set<String> = [
        "CloudKit",
        "com.apple.nsurlsessiond",
        "com.apple.HomeKit",
        "com.apple.bird",
        "com.apple.iCloudHelper",
        "com.apple.ap.adprivacyd",
        "com.apple.parsecd",
        "com.apple.accountsd",
        "com.apple.appstored",
        "com.apple.commerce",
        "com.apple.containermanagerd"
    ]

    var totalCleanableSize: UInt64 {
        categorySummaries.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }

    var selectedCategoriesCount: Int {
        categorySummaries.filter { $0.isSelected }.count
    }

    // MARK: - Scan All Categories
    func scanAll() {
        isScanning = true
        scanProgress = 0
        currentTask = "Preparing scan..."
        cleanableItems = []
        categorySummaries = []
        cleanComplete = false

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var items: [CleanableItem] = []
            var scannedPaths = Set<String>() // Track paths to avoid duplicates
            let totalSteps = 8.0
            var step = 0.0

            // Helper function to add items while avoiding duplicates
            func addItems(_ newItems: [CleanableItem]) {
                for item in newItems {
                    if !scannedPaths.contains(item.path) {
                        scannedPaths.insert(item.path)
                        items.append(item)
                    }
                }
            }

            // 1. System Cache
            self.updateProgress(step / totalSteps, task: "Scanning system cache...")
            addItems(self.scanSystemCache())
            step += 1

            // 2. Browser Cache
            self.updateProgress(step / totalSteps, task: "Scanning browser cache...")
            addItems(self.scanBrowserCache())
            step += 1

            // 3. App Cache
            self.updateProgress(step / totalSteps, task: "Scanning app cache...")
            addItems(self.scanAppCache())
            step += 1

            // 4. Logs
            self.updateProgress(step / totalSteps, task: "Scanning logs...")
            addItems(self.scanLogs())
            step += 1

            // 5. Temp Files
            self.updateProgress(step / totalSteps, task: "Scanning temp files...")
            addItems(self.scanTempFiles())
            step += 1

            // 6. Old Downloads
            self.updateProgress(step / totalSteps, task: "Scanning downloads...")
            addItems(self.scanOldDownloads())
            step += 1

            // 7. Xcode Data
            self.updateProgress(step / totalSteps, task: "Scanning Xcode data...")
            addItems(self.scanXcodeData())
            step += 1

            // 8. App Leftovers
            self.updateProgress(step / totalSteps, task: "Scanning leftovers...")
            addItems(self.scanLeftovers())
            step += 1

            // Build category summaries
            var summaries: [CleanCategory: (size: UInt64, count: Int)] = [:]
            for item in items {
                let current = summaries[item.category] ?? (0, 0)
                summaries[item.category] = (current.size + item.size, current.count + 1)
            }

            let categorySummaryList = CleanCategory.allCases.compactMap { category -> CategorySummary? in
                guard let data = summaries[category], data.size > 0 else { return nil }
                return CategorySummary(category: category, size: data.size, itemCount: data.count)
            }.sorted { $0.size > $1.size }

            DispatchQueue.main.async {
                self.cleanableItems = items
                self.categorySummaries = categorySummaryList
                self.isScanning = false
                self.scanProgress = 1.0
                self.currentTask = ""
            }
        }
    }

    private func updateProgress(_ progress: Double, task: String) {
        DispatchQueue.main.async {
            self.scanProgress = progress
            self.currentTask = task
        }
    }

    // MARK: - Scan Functions

    private func scanSystemCache() -> [CleanableItem] {
        var items: [CleanableItem] = []
        let home = NSHomeDirectory()
        let fileManager = FileManager.default

        // System cache in ~/Library/Caches (macOS system components, NOT browser caches)
        // NOTE: Browser caches are handled separately in scanBrowserCache()
        let systemCachePaths = [
            ("\(home)/Library/Caches/com.apple.helpd", "Help Index Cache"),
            ("\(home)/Library/Caches/com.apple.nsservicescache.plist", "Services Cache"),
            ("\(home)/Library/Caches/com.apple.preferencepanes.cache", "Preferences Cache"),
            ("\(home)/Library/Caches/com.apple.spotlight", "Spotlight Cache")
        ]

        for (path, name) in systemCachePaths {
            if fileManager.fileExists(atPath: path) {
                let size = calculateSize(path: path)
                if size > 512 * 1024 { // Only if > 512KB
                    items.append(CleanableItem(
                        name: name,
                        path: path,
                        size: size,
                        category: .systemCache,
                        icon: CleanCategory.systemCache.icon
                    ))
                }
            }
        }

        return items
    }

    private func scanBrowserCache() -> [CleanableItem] {
        var items: [CleanableItem] = []
        let home = NSHomeDirectory()
        let fileManager = FileManager.default

        // Safe browser cache paths (only caches, NOT user data like bookmarks/passwords)
        let browserPaths: [(String, String)] = [
            ("\(home)/Library/Caches/com.apple.Safari", "Safari Cache"),
            ("\(home)/Library/Caches/Google/Chrome", "Chrome Cache"),
            ("\(home)/Library/Caches/com.google.Chrome", "Chrome Cache"),
            ("\(home)/Library/Application Support/Google/Chrome/Default/Cache", "Chrome Data Cache"),
            ("\(home)/Library/Application Support/Google/Chrome/Default/Code Cache", "Chrome Code Cache"),
            ("\(home)/Library/Application Support/Google/Chrome/Default/GPUCache", "Chrome GPU Cache"),
            ("\(home)/Library/Caches/Firefox", "Firefox Cache"),
            ("\(home)/Library/Caches/org.mozilla.firefox", "Firefox Cache"),
            ("\(home)/Library/Caches/com.brave.Browser", "Brave Cache"),
            ("\(home)/Library/Caches/com.microsoft.edgemac", "Edge Cache"),
            ("\(home)/Library/Caches/com.operasoftware.Opera", "Opera Cache")
        ]
        // NOTE: Intentionally NOT including:
        // - Safari/LocalStorage (contains website data)
        // - Firefox/Profiles (contains passwords, bookmarks)
        // - Chrome/Default (except Cache folders)

        for (path, name) in browserPaths {
            if fileManager.fileExists(atPath: path) {
                let size = calculateSize(path: path)
                if size > 1024 * 1024 { // Only show if > 1MB
                    items.append(CleanableItem(
                        name: name,
                        path: path,
                        size: size,
                        category: .browserCache,
                        icon: CleanCategory.browserCache.icon
                    ))
                }
            }
        }

        return items
    }

    private func scanAppCache() -> [CleanableItem] {
        var items: [CleanableItem] = []
        let home = NSHomeDirectory()
        let fileManager = FileManager.default
        let cachePath = "\(home)/Library/Caches"

        guard let contents = try? fileManager.contentsOfDirectory(atPath: cachePath) else {
            return items
        }

        for item in contents {
            // Skip excluded directories
            if excludedCacheDirectories.contains(item) { continue }
            if item.hasPrefix("com.apple.") { continue }
            if item == "Google" || item == "Firefox" { continue } // Handled in browser
            if item.hasPrefix("com.google.") { continue }
            if item.hasPrefix("org.mozilla.") { continue }

            let itemPath = "\(cachePath)/\(item)"
            let size = calculateSize(path: itemPath)

            if size > 512 * 1024 { // Only show if > 512KB
                // Get app name from bundle ID
                let appName = getAppNameFromBundleID(item) ?? item
                items.append(CleanableItem(
                    name: "\(appName) Cache",
                    path: itemPath,
                    size: size,
                    category: .appCache,
                    icon: CleanCategory.appCache.icon
                ))
            }
        }

        return items
    }

    private func scanLogs() -> [CleanableItem] {
        var items: [CleanableItem] = []
        let home = NSHomeDirectory()
        let fileManager = FileManager.default
        let logsPath = "\(home)/Library/Logs"

        guard let contents = try? fileManager.contentsOfDirectory(atPath: logsPath) else {
            return items
        }

        // Get logs older than 7 days
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)

        for item in contents {
            let itemPath = "\(logsPath)/\(item)"

            if let attrs = try? fileManager.attributesOfItem(atPath: itemPath),
               let modDate = attrs[.modificationDate] as? Date,
               modDate < sevenDaysAgo {
                let size = calculateSize(path: itemPath)
                if size > 0 {
                    items.append(CleanableItem(
                        name: item,
                        path: itemPath,
                        size: size,
                        category: .logs,
                        icon: CleanCategory.logs.icon
                    ))
                }
            }
        }

        return items
    }

    private func scanTempFiles() -> [CleanableItem] {
        var items: [CleanableItem] = []
        let fileManager = FileManager.default

        // Scan user's temp directory
        let userTempDir = NSTemporaryDirectory()
        if let contents = try? fileManager.contentsOfDirectory(atPath: userTempDir) {
            for item in contents {
                let itemPath = "\(userTempDir)/\(item)"

                // Only delete user-owned files
                if let attrs = try? fileManager.attributesOfItem(atPath: itemPath),
                   let ownerID = attrs[.ownerAccountID] as? NSNumber,
                   ownerID.uint32Value == getuid() {
                    let size = calculateSize(path: itemPath)
                    if size > 1024 * 1024 { // Only show if > 1MB
                        items.append(CleanableItem(
                            name: item,
                            path: itemPath,
                            size: size,
                            category: .tempFiles,
                            icon: CleanCategory.tempFiles.icon
                        ))
                    }
                }
            }
        }

        return items
    }

    private func scanOldDownloads() -> [CleanableItem] {
        var items: [CleanableItem] = []
        let home = NSHomeDirectory()
        let fileManager = FileManager.default
        let downloadsPath = "\(home)/Downloads"

        guard let contents = try? fileManager.contentsOfDirectory(atPath: downloadsPath) else {
            return items
        }

        // Get files older than 30 days that are DEFINITELY installers (not general archives)
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        // Only disk images and packages - NOT zip/tar which could be important files
        let installerExtensions = ["dmg", "pkg", "iso"]

        for item in contents {
            let itemPath = "\(downloadsPath)/\(item)"
            let ext = (item as NSString).pathExtension.lowercased()

            if installerExtensions.contains(ext) {
                if let attrs = try? fileManager.attributesOfItem(atPath: itemPath),
                   let modDate = attrs[.modificationDate] as? Date,
                   modDate < thirtyDaysAgo {
                    let size = calculateSize(path: itemPath)
                    if size > 0 {
                        items.append(CleanableItem(
                            name: item,
                            path: itemPath,
                            size: size,
                            category: .downloads,
                            icon: CleanCategory.downloads.icon
                        ))
                    }
                }
            }
        }

        return items
    }

    private func scanXcodeData() -> [CleanableItem] {
        var items: [CleanableItem] = []
        let home = NSHomeDirectory()
        let fileManager = FileManager.default

        // SAFE to clean: DerivedData and Caches
        // NOT included: Archives (needed for App Store submissions)
        // NOT included: DeviceSupport (needed for debugging on devices)
        let xcodePaths: [(String, String)] = [
            ("\(home)/Library/Developer/Xcode/DerivedData", "Xcode DerivedData"),
            ("\(home)/Library/Developer/CoreSimulator/Caches", "Simulator Caches"),
            ("\(home)/Library/Developer/CoreSimulator/Devices", "Simulator Devices")
        ]
        // NOTE: We're NOT cleaning:
        // - Archives: User needs these for uploading to App Store
        // - iOS DeviceSupport: Required for debugging on physical devices
        // - watchOS DeviceSupport: Required for debugging on physical devices

        for (path, name) in xcodePaths {
            if fileManager.fileExists(atPath: path) {
                let size = calculateSize(path: path)
                if size > 10 * 1024 * 1024 { // Only show if > 10MB (Xcode stuff is usually big)
                    items.append(CleanableItem(
                        name: name,
                        path: path,
                        size: size,
                        category: .xcode,
                        icon: CleanCategory.xcode.icon
                    ))
                }
            }
        }

        return items
    }

    private func scanLeftovers() -> [CleanableItem] {
        var items: [CleanableItem] = []
        let home = NSHomeDirectory()
        let fileManager = FileManager.default

        // Critical folders that should NEVER be deleted from Application Support
        // Using lowercased set for case-insensitive matching
        let protectedAppSupportFolders: Set<String> = [
            "addressbook", "dock", "icloud", "clouddocs", "mobilesync",
            "knowledge", "callhistorydb", "syncservices", "google",
            "firefox", "sublime text", "code", "jetbrains", "microsoft",
            "adobe", "spotify", "discord", "slack", "zoom", "telegram",
            "steam", "epic", "1password", "bitwarden", "keychain",
            "crashreporter", "coresimulator", "developer", "obs-studio",
            "notion", "bear", "obsidian", "evernote", "dropbox", "onedrive",
            "virtualbox", "vmware", "parallels", "docker", "atom", "visual studio code"
        ]

        // Get all installed app bundle IDs AND app names
        var installedBundleIDs = Set<String>()
        var installedAppNames = Set<String>()
        let appPaths = ["/Applications", "\(home)/Applications"]

        for appPath in appPaths {
            if let contents = try? fileManager.contentsOfDirectory(atPath: appPath) {
                for app in contents where app.hasSuffix(".app") {
                    // Store app name without .app extension
                    let appName = String(app.dropLast(4))
                    installedAppNames.insert(appName.lowercased())

                    let plistPath = "\(appPath)/\(app)/Contents/Info.plist"
                    if let plist = NSDictionary(contentsOfFile: plistPath),
                       let bundleID = plist["CFBundleIdentifier"] as? String {
                        installedBundleIDs.insert(bundleID)
                        // Also extract last component of bundle ID
                        if let lastPart = bundleID.components(separatedBy: ".").last {
                            installedAppNames.insert(lastPart.lowercased())
                        }
                    }
                }
            }
        }

        // Scan for orphaned preferences (only large ones > 10KB to avoid noise)
        let prefsPath = "\(home)/Library/Preferences"
        if let contents = try? fileManager.contentsOfDirectory(atPath: prefsPath) {
            for item in contents where item.hasSuffix(".plist") {
                let bundleID = String(item.dropLast(6)) // Remove .plist

                // Skip Apple prefs
                if bundleID.hasPrefix("com.apple.") { continue }
                if bundleID.hasPrefix("group.com.apple.") { continue }

                // Skip if bundle ID matches installed app
                if installedBundleIDs.contains(bundleID) { continue }

                // Skip if any part of bundle ID matches installed app name
                let bundleParts = bundleID.lowercased().components(separatedBy: ".")
                let matchesInstalled = bundleParts.contains { part in
                    installedAppNames.contains(part)
                }
                if matchesInstalled { continue }

                let itemPath = "\(prefsPath)/\(item)"
                let size = calculateSize(path: itemPath)

                // Only show if > 10KB (small prefs are harmless)
                if size > 10 * 1024 {
                    items.append(CleanableItem(
                        name: "\(bundleID) Preferences",
                        path: itemPath,
                        size: size,
                        category: .leftovers,
                        icon: CleanCategory.leftovers.icon
                    ))
                }
            }
        }

        // Scan for orphaned Application Support (be VERY conservative)
        let appSupportPath = "\(home)/Library/Application Support"
        if let contents = try? fileManager.contentsOfDirectory(atPath: appSupportPath) {
            for item in contents {
                // Skip protected folders (case-insensitive)
                if protectedAppSupportFolders.contains(item.lowercased()) { continue }
                if item.hasPrefix("com.apple.") { continue }
                if item.hasPrefix(".") { continue } // Hidden folders

                let itemLower = item.lowercased()

                // Check if folder name matches any installed app
                if installedAppNames.contains(itemLower) { continue }

                // Check if any installed app name is contained in folder name
                let matchesAnyApp = installedAppNames.contains { appName in
                    itemLower.contains(appName) || appName.contains(itemLower)
                }
                if matchesAnyApp { continue }

                // Check if any bundle ID matches
                let matchesBundleID = installedBundleIDs.contains { bundleID in
                    bundleID.lowercased().contains(itemLower)
                }
                if matchesBundleID { continue }

                // Check if app with this name exists
                let appExists = appPaths.contains { path in
                    fileManager.fileExists(atPath: "\(path)/\(item).app")
                }
                if appExists { continue }

                let itemPath = "\(appSupportPath)/\(item)"
                let size = calculateSize(path: itemPath)

                // Only show if > 5MB (to avoid noise)
                if size > 5 * 1024 * 1024 {
                    items.append(CleanableItem(
                        name: "\(item) Data",
                        path: itemPath,
                        size: size,
                        category: .leftovers,
                        icon: CleanCategory.leftovers.icon
                    ))
                }
            }
        }

        return items
    }

    // MARK: - Clean Functions

    func cleanSelected() {
        isCleaning = true
        cleanProgress = 0
        totalCleaned = 0
        itemsCleaned = 0
        cleanComplete = false

        // Get items from selected categories
        let selectedCategories = Set(categorySummaries.filter { $0.isSelected }.map { $0.category })
        let itemsToClean = cleanableItems.filter { selectedCategories.contains($0.category) }

        guard !itemsToClean.isEmpty else {
            isCleaning = false
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let fileManager = FileManager.default
            let total = itemsToClean.count

            // Use concurrent queue for parallel deletion
            let cleanQueue = DispatchQueue(label: "com.systemmonitor.clean", attributes: .concurrent)
            let group = DispatchGroup()

            // Thread-safe counters
            var cleaned: UInt64 = 0
            var count = 0
            var processedCount = 0
            var cleanedPaths = Set<String>()
            let lock = NSLock()

            for item in itemsToClean {
                group.enter()
                cleanQueue.async {
                    defer { group.leave() }

                    // Thread-safe check for duplicate paths
                    lock.lock()
                    if cleanedPaths.contains(item.path) {
                        lock.unlock()
                        return
                    }
                    cleanedPaths.insert(item.path)
                    processedCount += 1
                    let currentProgress = processedCount
                    lock.unlock()

                    // Safety check - never delete protected paths
                    if self.isProtectedPath(item.path) { return }

                    // Verify file still exists before trying to delete
                    guard fileManager.fileExists(atPath: item.path) else { return }

                    // Update progress on main thread (throttled)
                    if currentProgress % 5 == 0 || currentProgress == total {
                        DispatchQueue.main.async {
                            self.currentTask = "Cleaning \(item.name)..."
                            self.cleanProgress = Double(currentProgress) / Double(total)
                        }
                    }

                    do {
                        // Always use trashItem for safety (user can recover from Trash)
                        try fileManager.trashItem(at: URL(fileURLWithPath: item.path), resultingItemURL: nil)
                        lock.lock()
                        cleaned += item.size
                        count += 1
                        lock.unlock()
                    } catch {
                        // If trashItem fails (e.g., permission denied), skip the file
                        print("Failed to clean \(item.path): \(error.localizedDescription)")
                    }
                }
            }

            // Wait for all deletions to complete
            group.wait()

            DispatchQueue.main.async {
                self.totalCleaned = cleaned
                self.itemsCleaned = count
                self.cleanProgress = 1.0
                self.isCleaning = false
                self.cleanComplete = true
                self.currentTask = ""

                // Clear cleaned items from list
                self.cleanableItems.removeAll { item in
                    selectedCategories.contains(item.category)
                }
                self.categorySummaries.removeAll { $0.isSelected }
            }
        }
    }

    func cleanCategory(_ category: CleanCategory) {
        // Toggle only this category, clean it
        for i in categorySummaries.indices {
            categorySummaries[i].isSelected = (categorySummaries[i].category == category)
        }
        cleanSelected()
    }

    // MARK: - Helper Functions

    private func isProtectedPath(_ path: String) -> Bool {
        let home = NSHomeDirectory()

        // Paths inside user's home directory are generally safe
        // We're only cleaning from ~/Library/ which is user-writable
        if path.hasPrefix(home) {
            return false
        }

        // For paths outside home, be more careful
        // Only allow /tmp and specific system cache locations
        if path.hasPrefix("/tmp") || path.hasPrefix(NSTemporaryDirectory()) {
            return false
        }

        // Everything else outside user home is protected
        return true
    }

    private func calculateSize(path: String) -> UInt64 {
        // Use fast method with du command for directories
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: path) else { return 0 }

        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: path, isDirectory: &isDirectory)

        if !isDirectory.boolValue {
            // Single file - use attributes
            if let attrs = try? fileManager.attributesOfItem(atPath: path),
               let size = attrs[.size] as? UInt64 {
                return size
            }
            return 0
        }

        // Directory - use du command (MUCH faster than enumerating)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", path] // -s = summary, -k = kilobytes

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8),
               let sizeStr = output.split(separator: "\t").first,
               let sizeKB = UInt64(sizeStr) {
                return sizeKB * 1024 // Convert KB to bytes
            }
        } catch {
            // Fallback to slower method if du fails
            return calculateSizeSlow(path: path)
        }

        return 0
    }

    private func calculateSizeSlow(path: String) -> UInt64 {
        let fileManager = FileManager.default
        var totalSize: UInt64 = 0

        guard let enumerator = fileManager.enumerator(atPath: path) else { return 0 }

        while let file = enumerator.nextObject() as? String {
            let filePath = "\(path)/\(file)"
            if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
               let size = attrs[.size] as? UInt64 {
                totalSize += size
            }
        }

        return totalSize
    }

    private func getAppNameFromBundleID(_ bundleID: String) -> String? {
        // Try to find app name from bundle ID
        let components = bundleID.components(separatedBy: ".")
        if let lastComponent = components.last, !lastComponent.isEmpty {
            // Convert camelCase to spaces and capitalize
            var name = ""
            for char in lastComponent {
                if char.isUppercase && !name.isEmpty {
                    name += " "
                }
                name += String(char)
            }
            return name.capitalized
        }
        return nil
    }

    func toggleCategory(_ category: CleanCategory) {
        if let index = categorySummaries.firstIndex(where: { $0.category == category }) {
            categorySummaries[index].isSelected.toggle()
        }
    }

    func selectAll() {
        for i in categorySummaries.indices {
            categorySummaries[i].isSelected = true
        }
    }

    func deselectAll() {
        for i in categorySummaries.indices {
            categorySummaries[i].isSelected = false
        }
    }

    // MARK: - Format Helpers

    static func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        } else {
            let mb = Double(bytes) / 1_048_576
            if mb >= 1 {
                return String(format: "%.1f MB", mb)
            } else {
                let kb = Double(bytes) / 1024
                return String(format: "%.0f KB", kb)
            }
        }
    }
}
