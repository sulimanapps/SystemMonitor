import Foundation
import Darwin

class SystemMonitor: ObservableObject {
    @Published var cpuUsage: Double = 0
    @Published var memoryUsage: Double = 0
    @Published var memoryUsed: UInt64 = 0
    @Published var memoryTotal: UInt64 = 0
    @Published var diskUsage: Double = 0
    @Published var diskUsed: UInt64 = 0
    @Published var diskTotal: UInt64 = 0
    @Published var topProcesses: [AppProcessInfo] = []
    @Published var cpuHistory: [Double] = Array(repeating: 0, count: 20)
    @Published var systemUptime: TimeInterval = 0

    private var previousCPUInfo: host_cpu_load_info?

    struct AppProcessInfo: Identifiable {
        let id = UUID()
        let name: String
        let memory: UInt64
        let pid: Int32
    }

    init() {
        updateStats()
    }

    func updateStats() {
        cpuUsage = getCPUUsage()
        cpuHistory.removeFirst()
        cpuHistory.append(cpuUsage)

        let memInfo = getMemoryUsage()
        memoryUsed = memInfo.used
        memoryTotal = memInfo.total
        memoryUsage = memInfo.total > 0 ? Double(memInfo.used) / Double(memInfo.total) * 100 : 0

        let diskInfo = getDiskUsage()
        diskUsed = diskInfo.used
        diskTotal = diskInfo.total
        diskUsage = diskInfo.total > 0 ? Double(diskInfo.used) / Double(diskInfo.total) * 100 : 0

        topProcesses = getTopProcesses()
        systemUptime = getSystemUptime()
    }

    private func getSystemUptime() -> TimeInterval {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.stride
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]

        if sysctl(&mib, 2, &boottime, &size, nil, 0) != -1 {
            let bootDate = Date(timeIntervalSince1970: TimeInterval(boottime.tv_sec))
            return Date().timeIntervalSince(bootDate)
        }
        return 0
    }

    private func getCPUUsage() -> Double {
        var cpuInfo: host_cpu_load_info?
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)

        let hostInfo = host_cpu_load_info_t.allocate(capacity: 1)
        defer { hostInfo.deallocate() }

        let result = hostInfo.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { pointer in
            host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, pointer, &count)
        }

        guard result == KERN_SUCCESS else { return 0 }

        cpuInfo = hostInfo.pointee

        guard let current = cpuInfo, let previous = previousCPUInfo else {
            previousCPUInfo = cpuInfo
            return 0
        }

        let userDiff = Double(current.cpu_ticks.0 - previous.cpu_ticks.0)
        let systemDiff = Double(current.cpu_ticks.1 - previous.cpu_ticks.1)
        let idleDiff = Double(current.cpu_ticks.2 - previous.cpu_ticks.2)
        let niceDiff = Double(current.cpu_ticks.3 - previous.cpu_ticks.3)

        let totalTicks = userDiff + systemDiff + idleDiff + niceDiff
        let usedTicks = userDiff + systemDiff + niceDiff

        previousCPUInfo = cpuInfo

        return totalTicks > 0 ? (usedTicks / totalTicks) * 100 : 0
    }

    private func getMemoryUsage() -> (used: UInt64, total: UInt64) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { pointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, pointer, &count)
            }
        }

        guard result == KERN_SUCCESS else { return (0, 0) }

        let pageSize = UInt64(vm_kernel_page_size)
        let totalMemory = Foundation.ProcessInfo.processInfo.physicalMemory

        let activeMemory = UInt64(stats.active_count) * pageSize
        let wiredMemory = UInt64(stats.wire_count) * pageSize
        let compressedMemory = UInt64(stats.compressor_page_count) * pageSize

        let usedMemory = activeMemory + wiredMemory + compressedMemory

        return (usedMemory, totalMemory)
    }

    private func getDiskUsage() -> (used: UInt64, total: UInt64) {
        let fileManager = FileManager.default

        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: "/")
            let totalSpace = attributes[.systemSize] as? UInt64 ?? 0
            let freeSpace = attributes[.systemFreeSize] as? UInt64 ?? 0
            let usedSpace = totalSpace - freeSpace
            return (usedSpace, totalSpace)
        } catch {
            return (0, 0)
        }
    }

    private func getTopProcesses() -> [AppProcessInfo] {
        // Use a simpler approach that doesn't block
        var processes: [AppProcessInfo] = []

        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-axm", "-o", "pid,rss,comm"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()

            // Set a timeout to prevent hanging
            let deadline = DispatchTime.now() + .milliseconds(500)
            let semaphore = DispatchSemaphore(value: 0)

            DispatchQueue.global(qos: .utility).async {
                task.waitUntilExit()
                semaphore.signal()
            }

            let result = semaphore.wait(timeout: deadline)

            if result == .timedOut {
                task.terminate()
                return processes
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n").dropFirst()
                var tempProcesses: [(name: String, memory: UInt64, pid: Int32)] = []

                for line in lines.prefix(100) { // Limit to first 100 lines
                    let components = line.trimmingCharacters(in: .whitespaces)
                        .components(separatedBy: .whitespaces)
                        .filter { !$0.isEmpty }

                    guard components.count >= 3,
                          let pid = Int32(components[0]),
                          let rss = UInt64(components[1]) else { continue }

                    let name = components.dropFirst(2).joined(separator: " ")
                    let memoryBytes = rss * 1024
                    tempProcesses.append((name: name, memory: memoryBytes, pid: pid))
                }

                tempProcesses.sort { $0.memory > $1.memory }
                processes = tempProcesses.prefix(3).map { AppProcessInfo(name: $0.name, memory: $0.memory, pid: $0.pid) }
            }
        } catch {
            // Silently fail
        }

        return processes
    }
}
