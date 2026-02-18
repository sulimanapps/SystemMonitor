import XCTest
@testable import SystemMonitor

final class SystemMonitorTests: XCTestCase {

    // MARK: - ProcessInfo Tests

    func testMemoryStringMB() {
        let info = ProcessInfo(id: 1, pid: 1, name: "Test", cpuUsage: 0,
                               memoryUsage: 104_857_600, user: "user", isSystemProcess: false)
        XCTAssertEqual(info.memoryString, "100.0 MB")
    }

    func testMemoryStringGB() {
        let info = ProcessInfo(id: 1, pid: 1, name: "Test", cpuUsage: 0,
                               memoryUsage: 2_147_483_648, user: "user", isSystemProcess: false)
        XCTAssertEqual(info.memoryString, "2.0 GB")
    }

    func testMemoryStringSmall() {
        let info = ProcessInfo(id: 1, pid: 1, name: "Test", cpuUsage: 0,
                               memoryUsage: 1_048_576, user: "user", isSystemProcess: false)
        XCTAssertEqual(info.memoryString, "1.0 MB")
    }

    // MARK: - ProcessInfo Equatable

    func testProcessInfoEqualityByPID() {
        let p1 = ProcessInfo(id: 42, pid: 42, name: "Safari", cpuUsage: 5.0,
                              memoryUsage: 100, user: "user", isSystemProcess: false)
        let p2 = ProcessInfo(id: 42, pid: 42, name: "Different", cpuUsage: 99.0,
                              memoryUsage: 999, user: "root", isSystemProcess: true)
        XCTAssertEqual(p1, p2)
    }

    func testProcessInfoInequalityByPID() {
        let p1 = ProcessInfo(id: 1, pid: 1, name: "Same", cpuUsage: 5.0,
                              memoryUsage: 100, user: "user", isSystemProcess: false)
        let p2 = ProcessInfo(id: 2, pid: 2, name: "Same", cpuUsage: 5.0,
                              memoryUsage: 100, user: "user", isSystemProcess: false)
        XCTAssertNotEqual(p1, p2)
    }

    // MARK: - ProcessManager Initial State

    func testProcessManagerInitialState() {
        let manager = ProcessManager()
        XCTAssertTrue(manager.processes.isEmpty)
        XCTAssertFalse(manager.isLoading)
        XCTAssertEqual(manager.sortBy, .memory)
        XCTAssertFalse(manager.showSystemProcesses)
        XCTAssertTrue(manager.searchText.isEmpty)
        XCTAssertNil(manager.killError)
    }

    // MARK: - ProcessManager Filtering

    func testFilteredProcessesSearchByName() {
        let manager = ProcessManager()
        manager.processes = [
            ProcessInfo(id: 1, pid: 1, name: "Safari", cpuUsage: 5.0,
                         memoryUsage: 500_000_000, user: "user", isSystemProcess: false),
            ProcessInfo(id: 2, pid: 2, name: "Xcode", cpuUsage: 10.0,
                         memoryUsage: 1_000_000_000, user: "user", isSystemProcess: false),
        ]

        manager.searchText = "Safari"
        XCTAssertEqual(manager.filteredProcesses.count, 1)
        XCTAssertEqual(manager.filteredProcesses.first?.name, "Safari")
    }

    func testFilteredProcessesCaseInsensitiveSearch() {
        let manager = ProcessManager()
        manager.processes = [
            ProcessInfo(id: 1, pid: 1, name: "Safari", cpuUsage: 5.0,
                         memoryUsage: 500_000_000, user: "user", isSystemProcess: false),
        ]

        manager.searchText = "safari"
        XCTAssertEqual(manager.filteredProcesses.count, 1)
    }

    func testFilteredProcessesHidesSystemByDefault() {
        let manager = ProcessManager()
        manager.processes = [
            ProcessInfo(id: 1, pid: 1, name: "Safari", cpuUsage: 5.0,
                         memoryUsage: 500_000_000, user: "user", isSystemProcess: false),
            ProcessInfo(id: 2, pid: 2, name: "kernel_task", cpuUsage: 10.0,
                         memoryUsage: 1_000_000_000, user: "root", isSystemProcess: true),
        ]

        XCTAssertEqual(manager.filteredProcesses.count, 1)

        manager.showSystemProcesses = true
        XCTAssertEqual(manager.filteredProcesses.count, 2)
    }

    // MARK: - ProcessManager Sorting

    func testFilteredProcessesSortByMemory() {
        let manager = ProcessManager()
        manager.sortBy = .memory
        manager.processes = [
            ProcessInfo(id: 1, pid: 1, name: "Small", cpuUsage: 50.0,
                         memoryUsage: 100_000, user: "user", isSystemProcess: false),
            ProcessInfo(id: 2, pid: 2, name: "Large", cpuUsage: 1.0,
                         memoryUsage: 1_000_000_000, user: "user", isSystemProcess: false),
        ]

        XCTAssertEqual(manager.filteredProcesses.first?.name, "Large")
    }

    func testFilteredProcessesSortByCPU() {
        let manager = ProcessManager()
        manager.sortBy = .cpu
        manager.processes = [
            ProcessInfo(id: 1, pid: 1, name: "LowCPU", cpuUsage: 1.0,
                         memoryUsage: 1_000_000_000, user: "user", isSystemProcess: false),
            ProcessInfo(id: 2, pid: 2, name: "HighCPU", cpuUsage: 90.0,
                         memoryUsage: 100_000, user: "user", isSystemProcess: false),
        ]

        XCTAssertEqual(manager.filteredProcesses.first?.name, "HighCPU")
    }

