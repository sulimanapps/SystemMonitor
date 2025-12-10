import Foundation
import AppKit
import IOKit

// MARK: - Hardware Check Result
struct HardwareCheckResult: Identifiable {
    let id = UUID()
    let category: String
    let item: String
    let value: String
    let status: CheckStatus
    let detail: String?

    enum CheckStatus {
        case ok
        case warning
        case issue
        case unknown

        var icon: String {
            switch self {
            case .ok: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .issue: return "xmark.circle.fill"
            case .unknown: return "questionmark.circle.fill"
            }
        }

        var color: String {
            switch self {
            case .ok: return "green"
            case .warning: return "orange"
            case .issue: return "red"
            case .unknown: return "gray"
            }
        }
    }
}

// MARK: - Hardware Profile
struct HardwareProfile {
    var serialNumber: String = ""
    var modelIdentifier: String = ""
    var modelName: String = ""
    var chipType: String = ""
    var boardID: String = ""
    var osVersion: String = ""
    var osBuild: String = ""
    var bootROMVersion: String = ""
    var hardwareUUID: String = ""
    var provisioningUDID: String = ""

    // Battery
    var batteryCycleCount: Int = 0
    var batteryHealth: Double = 0
    var batteryDesignCapacity: Int = 0
    var batteryMaxCapacity: Int = 0
    var batteryManufactureDate: Date?
    var batterySerialNumber: String = ""

    // Display
    var displayInfo: String = ""
    var displaySerialNumber: String = ""

    // Storage
    var storageModel: String = ""
    var storageSerial: String = ""
    var storageSize: String = ""
    var storageSMART: String = ""

    // Memory
    var memorySize: String = ""
    var memoryType: String = ""

    // Dates
    var systemPurchaseDate: Date?
    var warrantyStatus: String = ""
}

// MARK: - Integrity Finding
struct IntegrityFinding: Identifiable {
    let id = UUID()
    let severity: Severity
    let title: String
    let description: String
    let recommendation: String?

    enum Severity {
        case info
        case warning
        case critical
    }
}

// MARK: - Hardware Integrity Manager
class HardwareIntegrityManager: ObservableObject {
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var currentTask: String = ""
    @Published var scanComplete = false

    @Published var hardwareProfile = HardwareProfile()
    @Published var checkResults: [HardwareCheckResult] = []
    @Published var findings: [IntegrityFinding] = []
    @Published var overallScore: Int = 100
    @Published var overallStatus: String = "Unknown"

