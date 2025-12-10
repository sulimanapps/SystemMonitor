import SwiftUI
import AppKit

// MARK: - Main Dashboard View
struct DashboardView: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var featureManager: FeatureManager
    @ObservedObject var cacheManager: CacheManager
    @ObservedObject var appManager: AppManager
    @ObservedObject var smartCleanManager: SmartCleanManager
    @ObservedObject var settings: SettingsManager
    @StateObject private var processManager = ProcessManager()
    @StateObject private var startupManager = StartupManager()
    @StateObject private var hardwareIntegrityManager = HardwareIntegrityManager()

    @State private var showSettings = false
    @State private var currentTime = Date()
    @State private var alertMessage: String? = nil
    @State private var alertType: AlertBanner.AlertType = .info

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Background
            Theme.Colors.background

            VStack(spacing: 0) {
                // Header
                DashboardHeader(
                    currentTime: currentTime,
                    uptime: systemMonitor.systemUptime,
                    cpuStatus: statusFor(systemMonitor.cpuUsage),
                    memoryStatus: statusFor(systemMonitor.memoryUsage),
                    diskStatus: statusFor(systemMonitor.diskUsage),
                    onSettingsTap: { showSettings = true }
                )

                // Alert Banner
                if let message = alertMessage {
                    AlertBanner(message: message, type: alertType) {
                        alertMessage = nil
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Main Content - Simple 3-column layout (NO GeometryReader, NO ScrollView)
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    // Left Column - System Health
                    VStack(spacing: Theme.Spacing.md) {
                        CPUCard(
                            usage: systemMonitor.cpuUsage,
                            history: systemMonitor.cpuHistory
                        )

                        MemoryCard(
                            usage: systemMonitor.memoryUsage,
                            used: systemMonitor.memoryUsed,
                            total: systemMonitor.memoryTotal
                        )

                        DiskCard(
                            usage: systemMonitor.diskUsage,
                            used: systemMonitor.diskUsed,
                            total: systemMonitor.diskTotal
                        )
                    }
                    .frame(width: 260)

                    // Center Column - Charts (flexible width)
                    VStack(spacing: Theme.Spacing.md) {
                        PerformanceHistoryCard(
                            cpuHistory: featureManager.usageHistory.map { $0.cpuUsage },
                            memoryHistory: featureManager.usageHistory.map { $0.memoryUsage }
                        )

                        NetworkActivityCard(featureManager: featureManager)
                    }

                    // Right Column - Details
                    VStack(spacing: Theme.Spacing.md) {
                        BatteryCard(batteryInfo: featureManager.batteryInfo)

                        ThermalCard(
                            cpuTemp: featureManager.cpuTemperature,
                            gpuTemp: featureManager.gpuTemperature
                        )

                        TopProcessesCard(featureManager: featureManager)
                    }
                    .frame(width: 240)
                }
                .padding(Theme.Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom Action Bar
                ActionBar(
                    featureManager: featureManager,
                    appManager: appManager,
                    smartCleanManager: smartCleanManager,
                    processManager: processManager,
                    startupManager: startupManager,
                    hardwareIntegrityManager: hardwareIntegrityManager
                )
            }

            // Settings Panel Overlay
            if showSettings {
                Color.black.opacity(0.5)
                    .onTapGesture { showSettings = false }

                HStack {
                    Spacer()
                    SettingsPanel(settings: settings, isPresented: $showSettings)
                }
                .transition(.move(edge: .trailing))
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .animation(Theme.Animation.normal, value: showSettings)
        .animation(Theme.Animation.normal, value: alertMessage != nil)
    }

    private func statusFor(_ value: Double) -> StatusDot.Status {
        if value >= 85 { return .critical }
        else if value >= 70 { return .warning }
        else { return .normal }
    }
}

// MARK: - Dashboard Header
struct DashboardHeader: View {
    let currentTime: Date
    let uptime: TimeInterval
    let cpuStatus: StatusDot.Status
    let memoryStatus: StatusDot.Status
    let diskStatus: StatusDot.Status
    let onSettingsTap: () -> Void

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy • HH:mm:ss"
        return formatter.string(from: currentTime)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Logo and Title
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "cpu")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(Theme.Colors.primary)
                    .glowEffect(color: Theme.Colors.primary.opacity(0.5), radius: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text("SystemMonitor Pro")
                        .font(Theme.Typography.title)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(formattedTime)
                        .font(Theme.Typography.monoSmall)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }

            Spacer()

            // Status indicators
            HStack(spacing: Theme.Spacing.md) {
                StatusBadge(label: "CPU", status: cpuStatus)
                StatusBadge(label: "MEM", status: memoryStatus)
                StatusBadge(label: "DISK", status: diskStatus)
            }

            Divider()
                .frame(height: 30)
                .background(Theme.Colors.cardBorder)

            // Uptime
            UptimeDisplay(uptime: uptime)

            LiveIndicator()

            // Settings button
            Button(action: onSettingsTap) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(Theme.Radius.small)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Colors.headerBackground)
    }
}

