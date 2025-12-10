import Foundation
import IOKit
import IOKit.storage

struct DiskHealthInfo: Identifiable {
    let id = UUID()
    let name: String
    let model: String
    let serialNumber: String
    let capacity: UInt64
    let isSSD: Bool
    let healthStatus: DiskHealthStatus
    let temperature: Int?
    let powerOnHours: Int?
    let powerCycleCount: Int?
    let readErrorRate: Int?
    let reallocatedSectors: Int?
    let wearLevelingCount: Int?
}

enum DiskHealthStatus: String {
    case healthy = "Healthy"
    case warning = "Warning"
    case critical = "Critical"
    case unknown = "Unknown"

    var color: String {
        switch self {
        case .healthy: return "green"
        case .warning: return "yellow"
        case .critical: return "red"
        case .unknown: return "gray"
        }
    }

    var icon: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

class DiskHealthManager: ObservableObject {
    @Published var disks: [DiskHealthInfo] = []
    @Published var isScanning = false
    @Published var lastScanDate: Date?

    func scanDisks() {
        isScanning = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var diskInfos: [DiskHealthInfo] = []

            // Get disk information using diskutil
            let diskInfo = self.getDiskInfo()
            diskInfos.append(contentsOf: diskInfo)

            DispatchQueue.main.async {
                self.disks = diskInfos
                self.isScanning = false
                self.lastScanDate = Date()
            }
        }
    }

    private func getDiskInfo() -> [DiskHealthInfo] {
        var disks: [DiskHealthInfo] = []

        // Use diskutil to get disk information
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["list", "-plist"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()

            if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
               let allDisks = plist["AllDisksAndPartitions"] as? [[String: Any]] {

                for disk in allDisks {
                    guard let deviceIdentifier = disk["DeviceIdentifier"] as? String,
                          deviceIdentifier.hasPrefix("disk") && !deviceIdentifier.contains("s") else { continue }

                    let size = disk["Size"] as? UInt64 ?? 0

                    // Get detailed info for this disk
                    if let detailedInfo = getDetailedDiskInfo(deviceIdentifier: deviceIdentifier) {
                        let healthStatus = determineDiskHealth(info: detailedInfo)

                        let diskInfo = DiskHealthInfo(
                            name: detailedInfo["name"] ?? deviceIdentifier,
                            model: detailedInfo["model"] ?? "Unknown",
                            serialNumber: detailedInfo["serial"] ?? "N/A",
                            capacity: size,
                            isSSD: detailedInfo["isSSD"] == "true",
                            healthStatus: healthStatus,
                            temperature: Int(detailedInfo["temperature"] ?? ""),
                            powerOnHours: Int(detailedInfo["powerOnHours"] ?? ""),
                            powerCycleCount: Int(detailedInfo["powerCycleCount"] ?? ""),
                            readErrorRate: nil,
                            reallocatedSectors: nil,
                            wearLevelingCount: nil
                        )
                        disks.append(diskInfo)
                    }
                }
            }
        } catch {
            // Fallback: create basic disk info
            disks.append(createBasicDiskInfo())
        }

        if disks.isEmpty {
            disks.append(createBasicDiskInfo())
        }

        return disks
    }

    private func getDetailedDiskInfo(deviceIdentifier: String) -> [String: String]? {
        var info: [String: String] = [:]

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", "-plist", deviceIdentifier]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()

            if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                info["name"] = plist["MediaName"] as? String ?? plist["IORegistryEntryName"] as? String ?? deviceIdentifier
                info["model"] = plist["DeviceModel"] as? String ?? "Unknown"
                info["serial"] = plist["DeviceSerialNumber"] as? String ?? "N/A"
                info["isSSD"] = (plist["SolidState"] as? Bool ?? false) ? "true" : "false"

                // Check for internal vs external
                let isInternal = plist["Internal"] as? Bool ?? true
                info["isInternal"] = isInternal ? "true" : "false"
            }
        } catch {
            return nil
        }

        // Try to get S.M.A.R.T. data using system_profiler
        if let smartData = getSMARTData(deviceIdentifier: deviceIdentifier) {
            info.merge(smartData) { _, new in new }
        }

        return info.isEmpty ? nil : info
    }

    private func getSMARTData(deviceIdentifier: String) -> [String: String]? {
        var smartInfo: [String: String] = [:]

        // Use system_profiler for storage info
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPStorageDataType", "-json"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let storageData = json["SPStorageDataType"] as? [[String: Any]] {

                for storage in storageData {
                    if let smartStatus = storage["smart_status"] as? String {
                        smartInfo["smartStatus"] = smartStatus
                    }
                }
            }
        } catch {
            // S.M.A.R.T. data not available
        }

        return smartInfo.isEmpty ? nil : smartInfo
    }

    private func determineDiskHealth(info: [String: String]) -> DiskHealthStatus {
        // Check S.M.A.R.T. status if available
        if let smartStatus = info["smartStatus"] {
            switch smartStatus.lowercased() {
            case "verified", "ok", "passed":
                return .healthy
            case "failing", "failed":
                return .critical
            default:
                break
            }
        }

        // Default to healthy if no issues detected
        return .healthy
    }

    private func createBasicDiskInfo() -> DiskHealthInfo {
        // Get basic disk info from FileManager
        let fileManager = FileManager.default
        var totalSpace: UInt64 = 0

        do {
            let attrs = try fileManager.attributesOfFileSystem(forPath: "/")
            totalSpace = attrs[.systemSize] as? UInt64 ?? 0
        } catch {}

        // Determine if Mac has SSD (most modern Macs do)
        let isSSD = true // Default assumption for modern Macs

        return DiskHealthInfo(
            name: "Macintosh HD",
            model: getMacModel(),
            serialNumber: "N/A",
            capacity: totalSpace,
            isSSD: isSSD,
            healthStatus: .healthy,
            temperature: nil,
            powerOnHours: nil,
            powerCycleCount: nil,
            readErrorRate: nil,
            reallocatedSectors: nil,
            wearLevelingCount: nil
        )
    }

    private func getMacModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1000 {
            return String(format: "%.1f TB", gb / 1024)
        } else if gb >= 1 {
            return String(format: "%.0f GB", gb)
        } else {
            let mb = Double(bytes) / 1_048_576
            return String(format: "%.0f MB", mb)
        }
    }
}
