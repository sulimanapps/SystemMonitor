import Foundation
import AppKit

struct ProcessInfo: Identifiable, Equatable {
    let id: Int32  // Use PID as ID for stability
    let pid: Int32
    let name: String
    let cpuUsage: Double
    let memoryUsage: UInt64
    let user: String
    let isSystemProcess: Bool

    static func == (lhs: ProcessInfo, rhs: ProcessInfo) -> Bool {
        lhs.pid == rhs.pid
    }

    var memoryString: String {
        let mb = Double(memoryUsage) / 1_048_576
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.1f MB", mb)
    }
}

class ProcessManager: ObservableObject {
    @Published var processes: [ProcessInfo] = []
    @Published var isLoading = false
    @Published var sortBy: SortOption = .memory
    @Published var showSystemProcesses = false
    @Published var searchText = ""
    @Published var killError: String?

    private var isLoadingInProgress = false

    enum SortOption: String, CaseIterable {
        case memory = "Memory"
        case cpu = "CPU"
        case name = "Name"
    }

    var filteredProcesses: [ProcessInfo] {
        var result = processes

        // Filter system processes
        if !showSystemProcesses {
            result = result.filter { !$0.isSystemProcess }
        }

        // Filter by search
        if !searchText.isEmpty {
            let search = searchText.lowercased()
            result = result.filter { $0.name.lowercased().contains(search) }
        }

        // Sort
        switch sortBy {
        case .memory:
            result.sort { $0.memoryUsage > $1.memoryUsage }
        case .cpu:
            result.sort { $0.cpuUsage > $1.cpuUsage }
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        return result
    }

    func loadProcesses() {
        // Prevent multiple simultaneous loads
        guard !isLoadingInProgress else { return }
        isLoadingInProgress = true
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let processList = self.fetchProcessList()

            DispatchQueue.main.async {
                self.processes = processList
                self.isLoading = false
                self.isLoadingInProgress = false
            }
        }
    }

    private func fetchProcessList() -> [ProcessInfo] {
        var processList: [ProcessInfo] = []

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,user=,%cpu=,rss=,comm="]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard let output = String(data: data, encoding: .utf8) else {
                return processList
            }

            let lines = output.components(separatedBy: "\n")

            for line in lines {
                guard !line.isEmpty else { continue }

                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let parts = trimmed.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)

                guard parts.count >= 5 else { continue }

                guard let pid = Int32(parts[0]),
                      let cpu = Double(parts[2]),
                      let rss = UInt64(parts[3]) else { continue }

                let user = String(parts[1])
                let fullPath = String(parts[4])
                let memoryBytes = rss * 1024

                let cleanedName = cleanProcessName(fullPath)
                let isSystem = isSystemProcess(name: fullPath, user: user)

                let processInfo = ProcessInfo(
                    id: pid,
                    pid: pid,
                    name: cleanedName,
                    cpuUsage: cpu,
                    memoryUsage: memoryBytes,
                    user: user,
                    isSystemProcess: isSystem
                )
                processList.append(processInfo)
            }
        } catch {
            // Handle error silently
        }

        return processList
    }

    func killProcess(_ process: ProcessInfo, force: Bool = false) {
        killError = nil

        let signal = force ? SIGKILL : SIGTERM

        if kill(process.pid, signal) == 0 {
            // Success - refresh list
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.loadProcesses()
            }
        } else {
            // Need elevated privileges
            killWithAdmin(process, force: force)
        }
    }

    private func killWithAdmin(_ process: ProcessInfo, force: Bool) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let signal = force ? "-9" : "-15"
            let script = """
            do shell script "kill \(signal) \(process.pid)" with administrator privileges
            """

            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)

                DispatchQueue.main.async {
                    if let error = error {
                        self?.killError = error[NSAppleScript.errorMessage] as? String ?? "Failed to terminate process"
                    } else {
                        // Success - reload
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self?.loadProcesses()
                        }
                    }
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }

    private func isSystemProcess(name: String, user: String) -> Bool {
        // System users
        let systemUsers: Set<String> = ["root", "_windowserver", "_coreaudiod", "_mdnsresponder",
                                         "_spotlight", "_hidd", "_distnoted", "_networkd"]
        if systemUsers.contains(user) { return true }

        // System paths
        if name.hasPrefix("/System/") || name.hasPrefix("/usr/") || name.hasPrefix("/sbin/") {
            return true
        }

        // Known system processes
        let baseName = (name as NSString).lastPathComponent
        let systemProcesses: Set<String> = [
            "kernel_task", "launchd", "WindowServer", "loginwindow", "Finder",
            "Dock", "SystemUIServer", "cfprefsd", "trustd", "securityd",
            "distnoted", "UserEventAgent", "secinitd", "coreservicesd",
            "mds", "mds_stores", "mdworker", "notifyd", "logd", "powerd"
        ]

        return systemProcesses.contains(baseName)
    }

    private func cleanProcessName(_ name: String) -> String {
        var baseName = (name as NSString).lastPathComponent

        // Remove common suffixes
        let suffixes = [" Helper", " (Renderer)", " (GPU)", " (Plugin)", ".app"]
        for suffix in suffixes {
            if baseName.hasSuffix(suffix) {
                baseName = String(baseName.dropLast(suffix.count))
            }
        }

        return baseName
    }
}