// MARK: - CPU Card
struct CPUCard: View {
    let usage: Double
    let history: [Double]

    var body: some View {
        DashboardCard(title: "CPU", icon: "cpu", iconColor: Theme.Colors.chartCPU) {
            VStack(spacing: Theme.Spacing.sm) {
                HStack {
                    CircularGauge(
                        value: usage,
                        title: "Usage",
                        subtitle: "",
                        color: Theme.Colors.statusColor(for: usage),
                        size: 80
                    )

                    Spacer()

                    VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                        Text(String(format: "%.1f%%", usage))
                            .font(Theme.Typography.statMedium)
                            .foregroundColor(Theme.Colors.statusColor(for: usage))

                        Text("\(Foundation.ProcessInfo.processInfo.processorCount) cores")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }

                // Sparkline
                Sparkline(data: history, color: Theme.Colors.chartCPU, height: 30)
            }
        }
    }
}

// MARK: - Memory Card
struct MemoryCard: View {
    let usage: Double
    let used: UInt64
    let total: UInt64

    var body: some View {
        DashboardCard(title: "Memory", icon: "memorychip", iconColor: Theme.Colors.chartMemory) {
            VStack(spacing: Theme.Spacing.sm) {
                HStack {
                    CircularGauge(
                        value: usage,
                        title: "Usage",
                        subtitle: "",
                        color: Theme.Colors.statusColor(for: usage),
                        size: 80
                    )

                    Spacer()

                    VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                        Text(String(format: "%.1f%%", usage))
                            .font(Theme.Typography.statMedium)
                            .foregroundColor(Theme.Colors.statusColor(for: usage))

                        Text("\(formatBytes(used)) / \(formatBytes(total))")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }

                ProgressBar(value: usage, color: Theme.Colors.chartMemory, height: 6)
            }
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        return String(format: "%.1f GB", gb)
    }
}

// MARK: - Disk Card
struct DiskCard: View {
    let usage: Double
    let used: UInt64
    let total: UInt64

    var body: some View {
        DashboardCard(title: "Disk", icon: "internaldrive", iconColor: Theme.Colors.chartDisk) {
            VStack(spacing: Theme.Spacing.sm) {
                HStack {
                    DiskDonutChart(
                        used: Double(used),
                        total: Double(total),
                        size: 80
                    )

                    Spacer()

                    VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                        Text(String(format: "%.1f%%", usage))
                            .font(Theme.Typography.statMedium)
                            .foregroundColor(Theme.Colors.statusColor(for: usage))

                        Text("\(formatBytes(total - used)) free")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }

                ProgressBar(value: usage, color: Theme.Colors.chartDisk, height: 6)
            }
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        return String(format: "%.1f GB", gb)
    }
}

// MARK: - Performance History Card
struct PerformanceHistoryCard: View {
    let cpuHistory: [Double]
    let memoryHistory: [Double]