    func testFilteredProcessesSortByName() {
        let manager = ProcessManager()
        manager.sortBy = .name
        manager.processes = [
            ProcessInfo(id: 1, pid: 1, name: "Zapp", cpuUsage: 1.0,
                         memoryUsage: 100, user: "user", isSystemProcess: false),
            ProcessInfo(id: 2, pid: 2, name: "Alpha", cpuUsage: 1.0,
                         memoryUsage: 100, user: "user", isSystemProcess: false),
        ]

        XCTAssertEqual(manager.filteredProcesses.first?.name, "Alpha")
    }

    // MARK: - ProcessManager Utility Methods

    func testCleanProcessNameRemovesPath() {
        let manager = ProcessManager()
        XCTAssertEqual(manager.cleanProcessName("/usr/bin/python3"), "python3")
    }

    func testCleanProcessNameRemovesAppSuffix() {
        let manager = ProcessManager()
        XCTAssertEqual(manager.cleanProcessName("/Applications/Safari.app"), "Safari")
    }

    func testCleanProcessNameRemovesHelperSuffix() {
        let manager = ProcessManager()
        XCTAssertEqual(manager.cleanProcessName("Chrome Helper"), "Chrome")
    }

    func testIsSystemProcessByUser() {
        let manager = ProcessManager()
        XCTAssertTrue(manager.isSystemProcess(name: "anything", user: "root"))
        XCTAssertTrue(manager.isSystemProcess(name: "anything", user: "_windowserver"))
        XCTAssertTrue(manager.isSystemProcess(name: "anything", user: "_coreaudiod"))
    }

    func testIsSystemProcessByPath() {
        let manager = ProcessManager()
        XCTAssertTrue(manager.isSystemProcess(name: "/System/Library/something", user: "user"))
        XCTAssertTrue(manager.isSystemProcess(name: "/usr/bin/something", user: "user"))
        XCTAssertTrue(manager.isSystemProcess(name: "/sbin/something", user: "user"))
    }

    func testIsSystemProcessByKnownName() {
        let manager = ProcessManager()
        XCTAssertTrue(manager.isSystemProcess(name: "kernel_task", user: "user"))
        XCTAssertTrue(manager.isSystemProcess(name: "WindowServer", user: "user"))
        XCTAssertTrue(manager.isSystemProcess(name: "Dock", user: "user"))
    }

    func testIsNotSystemProcess() {
        let manager = ProcessManager()
        XCTAssertFalse(manager.isSystemProcess(name: "/Applications/Safari.app", user: "sm"))
        XCTAssertFalse(manager.isSystemProcess(name: "MyApp", user: "sm"))
    }

    // MARK: - SystemMonitor Tests

    func testSystemMonitorMemoryPopulated() {
        let monitor = SystemMonitor()
        XCTAssertGreaterThan(monitor.memoryTotal, 0)
        XCTAssertLessThanOrEqual(monitor.memoryUsed, monitor.memoryTotal)
    }

    func testSystemMonitorMemoryPercentage() {
        let monitor = SystemMonitor()
        XCTAssertGreaterThanOrEqual(monitor.memoryUsage, 0)
        XCTAssertLessThanOrEqual(monitor.memoryUsage, 100)
    }

    func testSystemMonitorDiskPopulated() {
        let monitor = SystemMonitor()
        XCTAssertGreaterThan(monitor.diskTotal, 0)
        XCTAssertLessThanOrEqual(monitor.diskUsed, monitor.diskTotal)
    }

    func testSystemMonitorDiskPercentage() {
        let monitor = SystemMonitor()
        XCTAssertGreaterThanOrEqual(monitor.diskUsage, 0)
        XCTAssertLessThanOrEqual(monitor.diskUsage, 100)
    }

    func testSystemMonitorCPUHistoryLength() {
        let monitor = SystemMonitor()
        XCTAssertEqual(monitor.cpuHistory.count, 20)
    }

    func testSystemMonitorUpdateStats() {
        let monitor = SystemMonitor()
        monitor.updateStats()
        // After second call, values should still be valid
        XCTAssertGreaterThanOrEqual(monitor.cpuUsage, 0)
        XCTAssertLessThanOrEqual(monitor.cpuUsage, 100)
        XCTAssertEqual(monitor.cpuHistory.count, 20)
    }

    // MARK: - SystemReportManager Tests

    func testFormatBytesZero() {
        let manager = SystemReportManager()
        XCTAssertEqual(manager.formatBytes(0), "0 MB")
    }

    func testFormatBytesMB() {
        let manager = SystemReportManager()
        XCTAssertEqual(manager.formatBytes(1_048_576), "1 MB")
        XCTAssertEqual(manager.formatBytes(524_288_000), "500 MB")
    }

    func testFormatBytesGB() {
        let manager = SystemReportManager()
        XCTAssertEqual(manager.formatBytes(1_073_741_824), "1.00 GB")
        XCTAssertEqual(manager.formatBytes(8_589_934_592), "8.00 GB")
        XCTAssertEqual(manager.formatBytes(17_179_869_184), "16.00 GB")
    }

    // MARK: - SettingsManager Tests

    func testSettingsManagerDefaultRefreshRate() {
        let settings = SettingsManager()
        XCTAssertEqual(settings.refreshRate, 2.0)
    }

    func testSettingsManagerDefaultThresholds() {
        let settings = SettingsManager()
        XCTAssertEqual(settings.cpuAlertThreshold, 85)
        XCTAssertEqual(settings.memoryAlertThreshold, 85)
        XCTAssertEqual(settings.diskAlertThreshold, 90)
    }

    func testSettingsManagerDefaultTheme() {
        let settings = SettingsManager()
        XCTAssertEqual(settings.theme, .dark)
    }
}
