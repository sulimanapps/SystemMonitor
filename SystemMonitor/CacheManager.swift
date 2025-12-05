import Foundation

struct DeletedFileEntry: Identifiable {
    let id = UUID()
    let path: String
    let size: UInt64
    let timestamp: Date
}

class CacheManager: ObservableObject {
    @Published var isScanning: Bool = false
    @Published var isCleaning: Bool = false
    @Published var cleaningProgress: Double = 0
    @Published var cacheBreakdown: CacheBreakdown = CacheBreakdown()
    @Published var lastCleanedAmount: UInt64 = 0
    @Published var cleaningComplete: Bool = false
    @Published var deletedFiles: [DeletedFileEntry] = []
    @Published var currentlyDeleting: String = ""

    struct CacheBreakdown {
        var browserCache: UInt64 = 0
        var appCache: UInt64 = 0
        var xcodeData: UInt64 = 0
        var logs: UInt64 = 0
        var tempFiles: UInt64 = 0

        var total: UInt64 {
            browserCache + appCache + xcodeData + logs + tempFiles
        }
    }

    struct CacheLocation {
        let path: String
        let category: CacheCategory
        let description: String
    }

    enum CacheCategory {
        case browser
        case app
        case xcode
        case logs
        case temp
    }

    // Safe cache locations to clean
    private let cacheLocations: [CacheLocation] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            // Browser caches
            CacheLocation(path: "\(home)/Library/Caches/com.apple.Safari", category: .browser, description: "Safari Cache"),
            CacheLocation(path: "\(home)/Library/Caches/Google/Chrome", category: .browser, description: "Chrome Cache"),
            CacheLocation(path: "\(home)/Library/Caches/Firefox", category: .browser, description: "Firefox Cache"),
            CacheLocation(path: "\(home)/Library/Caches/com.google.Chrome", category: .browser, description: "Chrome Cache"),
            CacheLocation(path: "\(home)/Library/Caches/org.mozilla.firefox", category: .browser, description: "Firefox Cache"),

            // Xcode
            CacheLocation(path: "\(home)/Library/Developer/Xcode/DerivedData", category: .xcode, description: "Xcode DerivedData"),
            CacheLocation(path: "\(home)/Library/Developer/Xcode/Archives", category: .xcode, description: "Xcode Archives"),

            // Logs
            CacheLocation(path: "\(home)/Library/Logs", category: .logs, description: "User Logs"),