    var body: some View {
        DashboardCard(title: "Performance History", icon: "chart.xyaxis.line", iconColor: Theme.Colors.primary) {
            VStack(spacing: Theme.Spacing.sm) {
                if cpuHistory.count > 1 {
                    LineChart(
                        dataSeries: [
                            LineChart.ChartDataSeries(name: "CPU", data: cpuHistory, color: Theme.Colors.chartCPU),
                            LineChart.ChartDataSeries(name: "Memory", data: memoryHistory, color: Theme.Colors.chartMemory)
                        ],
                        showGrid: true,
                        showLegend: true,
                        height: 140
                    )
                } else {
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.Colors.textMuted)
                        Text("Collecting data...")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                }

                HStack {
                    Text("Last \(max(cpuHistory.count, 1)) minutes")
                        .font(Theme.Typography.footnote)
                        .foregroundColor(Theme.Colors.textMuted)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Network Activity Card
struct NetworkActivityCard: View {
    @ObservedObject var featureManager: FeatureManager

    var body: some View {
        DashboardCard(title: "Network Activity", icon: "network", iconColor: Theme.Colors.chartNetwork) {
            VStack(spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.xl) {
                    // Download
                    VStack(spacing: Theme.Spacing.xxs) {
                        HStack(spacing: Theme.Spacing.xxs) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(Theme.Colors.success)
                            Text("Download")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        Text(formatSpeed(featureManager.downloadSpeed))
                            .font(Theme.Typography.statSmall)
                            .foregroundColor(Theme.Colors.success)
                    }

                    // Upload
                    VStack(spacing: Theme.Spacing.xxs) {
                        HStack(spacing: Theme.Spacing.xxs) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(Theme.Colors.info)
                            Text("Upload")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        Text(formatSpeed(featureManager.uploadSpeed))
                            .font(Theme.Typography.statSmall)
                            .foregroundColor(Theme.Colors.info)
                    }

                    Spacer()

                    // Total
                    VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                        Text("Total")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                        Text(formatBytes(featureManager.totalBytesReceived + featureManager.totalBytesSent))
                            .font(Theme.Typography.mono)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }

                NetworkChart(
                    downloadData: featureManager.downloadHistory,
                    uploadData: featureManager.uploadHistory,
                    height: 80
                )
            }
        }
    }

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_000_000_000 {
            return String(format: "%.1f GB/s", bytesPerSecond / 1_000_000_000)
        } else if bytesPerSecond >= 1_000_000 {
            return String(format: "%.1f MB/s", bytesPerSecond / 1_000_000)
        } else if bytesPerSecond >= 1_000 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1_000)
        } else {
            return String(format: "%.0f B/s", bytesPerSecond)
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        } else {
            let mb = Double(bytes) / 1_048_576
            return String(format: "%.1f MB", mb)
        }
    }
}

// MARK: - Battery Card
struct BatteryCard: View {
    let batteryInfo: BatteryInfo

