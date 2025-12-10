import Foundation
import AppKit

class SystemReportManager: ObservableObject {
    @Published var isGenerating = false
    @Published var progress: Double = 0
    @Published var currentTask = ""
    @Published var reportGenerated = false
    @Published var lastReportPath: String?

    struct SystemReport {
        var systemInfo: [String: String] = [:]
        var cpuInfo: [String: String] = [:]
        var memoryInfo: [String: String] = [:]
        var diskInfo: [String: String] = [:]
        var batteryInfo: [String: String] = [:]
        var networkInfo: [String: String] = [:]
        var installedApps: [String] = []
        var startupItems: [String] = []
        var topProcesses: [(name: String, memory: String, cpu: String)] = []
        var generatedAt: Date = Date()
    }

    func generateReport(completion: @escaping (URL?) -> Void) {
        isGenerating = true
        progress = 0
        currentTask = "Starting..."
        reportGenerated = false

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var report = SystemReport()

            // 1. System Info
            self.updateProgress(0.1, task: "Gathering system info...")
            report.systemInfo = self.getSystemInfo()

            // 2. CPU Info
            self.updateProgress(0.2, task: "Gathering CPU info...")
            report.cpuInfo = self.getCPUInfo()

            // 3. Memory Info
            self.updateProgress(0.3, task: "Gathering memory info...")
            report.memoryInfo = self.getMemoryInfo()

            // 4. Disk Info
            self.updateProgress(0.4, task: "Gathering disk info...")
            report.diskInfo = self.getDiskInfo()

            // 5. Battery Info
            self.updateProgress(0.5, task: "Gathering battery info...")
            report.batteryInfo = self.getBatteryInfo()

            // 6. Network Info
            self.updateProgress(0.6, task: "Gathering network info...")
            report.networkInfo = self.getNetworkInfo()

            // 7. Installed Apps
            self.updateProgress(0.7, task: "Listing installed apps...")
            report.installedApps = self.getInstalledApps()

            // 8. Top Processes
            self.updateProgress(0.8, task: "Getting top processes...")
            report.topProcesses = self.getTopProcesses()

            // 9. Generate Report File
            self.updateProgress(0.9, task: "Generating report file...")
            let url = self.saveReport(report)

            DispatchQueue.main.async {
                self.progress = 1.0
                self.currentTask = "Complete!"
                self.isGenerating = false
                self.reportGenerated = true
                self.lastReportPath = url?.path
                completion(url)
            }
        }
    }

    private func updateProgress(_ value: Double, task: String) {
        DispatchQueue.main.async {
            self.progress = value
            self.currentTask = task
        }
    }

    private func getSystemInfo() -> [String: String] {
        var info: [String: String] = [:]

        // Mac Model
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        info["Model"] = String(cString: model)

        // macOS Version
        let osVersion = Foundation.ProcessInfo.processInfo.operatingSystemVersion
        info["macOS Version"] = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"

        // Computer Name
        info["Computer Name"] = Host.current().localizedName ?? "Unknown"

        // Hostname
        info["Hostname"] = Foundation.ProcessInfo.processInfo.hostName

        // System Uptime
        let uptime = Foundation.ProcessInfo.processInfo.systemUptime
        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        info["Uptime"] = "\(days)d \(hours)h \(minutes)m"

        // Architecture
        #if arch(arm64)
        info["Architecture"] = "Apple Silicon (arm64)"
        #else
        info["Architecture"] = "Intel (x86_64)"
        #endif

        return info
    }

    private func getCPUInfo() -> [String: String] {
        var info: [String: String] = [:]

        // CPU cores
        info["Physical Cores"] = "\(Foundation.ProcessInfo.processInfo.processorCount)"
        info["Active Cores"] = "\(Foundation.ProcessInfo.processInfo.activeProcessorCount)"

        // CPU Brand
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brand = [CChar](repeating: 0, count: size)
        if sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0) == 0 {
            info["Processor"] = String(cString: brand)
        }

        return info
    }

    private func getMemoryInfo() -> [String: String] {
        var info: [String: String] = [:]

        let totalMemory = Foundation.ProcessInfo.processInfo.physicalMemory
        info["Total RAM"] = formatBytes(totalMemory)

        // Get memory usage
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { pointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, pointer, &count)
            }
        }

        if result == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            let activeMemory = UInt64(stats.active_count) * pageSize
            let wiredMemory = UInt64(stats.wire_count) * pageSize
            let compressedMemory = UInt64(stats.compressor_page_count) * pageSize
            let freeMemory = UInt64(stats.free_count) * pageSize

            info["Active"] = formatBytes(activeMemory)
            info["Wired"] = formatBytes(wiredMemory)
            info["Compressed"] = formatBytes(compressedMemory)
            info["Free"] = formatBytes(freeMemory)
        }

        return info
    }

    private func getDiskInfo() -> [String: String] {
        var info: [String: String] = [:]

        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            let totalSpace = attrs[.systemSize] as? UInt64 ?? 0
            let freeSpace = attrs[.systemFreeSize] as? UInt64 ?? 0
            let usedSpace = totalSpace - freeSpace

            info["Total"] = formatBytes(totalSpace)
            info["Used"] = formatBytes(usedSpace)
            info["Free"] = formatBytes(freeSpace)
            info["Usage"] = String(format: "%.1f%%", Double(usedSpace) / Double(totalSpace) * 100)
        } catch {}

        return info
    }

    private func getBatteryInfo() -> [String: String] {
        var info: [String: String] = [:]

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "batt"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                if output.contains("InternalBattery") {
                    // Parse battery percentage
                    if let range = output.range(of: #"\d+%"#, options: .regularExpression) {
                        info["Battery Level"] = String(output[range])
                    }

                    if output.contains("charging") {
                        info["Status"] = "Charging"
                    } else if output.contains("discharging") {
                        info["Status"] = "Discharging"
                    } else if output.contains("charged") {
                        info["Status"] = "Fully Charged"
                    }
                } else {
                    info["Battery"] = "Not Available (Desktop Mac)"
                }
            }
        } catch {}

        return info
    }

    private func getNetworkInfo() -> [String: String] {
        var info: [String: String] = [:]

        // Get network interfaces
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Parse en0 (usually WiFi or Ethernet)
                if output.contains("en0") {
                    if let range = output.range(of: #"inet \d+\.\d+\.\d+\.\d+"#, options: .regularExpression) {
                        let ipString = String(output[range]).replacingOccurrences(of: "inet ", with: "")
                        info["IP Address (en0)"] = ipString
                    }
                }
            }
        } catch {}

        return info
    }

    private func getInstalledApps() -> [String] {
        var apps: [String] = []
        let fileManager = FileManager.default
        let appPaths = ["/Applications", NSHomeDirectory() + "/Applications"]

        for path in appPaths {
            if let contents = try? fileManager.contentsOfDirectory(atPath: path) {
                for item in contents where item.hasSuffix(".app") {
                    apps.append(item.replacingOccurrences(of: ".app", with: ""))
                }
            }
        }

        return apps.sorted()
    }

    private func getTopProcesses() -> [(name: String, memory: String, cpu: String)] {
        var processes: [(name: String, memory: String, cpu: String)] = []

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,%cpu=,rss=,comm=", "-r"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()

            // Read data BEFORE waiting - this prevents deadlock
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")

                for line in lines.prefix(15) {
                    let parts = line.trimmingCharacters(in: .whitespaces)
                        .split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)

                    guard parts.count >= 4,
                          let cpu = Double(parts[1]),
                          let rss = UInt64(parts[2]) else { continue }

                    let name = (String(parts[3]) as NSString).lastPathComponent
                    let memoryBytes = rss * 1024

                    processes.append((
                        name: name,
                        memory: formatBytes(memoryBytes),
                        cpu: String(format: "%.1f%%", cpu)
                    ))
                }
            }
        } catch {}

        return processes
    }

    private func saveReport(_ report: SystemReport) -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "SystemReport_\(dateFormatter.string(from: report.generatedAt)).txt"

        let desktopPath = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let fileURL = desktopPath.appendingPathComponent(filename)

        var content = """
        ╔══════════════════════════════════════════════════════════════════╗
        ║                    SYSTEMMONITOR PRO REPORT                      ║
        ║                 Generated: \(formatDate(report.generatedAt))                  ║
        ╚══════════════════════════════════════════════════════════════════╝

        ┌──────────────────────────────────────────────────────────────────┐
        │                        SYSTEM INFORMATION                         │
        └──────────────────────────────────────────────────────────────────┘
        """

        for (key, value) in report.systemInfo.sorted(by: { $0.key < $1.key }) {
            content += "\n  \(key.padding(toLength: 20, withPad: " ", startingAt: 0)): \(value)"
        }

        content += """


        ┌──────────────────────────────────────────────────────────────────┐
        │                         CPU INFORMATION                           │
        └──────────────────────────────────────────────────────────────────┘
        """

        for (key, value) in report.cpuInfo.sorted(by: { $0.key < $1.key }) {
            content += "\n  \(key.padding(toLength: 20, withPad: " ", startingAt: 0)): \(value)"
        }

        content += """


        ┌──────────────────────────────────────────────────────────────────┐
        │                       MEMORY INFORMATION                          │
        └──────────────────────────────────────────────────────────────────┘
        """

        for (key, value) in report.memoryInfo.sorted(by: { $0.key < $1.key }) {
            content += "\n  \(key.padding(toLength: 20, withPad: " ", startingAt: 0)): \(value)"
        }

        content += """


        ┌──────────────────────────────────────────────────────────────────┐
        │                        DISK INFORMATION                           │
        └──────────────────────────────────────────────────────────────────┘
        """

        for (key, value) in report.diskInfo.sorted(by: { $0.key < $1.key }) {
            content += "\n  \(key.padding(toLength: 20, withPad: " ", startingAt: 0)): \(value)"
        }

        content += """


        ┌──────────────────────────────────────────────────────────────────┐
        │                       BATTERY INFORMATION                         │
        └──────────────────────────────────────────────────────────────────┘
        """

        for (key, value) in report.batteryInfo.sorted(by: { $0.key < $1.key }) {
            content += "\n  \(key.padding(toLength: 20, withPad: " ", startingAt: 0)): \(value)"
        }

        content += """


        ┌──────────────────────────────────────────────────────────────────┐
        │                       NETWORK INFORMATION                         │
        └──────────────────────────────────────────────────────────────────┘
        """

        for (key, value) in report.networkInfo.sorted(by: { $0.key < $1.key }) {
            content += "\n  \(key.padding(toLength: 20, withPad: " ", startingAt: 0)): \(value)"
        }

        content += """


        ┌──────────────────────────────────────────────────────────────────┐
        │                    TOP PROCESSES (BY MEMORY)                      │
        └──────────────────────────────────────────────────────────────────┘
        """

        for (index, process) in report.topProcesses.prefix(15).enumerated() {
            content += "\n  \(String(index + 1).padding(toLength: 3, withPad: " ", startingAt: 0)). \(process.name.padding(toLength: 30, withPad: " ", startingAt: 0)) Memory: \(process.memory.padding(toLength: 10, withPad: " ", startingAt: 0)) CPU: \(process.cpu)"
        }

        content += """


        ┌──────────────────────────────────────────────────────────────────┐
        │                       INSTALLED APPLICATIONS                      │
        └──────────────────────────────────────────────────────────────────┘
        """

        for (index, app) in report.installedApps.enumerated() {
            content += "\n  \(String(index + 1).padding(toLength: 4, withPad: " ", startingAt: 0)). \(app)"
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

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        } else {
            let mb = Double(bytes) / 1_048_576
            return String(format: "%.0f MB", mb)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    func openReport() {
        if let path = lastReportPath {
            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        }
    }
}