            // Temp files
            CacheLocation(path: "/tmp", category: .temp, description: "Temporary Files"),
        ]
    }()

    // Directories to exclude from app cache cleaning
    private let excludedCacheDirectories: Set<String> = [
        "CloudKit",
        "com.apple.nsurlsessiond",
        "com.apple.HomeKit",
        "com.apple.Safari",  // Handled separately
        "Google",  // Handled separately
        "Firefox", // Handled separately
        "com.google.Chrome",
        "org.mozilla.firefox",
        "com.apple.bird",
        "com.apple.iCloudHelper",
        "com.apple.ap.adprivacyd",
        "com.apple.parsecd",
    ]

    func scanCaches() {
        isScanning = true
        cleaningComplete = false

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var breakdown = CacheBreakdown()
            let fileManager = FileManager.default
            let home = fileManager.homeDirectoryForCurrentUser.path

            // Scan specific cache locations
            for location in self.cacheLocations {
                let size = self.calculateDirectorySize(path: location.path)

                switch location.category {
                case .browser:
                    breakdown.browserCache += size
                case .app:
                    breakdown.appCache += size
                case .xcode:
                    breakdown.xcodeData += size
                case .logs:
                    breakdown.logs += size
                case .temp:
                    breakdown.tempFiles += size
                }
            }

            // Scan general app caches
            let appCachePath = "\(home)/Library/Caches"
            if let contents = try? fileManager.contentsOfDirectory(atPath: appCachePath) {
                for item in contents {
                    if !self.excludedCacheDirectories.contains(item) &&
                       !item.hasPrefix("com.apple.") &&
                       !item.hasPrefix("Google") &&
                       !item.hasPrefix("Firefox") {
                        let itemPath = "\(appCachePath)/\(item)"
                        breakdown.appCache += self.calculateDirectorySize(path: itemPath)
                    }
                }
            }

            // Scan Application Support caches
            let appSupportPath = "\(home)/Library/Application Support"
            if let contents = try? fileManager.contentsOfDirectory(atPath: appSupportPath) {
                for item in contents {
                    let cachePath = "\(appSupportPath)/\(item)/Cache"
                    if fileManager.fileExists(atPath: cachePath) {
                        breakdown.appCache += self.calculateDirectorySize(path: cachePath)
                    }
                    let cachesPath = "\(appSupportPath)/\(item)/Caches"
                    if fileManager.fileExists(atPath: cachesPath) {
                        breakdown.appCache += self.calculateDirectorySize(path: cachesPath)
                    }
                }
            }

            DispatchQueue.main.async {
                self.cacheBreakdown = breakdown
                self.isScanning = false
            }
        }
    }

    func cleanCaches(completion: @escaping (UInt64) -> Void) {
        isCleaning = true
        cleaningProgress = 0
        cleaningComplete = false
        deletedFiles = []
        currentlyDeleting = ""

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var totalCleaned: UInt64 = 0
            let totalSteps = 5.0
            var currentStep = 0.0

            // Clean browser caches
            totalCleaned += self.cleanBrowserCaches()
            currentStep += 1
            DispatchQueue.main.async { self.cleaningProgress = currentStep / totalSteps }

            // Clean Xcode data
            totalCleaned += self.cleanXcodeData()
            currentStep += 1
            DispatchQueue.main.async { self.cleaningProgress = currentStep / totalSteps }

            // Clean app caches
            totalCleaned += self.cleanAppCaches()
            currentStep += 1
            DispatchQueue.main.async { self.cleaningProgress = currentStep / totalSteps }

            // Clean logs
            totalCleaned += self.cleanLogs()
            currentStep += 1
            DispatchQueue.main.async { self.cleaningProgress = currentStep / totalSteps }

            // Clean temp files
            totalCleaned += self.cleanTempFiles()
            currentStep += 1
            DispatchQueue.main.async { self.cleaningProgress = currentStep / totalSteps }

            DispatchQueue.main.async {
                self.lastCleanedAmount = totalCleaned
                self.isCleaning = false
                self.cleaningComplete = true
                self.cleaningProgress = 1.0
                self.currentlyDeleting = ""
                completion(totalCleaned)
            }
        }
    }

    private func logDeletedFile(path: String, size: UInt64) {
        DispatchQueue.main.async { [weak self] in
            let entry = DeletedFileEntry(path: path, size: size, timestamp: Date())
            self?.deletedFiles.append(entry)
            self?.currentlyDeleting = path
        }
    }

    private func formatPathForDisplay(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + String(path.dropFirst(home.count))
        }
        return path
    }

    private func cleanBrowserCaches() -> UInt64 {
        var cleaned: UInt64 = 0
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        let browserPaths = [
            "\(home)/Library/Caches/com.apple.Safari",
            "\(home)/Library/Caches/Google/Chrome",
            "\(home)/Library/Caches/com.google.Chrome",
            "\(home)/Library/Caches/Firefox",
            "\(home)/Library/Caches/org.mozilla.firefox",
        ]

        for path in browserPaths {
            cleaned += deleteContentsOfDirectory(path: path)
        }

        return cleaned
    }

    private func cleanXcodeData() -> UInt64 {
        var cleaned: UInt64 = 0
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // Clean DerivedData
        let derivedDataPath = "\(home)/Library/Developer/Xcode/DerivedData"
        cleaned += deleteContentsOfDirectory(path: derivedDataPath)

        return cleaned
    }

    private func cleanAppCaches() -> UInt64 {
        var cleaned: UInt64 = 0
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path

        // Clean general app caches
        let appCachePath = "\(home)/Library/Caches"
        if let contents = try? fileManager.contentsOfDirectory(atPath: appCachePath) {
            for item in contents {
                if !excludedCacheDirectories.contains(item) &&
                   !item.hasPrefix("com.apple.") &&
                   !item.hasPrefix("Google") &&
                   !item.hasPrefix("Firefox") {
                    let itemPath = "\(appCachePath)/\(item)"
                    cleaned += deleteContentsOfDirectory(path: itemPath)
                }
            }
        }

        // Clean Application Support caches
        let appSupportPath = "\(home)/Library/Application Support"
        if let contents = try? fileManager.contentsOfDirectory(atPath: appSupportPath) {
            for item in contents {
                let cachePath = "\(appSupportPath)/\(item)/Cache"
                cleaned += deleteContentsOfDirectory(path: cachePath)
                let cachesPath = "\(appSupportPath)/\(item)/Caches"
                cleaned += deleteContentsOfDirectory(path: cachesPath)
            }
        }

        return cleaned
    }

    private func cleanLogs() -> UInt64 {
        var cleaned: UInt64 = 0
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let logsPath = "\(home)/Library/Logs"

        cleaned += deleteContentsOfDirectory(path: logsPath)

        return cleaned
    }

    private func cleanTempFiles() -> UInt64 {
        var cleaned: UInt64 = 0
        let fileManager = FileManager.default

        // Clean /tmp (only user-owned files)
        if let contents = try? fileManager.contentsOfDirectory(atPath: "/tmp") {
            for item in contents {
                let itemPath = "/tmp/\(item)"
                // Only delete files owned by current user
                if let attrs = try? fileManager.attributesOfItem(atPath: itemPath),
                   let ownerID = attrs[.ownerAccountID] as? NSNumber,
                   ownerID.uint32Value == getuid() {
                    let size = calculateDirectorySize(path: itemPath)
                    do {
                        try fileManager.removeItem(atPath: itemPath)
                        cleaned += size
                        logDeletedFile(path: formatPathForDisplay(itemPath), size: size)
                    } catch {
                        // Skip files in use or permission denied
                    }
                }
            }
        }

        return cleaned
    }

    private func deleteContentsOfDirectory(path: String) -> UInt64 {
        let fileManager = FileManager.default
        var deleted: UInt64 = 0

        guard fileManager.fileExists(atPath: path) else { return 0 }

        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            for item in contents {
                let itemPath = "\(path)/\(item)"

                // Skip .app files
                if item.hasSuffix(".app") { continue }

                // Skip system-critical files
                if item.hasPrefix(".") && !item.hasPrefix(".cache") { continue }

                let size = calculateDirectorySize(path: itemPath)

                do {
                    try fileManager.removeItem(atPath: itemPath)
                    deleted += size
                    logDeletedFile(path: formatPathForDisplay(itemPath), size: size)
                } catch {
                    // File in use or permission denied - skip
                }
            }
        } catch {
            // Directory doesn't exist or can't be read
        }

        return deleted
    }

    private func calculateDirectorySize(path: String) -> UInt64 {
        let fileManager = FileManager.default
        var totalSize: UInt64 = 0

        guard fileManager.fileExists(atPath: path) else { return 0 }

        // Check if it's a file
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: path, isDirectory: &isDirectory)

        if !isDirectory.boolValue {
            if let attrs = try? fileManager.attributesOfItem(atPath: path),
               let size = attrs[.size] as? UInt64 {
                return size
            }
            return 0
        }

        // It's a directory
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

    // Format bytes to human readable
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