    var body: some View {
        DashboardCard(title: "Battery", icon: "battery.100", iconColor: Theme.Colors.success) {
            if !batteryInfo.isPresent {
                HStack {
                    Image(systemName: "bolt.slash")
                        .foregroundColor(Theme.Colors.textMuted)
                    Text("No battery")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    HStack {
                        BatteryIndicator(
                            percentage: batteryInfo.currentCapacity,
                            isCharging: batteryInfo.isCharging,
                            isPluggedIn: batteryInfo.isPluggedIn
                        )

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(batteryInfo.currentCapacity)%")
                                .font(Theme.Typography.statSmall)
                                .foregroundColor(batteryColor)

                            Text(batteryInfo.isCharging ? "Charging" : batteryInfo.isPluggedIn ? "Plugged In" : "On Battery")
                                .font(Theme.Typography.footnote)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }

                    Divider()
                        .background(Theme.Colors.cardBorder)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Health")
                                .font(Theme.Typography.footnote)
                                .foregroundColor(Theme.Colors.textMuted)
                            Text(String(format: "%.0f%%", batteryInfo.health))
                                .font(Theme.Typography.mono)
                                .foregroundColor(healthColor)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Cycles")
                                .font(Theme.Typography.footnote)
                                .foregroundColor(Theme.Colors.textMuted)
                            Text("\(batteryInfo.cycleCount)")
                                .font(Theme.Typography.mono)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private var batteryColor: Color {
        if batteryInfo.currentCapacity <= 20 { return Theme.Colors.critical }
        else if batteryInfo.currentCapacity <= 40 { return Theme.Colors.warning }
        else { return Theme.Colors.success }
    }

    private var healthColor: Color {
        if batteryInfo.health >= 80 { return Theme.Colors.success }
        else if batteryInfo.health >= 60 { return Theme.Colors.warning }
        else { return Theme.Colors.critical }
    }
}

// MARK: - Thermal Card
struct ThermalCard: View {
    let cpuTemp: Double
    let gpuTemp: Double

    var body: some View {
        DashboardCard(title: "Thermal", icon: "thermometer.medium", iconColor: temperatureColor(cpuTemp)) {
            VStack(spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.lg) {
                    ArcGauge(
                        value: cpuTemp,
                        maxValue: 100,
                        title: "CPU",
                        unit: "°C",
                        color: temperatureColor(cpuTemp),
                        size: 80
                    )

                    ArcGauge(
                        value: gpuTemp,
                        maxValue: 100,
                        title: "GPU",
                        unit: "°C",
                        color: temperatureColor(gpuTemp),
                        size: 80
                    )
                }

                HStack {
                    Text("Status:")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                    Text(thermalStatus)
                        .font(Theme.Typography.caption)
                        .foregroundColor(thermalStatusColor)
                    Spacer()
                }
            }
        }
    }

    private func temperatureColor(_ temp: Double) -> Color {
        if temp >= 85 { return Theme.Colors.critical }
        else if temp >= 70 { return Theme.Colors.warning }
        else if temp >= 55 { return Color.yellow }
        else { return Theme.Colors.success }
    }

    private var thermalStatus: String {
        let avg = (cpuTemp + gpuTemp) / 2
        if avg >= 85 { return "Critical - Throttling" }
        else if avg >= 70 { return "Warm" }
        else if avg >= 55 { return "Normal" }
        else { return "Cool" }
    }

    private var thermalStatusColor: Color {
        temperatureColor((cpuTemp + gpuTemp) / 2)
    }
}

// MARK: - Top Processes Card
struct TopProcessesCard: View {
    @ObservedObject var featureManager: FeatureManager

    var body: some View {
        DashboardCard(title: "Top Processes", icon: "list.bullet", iconColor: Theme.Colors.tertiary) {
            VStack(spacing: Theme.Spacing.xs) {
                // Header
                HStack {
                    Text("#")
                        .frame(width: 20, alignment: .leading)
                    Text("Name")
                    Spacer()
                    Text("CPU")
                        .frame(width: 50, alignment: .trailing)
                    Text("MEM")
                        .frame(width: 60, alignment: .trailing)
                    Text("")
                        .frame(width: 20)
                }
                .font(Theme.Typography.footnote)
                .foregroundColor(Theme.Colors.textMuted)

                Divider()
                    .background(Theme.Colors.cardBorder)

                if featureManager.topProcesses.isEmpty {
                    Button(action: { featureManager.loadTopProcesses() }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Load Processes")
                        }
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.info)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, Theme.Spacing.sm)
                } else {
                    ForEach(Array(featureManager.topProcesses.prefix(5).enumerated()), id: \.element.id) { index, process in
                        ProcessRow(
                            rank: index + 1,
                            name: processName(process.name),
                            cpu: process.cpu,
                            memory: formatMemory(process.memory),
                            pid: process.pid,
                            onKill: { _ = featureManager.killProcess(pid: process.pid) }
                        )
                    }

                    Button(action: { featureManager.loadTopProcesses() }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh")
                        }
                        .font(Theme.Typography.footnote)
                        .foregroundColor(Theme.Colors.info)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Theme.Spacing.xs)
                }
            }
        }
    }

    private func processName(_ fullPath: String) -> String {
        let components = fullPath.components(separatedBy: "/")
        return components.last ?? fullPath
    }

    private func formatMemory(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1024 {
            return String(format: "%.1fGB", mb / 1024)
        } else {
            return String(format: "%.0fMB", mb)
        }
    }
}

// MARK: - Action Bar
struct ActionBar: View {
    @ObservedObject var featureManager: FeatureManager
    @ObservedObject var appManager: AppManager
    @ObservedObject var smartCleanManager: SmartCleanManager
    @ObservedObject var processManager: ProcessManager
    @ObservedObject var startupManager: StartupManager
    @ObservedObject var hardwareIntegrityManager: HardwareIntegrityManager