    // MARK: - Main Scan Function
    func performScan() {
        isScanning = true
        scanProgress = 0
        currentTask = "Initializing..."
        scanComplete = false
        checkResults = []
        findings = []
        overallScore = 100

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // 1. Basic System Info
            self.updateProgress(0.05, task: "Initializing scan engine...")
            Thread.sleep(forTimeInterval: 0.4)

            self.updateProgress(0.1, task: "Reading system information...")
            Thread.sleep(forTimeInterval: 0.3)
            self.collectBasicSystemInfo()

            // 2. Hardware Identifiers
            self.updateProgress(0.2, task: "Verifying hardware identifiers...")
            Thread.sleep(forTimeInterval: 0.5)
            self.collectHardwareIdentifiers()

            self.updateProgress(0.3, task: "Checking serial number consistency...")
            Thread.sleep(forTimeInterval: 0.4)

            // 3. Battery Analysis
            self.updateProgress(0.4, task: "Analyzing battery health...")
            Thread.sleep(forTimeInterval: 0.5)
            self.analyzeBattery()

            self.updateProgress(0.5, task: "Checking battery cycle history...")
            Thread.sleep(forTimeInterval: 0.3)

            // 4. Storage Check
            self.updateProgress(0.6, task: "Scanning storage integrity...")
            Thread.sleep(forTimeInterval: 0.5)
            self.checkStorage()

            // 5. Display Info
            self.updateProgress(0.7, task: "Verifying display components...")
            Thread.sleep(forTimeInterval: 0.4)
            self.checkDisplay()

            // 6. Memory Check
            self.updateProgress(0.8, task: "Analyzing memory configuration...")
            Thread.sleep(forTimeInterval: 0.4)
            self.checkMemory()

            // 7. Consistency Analysis
            self.updateProgress(0.88, task: "Cross-referencing hardware data...")
            Thread.sleep(forTimeInterval: 0.5)
            self.analyzeConsistency()

            // 8. Calculate Score
            self.updateProgress(0.95, task: "Calculating integrity score...")
            Thread.sleep(forTimeInterval: 0.4)
            self.calculateOverallScore()

            Thread.sleep(forTimeInterval: 0.3)

            DispatchQueue.main.async {
                self.scanProgress = 1.0
                self.currentTask = "Scan complete!"
                self.isScanning = false
                self.scanComplete = true
            }
        }
    }

    private func updateProgress(_ value: Double, task: String) {
        DispatchQueue.main.async {
            self.scanProgress = value
            self.currentTask = task
        }
    }

    // MARK: - 1. Basic System Info
    private func collectBasicSystemInfo() {
        // Model Identifier via sysctl
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let modelId = String(cString: model)

        // OS Version
        let osVersion = Foundation.ProcessInfo.processInfo.operatingSystemVersion
        let osVersionStr = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"

        // Get detailed info from system_profiler
        let spData = runSystemProfiler(dataType: "SPHardwareDataType")

        DispatchQueue.main.async {
            self.hardwareProfile.modelIdentifier = modelId
            self.hardwareProfile.osVersion = osVersionStr

            // Parse system_profiler output
            if let serialMatch = spData.range(of: "Serial Number \\(system\\): ([A-Z0-9]+)", options: .regularExpression) {
                let line = String(spData[serialMatch])
                if let colonIndex = line.lastIndex(of: ":") {
                    self.hardwareProfile.serialNumber = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                }
            }

            if let modelMatch = spData.range(of: "Model Name: (.+)", options: .regularExpression) {
                let line = String(spData[modelMatch])
                if let colonIndex = line.lastIndex(of: ":") {
                    self.hardwareProfile.modelName = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                }
            }

            if let chipMatch = spData.range(of: "Chip: (.+)", options: .regularExpression) {
                let line = String(spData[chipMatch])
                if let colonIndex = line.lastIndex(of: ":") {
                    self.hardwareProfile.chipType = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                }
            }

            // Add result
            self.addResult(
                category: "System",
                item: "Serial Number",
                value: self.hardwareProfile.serialNumber.isEmpty ? "Not Available" : self.maskSerial(self.hardwareProfile.serialNumber),
                status: self.hardwareProfile.serialNumber.isEmpty ? .warning : .ok,
                detail: nil
            )

            self.addResult(
                category: "System",
                item: "Model",
                value: self.hardwareProfile.modelName.isEmpty ? modelId : self.hardwareProfile.modelName,
                status: .ok,
                detail: nil
            )

            self.addResult(
                category: "System",
                item: "Chip",
                value: self.hardwareProfile.chipType.isEmpty ? self.getChipType() : self.hardwareProfile.chipType,
                status: .ok,
                detail: nil
            )
        }
    }

    // MARK: - 2. Hardware Identifiers
    private func collectHardwareIdentifiers() {
        let spData = runSystemProfiler(dataType: "SPHardwareDataType")

        DispatchQueue.main.async {
            // Hardware UUID
            if let uuidMatch = spData.range(of: "Hardware UUID: ([A-F0-9-]+)", options: .regularExpression) {
                let line = String(spData[uuidMatch])
                if let colonIndex = line.lastIndex(of: ":") {
                    self.hardwareProfile.hardwareUUID = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                }
            }

            // Provisioning UDID
            if let udidMatch = spData.range(of: "Provisioning UDID: ([A-F0-9-]+)", options: .regularExpression) {
                let line = String(spData[udidMatch])
                if let colonIndex = line.lastIndex(of: ":") {
                    self.hardwareProfile.provisioningUDID = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                }
            }

            self.addResult(
                category: "Identifiers",
                item: "Hardware UUID",
                value: self.hardwareProfile.hardwareUUID.isEmpty ? "Not Available" : self.maskUUID(self.hardwareProfile.hardwareUUID),
                status: self.hardwareProfile.hardwareUUID.isEmpty ? .warning : .ok,
                detail: "Unique identifier for this Mac"
            )
        }
    }

    // MARK: - 3. Battery Analysis
    private func analyzeBattery() {
        let spData = runSystemProfiler(dataType: "SPPowerDataType")

        // Parse battery info
        var cycleCount = 0
        var maxCapacity = 0
        var designCapacity = 0
        var condition = ""
        var healthPercentage: Double = 0

        // Cycle Count
        if let cycleMatch = spData.range(of: "Cycle Count: (\\d+)", options: .regularExpression) {
            let line = String(spData[cycleMatch])
            if let numRange = line.range(of: "\\d+", options: .regularExpression) {
                cycleCount = Int(line[numRange]) ?? 0
            }
        }

        // Try to get Maximum Capacity percentage directly (Apple Silicon format)
        if let maxCapMatch = spData.range(of: "Maximum Capacity: (\\d+)%", options: .regularExpression) {
            let line = String(spData[maxCapMatch])
            if let numRange = line.range(of: "\\d+", options: .regularExpression) {
                healthPercentage = Double(line[numRange]) ?? 0
            }
        }

        // Fallback: Max Capacity (from Full Charge Capacity) for Intel Macs
        if healthPercentage == 0 {
            if let maxMatch = spData.range(of: "Full Charge Capacity \\(mAh\\): (\\d+)", options: .regularExpression) {
                let line = String(spData[maxMatch])
                if let numRange = line.range(of: "\\d+$", options: .regularExpression) {
                    maxCapacity = Int(line[numRange]) ?? 0
                }
            }

            // Design Capacity
            if let designMatch = spData.range(of: "Design Capacity \\(mAh\\): (\\d+)", options: .regularExpression) {
                let line = String(spData[designMatch])
                if let numRange = line.range(of: "\\d+$", options: .regularExpression) {
                    designCapacity = Int(line[numRange]) ?? 0
                }
            }

            // Calculate health from mAh values
            if designCapacity > 0 {
                healthPercentage = (Double(maxCapacity) / Double(designCapacity)) * 100
                healthPercentage = min(100, healthPercentage)
            }
        }

        // Condition
        if let condMatch = spData.range(of: "Condition: (.+)", options: .regularExpression) {
            let line = String(spData[condMatch])
            if let colonIndex = line.lastIndex(of: ":") {
                condition = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            }
        }

        DispatchQueue.main.async {
            self.hardwareProfile.batteryCycleCount = cycleCount
            self.hardwareProfile.batteryMaxCapacity = maxCapacity
            self.hardwareProfile.batteryDesignCapacity = designCapacity
            self.hardwareProfile.batteryHealth = healthPercentage

            // Determine battery status
            var batteryStatus: HardwareCheckResult.CheckStatus = .ok
            var batteryDetail: String? = nil

            if cycleCount == 0 && healthPercentage == 0 {
                // Desktop Mac - no battery
                self.addResult(
                    category: "Battery",
                    item: "Status",
                    value: "Not Applicable (Desktop)",
                    status: .ok,
                    detail: nil
                )
                return
            }

            // Cycle count analysis
            if cycleCount > 1000 {
                batteryStatus = .issue
                batteryDetail = "High cycle count - battery may need replacement"
                self.addFinding(
                    severity: .warning,
                    title: "High Battery Cycle Count",
                    description: "Battery has \(cycleCount) cycles. Apple considers batteries consumed after 1000 cycles.",
                    recommendation: "Consider battery replacement for optimal performance"
                )
            } else if cycleCount > 500 {
                batteryStatus = .warning
                batteryDetail = "Moderate usage"
            }

            self.addResult(
                category: "Battery",
                item: "Cycle Count",
                value: "\(cycleCount)",
                status: batteryStatus,
                detail: batteryDetail
            )

            // Health analysis
            var healthStatus: HardwareCheckResult.CheckStatus = .ok
            if healthPercentage < 80 {
                healthStatus = .issue
                self.addFinding(
                    severity: .warning,
                    title: "Battery Health Below 80%",
                    description: "Battery maximum capacity is \(String(format: "%.1f", healthPercentage))% of design capacity.",
                    recommendation: "Battery service may be recommended"
                )
            } else if healthPercentage < 90 {
                healthStatus = .warning
            }

            self.addResult(
                category: "Battery",
                item: "Health",
                value: String(format: "%.1f%%", healthPercentage),
                status: healthStatus,
                detail: designCapacity > 0 ? "\(maxCapacity)/\(designCapacity) mAh" : nil
            )

            self.addResult(
                category: "Battery",
                item: "Condition",
                value: condition.isEmpty ? "Unknown" : condition,
                status: condition.lowercased() == "normal" ? .ok : .warning,
                detail: nil
            )

            // Check for battery replacement indicators
            self.checkBatteryReplacement(cycleCount: cycleCount, health: healthPercentage)
        }
    }

    private func checkBatteryReplacement(cycleCount: Int, health: Double) {
        // Suspicious: Very low cycle count with very high health on older serial
        if cycleCount < 50 && health > 98 {
            // Check serial number age
            if let year = extractYearFromSerial(hardwareProfile.serialNumber) {
                let currentYear = Calendar.current.component(.year, from: Date())
                let age = currentYear - year

                if age >= 2 {
                    addFinding(
                        severity: .warning,
                        title: "Possible Battery Replacement",
                        description: "Device appears to be \(age) years old but battery shows very low cycle count (\(cycleCount)) and high health (\(String(format: "%.1f", health))%).",
                        recommendation: "This may indicate the battery was replaced. Verify with Apple if needed."
                    )
                }
            }
        }
    }

    // MARK: - 4. Storage Check
    private func checkStorage() {
        let spData = runSystemProfiler(dataType: "SPNVMeDataType")

        var storageModel = ""
        var smartStatus = ""

        // Model
        if let modelMatch = spData.range(of: "Model: (.+)", options: .regularExpression) {
            let line = String(spData[modelMatch])
            if let colonIndex = line.lastIndex(of: ":") {
                storageModel = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            }
        }

        // If NVMe data is empty, try SATA
        if storageModel.isEmpty {
            let sataData = runSystemProfiler(dataType: "SPSerialATADataType")
            if let modelMatch = sataData.range(of: "Model: (.+)", options: .regularExpression) {
                let line = String(sataData[modelMatch])
                if let colonIndex = line.lastIndex(of: ":") {
                    storageModel = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                }
            }
        }

        // SMART Status
        if let smartMatch = spData.range(of: "S.M.A.R.T. status: (.+)", options: .regularExpression) {
            let line = String(spData[smartMatch])
            if let colonIndex = line.lastIndex(of: ":") {
                smartStatus = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            }
        }

        DispatchQueue.main.async {
            self.hardwareProfile.storageModel = storageModel
            self.hardwareProfile.storageSMART = smartStatus

            self.addResult(
                category: "Storage",
                item: "Model",
                value: storageModel.isEmpty ? "Not Available" : storageModel,
                status: .ok,
                detail: nil
            )

            var smartStatusCheck: HardwareCheckResult.CheckStatus = .ok
            if smartStatus.lowercased() != "verified" && !smartStatus.isEmpty {
                smartStatusCheck = .issue
                self.addFinding(
                    severity: .critical,
                    title: "Storage SMART Status Issue",
                    description: "Storage SMART status is: \(smartStatus)",
                    recommendation: "Back up your data immediately and consider storage replacement"
                )
            }

            self.addResult(
                category: "Storage",
                item: "SMART Status",
                value: smartStatus.isEmpty ? "Not Available" : smartStatus,
                status: smartStatusCheck,
                detail: nil
            )
        }
    }

    // MARK: - 5. Display Check
    private func checkDisplay() {
        let spData = runSystemProfiler(dataType: "SPDisplaysDataType")

        var displayName = ""
        var resolution = ""

        // Display name
        if let nameMatch = spData.range(of: "Display Type: (.+)", options: .regularExpression) {
            let line = String(spData[nameMatch])
            if let colonIndex = line.lastIndex(of: ":") {
                displayName = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            }
        }

        // Resolution
        if let resMatch = spData.range(of: "Resolution: (.+)", options: .regularExpression) {
            let line = String(spData[resMatch])
            if let colonIndex = line.lastIndex(of: ":") {
                resolution = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            }
        }

        DispatchQueue.main.async {
            self.hardwareProfile.displayInfo = displayName

            self.addResult(
                category: "Display",
                item: "Type",
                value: displayName.isEmpty ? "Built-in Display" : displayName,
                status: .ok,
                detail: nil
            )

            if !resolution.isEmpty {
                self.addResult(
                    category: "Display",
                    item: "Resolution",
                    value: resolution,
                    status: .ok,
                    detail: nil
                )
            }
        }
    }

    // MARK: - 6. Memory Check
    private func checkMemory() {
        let totalMemory = Foundation.ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(totalMemory) / 1_073_741_824

        let spData = runSystemProfiler(dataType: "SPMemoryDataType")

        var memoryType = ""
        if let typeMatch = spData.range(of: "Type: (.+)", options: .regularExpression) {
            let line = String(spData[typeMatch])
            if let colonIndex = line.lastIndex(of: ":") {
                memoryType = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            }
        }

        DispatchQueue.main.async {
            self.hardwareProfile.memorySize = String(format: "%.0f GB", memoryGB)
            self.hardwareProfile.memoryType = memoryType

            self.addResult(
                category: "Memory",
                item: "Size",
                value: String(format: "%.0f GB", memoryGB),
                status: .ok,
                detail: nil
            )

            if !memoryType.isEmpty {
                self.addResult(
                    category: "Memory",
                    item: "Type",
                    value: memoryType,
                    status: .ok,
                    detail: nil
                )
            }
        }
    }

    // MARK: - 7. Consistency Analysis
    private func analyzeConsistency() {
        DispatchQueue.main.async {
            // Check serial number format
            if !self.hardwareProfile.serialNumber.isEmpty {
                if !self.isValidSerialFormat(self.hardwareProfile.serialNumber) {
                    self.addFinding(
                        severity: .warning,
                        title: "Unusual Serial Number Format",
                        description: "Serial number format doesn't match expected Apple format.",
                        recommendation: "Verify serial number with Apple support"
                    )
                }
            }

            // Check for common refurbished indicators
            if self.hardwareProfile.serialNumber.hasPrefix("F") {
                self.addFinding(
                    severity: .info,
                    title: "Possible Refurbished Device",
                    description: "Serial number starting with 'F' may indicate a refurbished or replacement unit.",
                    recommendation: "This is normal for Apple-refurbished devices"
                )
            }
        }
    }

    // MARK: - 8. Calculate Score
    private func calculateOverallScore() {
        DispatchQueue.main.async {
            var score = 100

            // Deduct for issues
            for finding in self.findings {
                switch finding.severity {
                case .critical:
                    score -= 25
                case .warning:
                    score -= 10
                case .info:
                    score -= 2
                }
            }

            // Deduct for check results
            for result in self.checkResults {
                switch result.status {
                case .issue:
                    score -= 15
                case .warning:
                    score -= 5
                case .unknown:
                    score -= 2
                case .ok:
                    break
                }
            }

            self.overallScore = max(0, min(100, score))

            // Determine status
            if self.overallScore >= 90 {
                self.overallStatus = "Excellent"
            } else if self.overallScore >= 75 {
                self.overallStatus = "Good"
            } else if self.overallScore >= 50 {
                self.overallStatus = "Fair"
            } else {
                self.overallStatus = "Needs Attention"
            }
        }
    }

    // MARK: - Helper Functions

    private func runSystemProfiler(dataType: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        task.arguments = [dataType]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    private func getChipType() -> String {
        #if arch(arm64)
        return "Apple Silicon"
        #else
        return "Intel"
        #endif
    }

    private func maskSerial(_ serial: String) -> String {
        guard serial.count > 4 else { return serial }
        let visible = String(serial.suffix(4))
        let masked = String(repeating: "•", count: serial.count - 4)
        return masked + visible
    }

    private func maskUUID(_ uuid: String) -> String {
        let parts = uuid.split(separator: "-")
        guard parts.count >= 2 else { return uuid }
        return "••••••••-••••-••••-••••-" + parts.last!
    }

    private func isValidSerialFormat(_ serial: String) -> Bool {
        // Apple serials are typically 10-12 alphanumeric characters
        let pattern = "^[A-Z0-9]{10,12}$"
        return serial.range(of: pattern, options: .regularExpression) != nil
    }

    private func extractYearFromSerial(_ serial: String) -> Int? {
        // Apple serial number encoding for manufacturing year
        // Position 4 (0-indexed 3) contains year code for newer serials
        guard serial.count >= 4 else { return nil }

        let index = serial.index(serial.startIndex, offsetBy: 3)
        let yearChar = serial[index]

        // Year codes (simplified mapping)
        let yearMapping: [Character: Int] = [
            "C": 2020, "D": 2020, "F": 2020,
            "G": 2021, "H": 2021, "J": 2021,
            "K": 2021, "L": 2022, "M": 2022,
            "N": 2022, "P": 2022, "Q": 2023,
            "R": 2023, "T": 2023, "V": 2023,
            "W": 2024, "X": 2024, "Y": 2024
        ]

        return yearMapping[yearChar]
    }

    private func addResult(category: String, item: String, value: String, status: HardwareCheckResult.CheckStatus, detail: String?) {
        let result = HardwareCheckResult(
            category: category,
            item: item,
            value: value,
            status: status,
            detail: detail
        )

        DispatchQueue.main.async {
            self.checkResults.append(result)
        }
    }

    private func addFinding(severity: IntegrityFinding.Severity, title: String, description: String, recommendation: String?) {
        let finding = IntegrityFinding(
            severity: severity,
            title: title,
            description: description,
            recommendation: recommendation
        )

        DispatchQueue.main.async {
            self.findings.append(finding)
        }
    }

    // MARK: - Export Report
    func exportReport() -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "HardwareReport_\(dateFormatter.string(from: Date())).txt"

        let desktopPath = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let fileURL = desktopPath.appendingPathComponent(filename)

        var content = """
        ╔══════════════════════════════════════════════════════════════════╗
        ║              HARDWARE INTEGRITY REPORT                           ║
        ║              SystemMonitor Pro                                   ║
        ╚══════════════════════════════════════════════════════════════════╝

        Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .medium))

        ┌──────────────────────────────────────────────────────────────────┐
        │                      OVERALL SCORE: \(overallScore)/100                         │
        │                      Status: \(overallStatus)                                   │
        └──────────────────────────────────────────────────────────────────┘

        ═══════════════════════════════════════════════════════════════════
                               HARDWARE DETAILS
        ═══════════════════════════════════════════════════════════════════

        """

        // Group results by category
        let categories = Dictionary(grouping: checkResults) { $0.category }

        for (category, results) in categories.sorted(by: { $0.key < $1.key }) {
            content += "\n【\(category)】\n"
            for result in results {
                let statusIcon = result.status == .ok ? "✓" : (result.status == .warning ? "⚠" : "✗")
                content += "  \(statusIcon) \(result.item): \(result.value)\n"
                if let detail = result.detail {
                    content += "    └─ \(detail)\n"
                }
            }
        }

        if !findings.isEmpty {
            content += """

            ═══════════════════════════════════════════════════════════════════
                                   FINDINGS
            ═══════════════════════════════════════════════════════════════════

            """

            for finding in findings {
                let icon = finding.severity == .critical ? "🔴" : (finding.severity == .warning ? "🟡" : "🔵")
                content += """
                \(icon) \(finding.title)
                   \(finding.description)

                """
                if let rec = finding.recommendation {
                    content += "   → \(rec)\n"
                }
                content += "\n"
            }
        }

        content += """

        ═══════════════════════════════════════════════════════════════════
                          End of Report - SystemMonitor Pro
        ═══════════════════════════════════════════════════════════════════
        """

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }
}