    @State private var showLargeFiles = false
    @State private var showUninstallApps = false
    @State private var showSmartClean = false
    @State private var showProcessManager = false
    @State private var showStartupManager = false
    @State private var showHardwareCheck = false

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ActionButton(
                title: "Smart Clean",
                icon: "sparkles",
                color: .orange,
                isLoading: smartCleanManager.isScanning || smartCleanManager.isCleaning
            ) {
                showSmartClean = true
            }

            ActionButton(
                title: "RAM",
                icon: "wand.and.stars",
                color: Theme.Colors.chartMemory,
                isLoading: featureManager.isCleaningRAM
            ) {
                featureManager.openRAMCleaner()
            }

            ActionButton(
                title: "Large Files",
                icon: "folder.fill",
                color: Theme.Colors.chartDisk,
                isLoading: featureManager.isLoadingApps
            ) {
                showLargeFiles = true
            }

            ActionButton(
                title: "Uninstall",
                icon: "trash.square",
                color: Theme.Colors.critical,
                isLoading: appManager.isScanning || appManager.isUninstalling
            ) {
                showUninstallApps = true
            }

            ActionButton(
                title: "Processes",
                icon: "list.bullet.rectangle",
                color: .purple,
                isLoading: processManager.isLoading
            ) {
                showProcessManager = true
            }

            ActionButton(
                title: "Startup",
                icon: "power.circle.fill",
                color: .green,
                isLoading: startupManager.isLoading
            ) {
                showStartupManager = true
            }

            ActionButton(
                title: "HW Check",
                icon: "checkmark.shield",
                color: .cyan,
                isLoading: hardwareIntegrityManager.isScanning
            ) {
                showHardwareCheck = true
            }

            Spacer()

            // Status indicator
            if !featureManager.lastRAMCleanResult.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.success)
                    Text(featureManager.lastRAMCleanResult)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.success)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.headerBackground)
        .sheet(isPresented: $showLargeFiles) {
            LargeFilesView(featureManager: featureManager, isPresented: $showLargeFiles)
        }
        .sheet(isPresented: $showUninstallApps) {
            AppUninstallView(appManager: appManager, isPresented: $showUninstallApps)
        }
        .sheet(isPresented: $showSmartClean) {
            SmartCleanView(smartCleanManager: smartCleanManager, isPresented: $showSmartClean)
        }
        .sheet(isPresented: $showProcessManager) {
            ProcessManagerView(processManager: processManager, isPresented: $showProcessManager)
        }
        .sheet(isPresented: $showStartupManager) {
            StartupManagerView(startupManager: startupManager, isPresented: $showStartupManager)
        }
        .sheet(isPresented: $featureManager.showRAMCleanerSheet) {
            RAMCleanerView(featureManager: featureManager)
        }
        .sheet(isPresented: $showHardwareCheck) {
            HardwareIntegrityView(manager: hardwareIntegrityManager, isPresented: $showHardwareCheck)
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }
}

// MARK: - Large Files View
struct LargeFilesView: View {
    @ObservedObject var featureManager: FeatureManager
    @Binding var isPresented: Bool
    @State private var selectedFiles: Set<UUID> = []
    @State private var showConfirmation = false
    @State private var isDeleting = false
    @State private var deletionComplete = false
    @State private var deletedCount = 0
    @State private var deletedSize: UInt64 = 0

    var selectedSize: UInt64 {
        featureManager.largeApps
            .filter { selectedFiles.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "folder.circle.fill")
                    .font(.title)
                    .foregroundColor(Theme.Colors.chartDisk)
                Text("Large Files & Apps")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

            Divider()

            if featureManager.isLoadingApps {
                // Scanning state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Scanning for large files...")
                        .foregroundColor(.secondary)
                    Text("Checking /Applications and user folders")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if deletionComplete {
                // Completion state
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("Deletion Complete!")
                        .font(.headline)
                    Text("Removed \(deletedCount) items (\(formatBytes(deletedSize)))")
                        .foregroundColor(.secondary)

                    Button("Done") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isDeleting {
                // Deleting state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Deleting selected files...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // File list
                VStack(spacing: 0) {
                    // Info banner
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Select files to delete. Apps >100MB shown.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Select All") {
                            selectedFiles = Set(featureManager.largeApps.map { $0.id })
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)

                        Button("Clear") {
                            selectedFiles.removeAll()
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundColor(.orange)
                    }
                    .padding(10)
                    .background(Color.blue.opacity(0.1))

                    if featureManager.largeApps.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            Text("No large files found")
                                .foregroundColor(.secondary)
                            Text("Files larger than 100MB will appear here")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // File list
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(featureManager.largeApps) { app in
                                    LargeFileRow(
                                        app: app,
                                        isSelected: selectedFiles.contains(app.id),
                                        onToggle: {
                                            if selectedFiles.contains(app.id) {
                                                selectedFiles.remove(app.id)
                                            } else {
                                                selectedFiles.insert(app.id)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                    }
                }

                // Action buttons
                VStack(spacing: 12) {
                    Divider()

                    // Selected summary
                    if !selectedFiles.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("\(selectedFiles.count) selected")
                            Spacer()
                            Text(formatBytes(selectedSize))
                                .font(.headline.monospacedDigit())
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal)
                    }

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            isPresented = false
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)

                        Button(action: {
                            showConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Delete Selected")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .frame(maxWidth: .infinity)
                        .disabled(selectedFiles.isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
        .frame(width: 450, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .alert("Delete Files?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedFiles()
            }
        } message: {
            Text("Are you sure you want to delete \(selectedFiles.count) items (\(formatBytes(selectedSize)))? This will move them to Trash.")
        }
        .onAppear {
            featureManager.loadLargeApps()
        }
    }

    private func deleteSelectedFiles() {
        isDeleting = true
        let filesToDelete = featureManager.largeApps.filter { selectedFiles.contains($0.id) }
        deletedCount = filesToDelete.count
        deletedSize = selectedSize

        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default

            for file in filesToDelete {
                do {
                    try fileManager.trashItem(at: URL(fileURLWithPath: file.path), resultingItemURL: nil)
                } catch {
                    print("Failed to delete \(file.path): \(error)")
                }
            }

            DispatchQueue.main.async {
                isDeleting = false
                deletionComplete = true
                selectedFiles.removeAll()
                featureManager.loadLargeApps() // Refresh list
            }
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
}

// MARK: - Large File Row
struct LargeFileRow: View {
    let app: AppInfo
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .green : .secondary)

                // Icon
                Image(systemName: app.path.hasSuffix(".app") ? "app" : "doc")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.chartDisk)
                    .frame(width: 24)

                // Name and path
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(app.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                // Size
                Text(formatBytes(app.size))
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(app.size > 1_073_741_824 ? .orange : .secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.green.opacity(0.1) : Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
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
}

// MARK: - RAM Cleaner View
struct RAMCleanerView: View {
    @ObservedObject var featureManager: FeatureManager

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "memorychip")
                    .font(.title2)
                    .foregroundColor(Theme.Colors.chartMemory)
                Text("RAM Cleaner")
                    .font(.headline)
                Spacer()
                Button(action: { featureManager.showRAMCleanerSheet = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            VStack(spacing: 16) {
                // Memory visualization
                HStack(spacing: 30) {
                    // Before
                    VStack(spacing: 6) {
                        Text("Before")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)

                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                                .frame(width: 90, height: 90)

                            Circle()
                                .trim(from: 0, to: usedPercentageBefore)
                                .stroke(Theme.Colors.chartMemory, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 90, height: 90)
                                .rotationEffect(.degrees(-90))

                            VStack(spacing: 2) {
                                Text("\(Int(usedPercentageBefore * 100))%")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                Text("Used")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }

                        VStack(spacing: 2) {
                            Text("Used: \(formatBytes(featureManager.ramCleanerState.usedBefore))")
                                .font(.system(size: 11, design: .monospaced))
                            Text("Free: \(formatBytes(featureManager.ramCleanerState.memoryBefore))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Arrow / Loading
                    VStack(spacing: 4) {
                        if featureManager.ramCleanerState.isComplete {
                            Image(systemName: "arrow.right")
                                .font(.title2)
                                .foregroundColor(Theme.Colors.success)

                            if featureManager.ramCleanerState.memoryFreed > 0 {
                                Text("-\(formatBytes(featureManager.ramCleanerState.memoryFreed))")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Theme.Colors.success)
                            }
                        } else if featureManager.isCleaningRAM {
                            ProgressView()
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "arrow.right")
                                .font(.title2)
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                    }
                    .frame(width: 60)

                    // After
                    VStack(spacing: 6) {
                        Text("After")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)

                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                                .frame(width: 90, height: 90)

                            if featureManager.ramCleanerState.isComplete {
                                Circle()
                                    .trim(from: 0, to: usedPercentageAfter)
                                    .stroke(Theme.Colors.success, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                    .frame(width: 90, height: 90)
                                    .rotationEffect(.degrees(-90))

                                VStack(spacing: 2) {
                                    Text("\(Int(usedPercentageAfter * 100))%")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                    Text("Used")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                VStack(spacing: 2) {
                                    Text("--")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.secondary)
                                    Text("Used")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        if featureManager.ramCleanerState.isComplete {
                            VStack(spacing: 2) {
                                Text("Used: \(formatBytes(featureManager.ramCleanerState.usedAfter))")
                                    .font(.system(size: 11, design: .monospaced))
                                Text("Free: \(formatBytes(featureManager.ramCleanerState.memoryAfter))")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Theme.Colors.success)
                            }
                        } else {
                            VStack(spacing: 2) {
                                Text("Used: --")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Text("Free: --")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.top, 8)

                // Status
                HStack(spacing: 8) {
                    if featureManager.isCleaningRAM {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if featureManager.ramCleanerState.isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Theme.Colors.success)
                    }

                    Text(featureManager.ramCleanerState.status)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(featureManager.ramCleanerState.isComplete ? Theme.Colors.success : .secondary)
                }

                // Memory details
                VStack(spacing: 8) {
                    HStack {
                        Text("Total RAM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatBytes(featureManager.ramCleanerState.totalMemory))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }

                    if featureManager.ramCleanerState.isComplete && featureManager.ramCleanerState.memoryFreed > 0 {
                        HStack {
                            Text("Memory Freed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatBytes(featureManager.ramCleanerState.memoryFreed))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(Theme.Colors.success)
                        }

                        HStack {
                            Text("Available Now")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatBytes(featureManager.ramCleanerState.memoryAfter))
                                .font(.system(size: 12, design: .monospaced))
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                Spacer()
            }
            .padding()

            Divider()

            // Footer
            HStack {
                Spacer()

                if featureManager.ramCleanerState.isComplete {
                    Button("Done") {
                        featureManager.showRAMCleanerSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(action: {
                        featureManager.cleanRAM()
                    }) {
                        HStack(spacing: 6) {
                            if featureManager.isCleaningRAM {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Cleaning...")
                            } else {
                                Image(systemName: "wand.and.stars")
                                Text("Clean RAM")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.Colors.chartMemory)
                    .disabled(featureManager.isCleaningRAM)
                }
            }
            .padding()
        }
        .frame(width: 340, height: 420)
    }

    private var usedPercentageBefore: Double {
        guard featureManager.ramCleanerState.totalMemory > 0 else { return 0 }
        return Double(featureManager.ramCleanerState.usedBefore) / Double(featureManager.ramCleanerState.totalMemory)
    }

    private var usedPercentageAfter: Double {
        guard featureManager.ramCleanerState.totalMemory > 0 else { return 0 }
        return Double(featureManager.ramCleanerState.usedAfter) / Double(featureManager.ramCleanerState.totalMemory)
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
}

// MARK: - Preview
#Preview {
    DashboardView(
        systemMonitor: SystemMonitor(),
        featureManager: FeatureManager(),
        cacheManager: CacheManager(),
        appManager: AppManager(),
        smartCleanManager: SmartCleanManager(),
        settings: SettingsManager()
    )
    .frame(width: 900, height: 600)
}
