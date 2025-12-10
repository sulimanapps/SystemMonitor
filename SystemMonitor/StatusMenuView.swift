import SwiftUI
import AppKit

struct StatusMenuView: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var cacheManager: CacheManager
    @ObservedObject var featureManager: FeatureManager
    @Binding var showCleanupSheet: Bool
    @Binding var showFeedbackSheet: Bool

    // Section expansion states
    @State private var showLargeApps = false
    @State private var showDuplicates = false
    @State private var showOldFiles = false
    @State private var showProcesses = false
    @State private var showBattery = false
    @State private var showTemperature = false
    @State private var showUsageHistory = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Header with Network Stats
                HStack {
                    Image(systemName: "cpu")
                        .font(.title2)
                    Text("System Monitor")
                        .font(.headline)
                    Spacer()
                    NetworkStatsView(featureManager: featureManager)
                }
                .padding(.bottom, 4)

                Divider()

                // CPU Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("CPU", systemImage: "cpu")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(String(format: "%.1f%%", systemMonitor.cpuUsage))
                            .font(.subheadline.monospacedDigit())
                            .foregroundColor(colorForUsage(systemMonitor.cpuUsage))
                    }

                    // CPU Chart
                    CPUChartView(data: systemMonitor.cpuHistory)
                        .frame(height: 40)
                }

                Divider()

                // Memory Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Memory", systemImage: "memorychip")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(String(format: "%.1f%%", systemMonitor.memoryUsage))
                            .font(.subheadline.monospacedDigit())
                            .foregroundColor(colorForUsage(systemMonitor.memoryUsage))
                    }

                    HStack {
                        Text("\(formatBytes(systemMonitor.memoryUsed)) / \(formatBytes(systemMonitor.memoryTotal))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                    UsageBar(usage: systemMonitor.memoryUsage / 100)
                }

                Divider()

                // Disk Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Disk", systemImage: "internaldrive")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(String(format: "%.1f%%", systemMonitor.diskUsage))
                            .font(.subheadline.monospacedDigit())
                            .foregroundColor(colorForUsage(systemMonitor.diskUsage))
                    }

                    HStack {
                        Text("\(formatBytes(systemMonitor.diskUsed)) / \(formatBytes(systemMonitor.diskTotal))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                    UsageBar(usage: systemMonitor.diskUsage / 100)
                }

                Divider()

                // Feature 6: Process Killer (replaces old Top Processes)
                ProcessKillerView(featureManager: featureManager, isExpanded: $showProcesses)

                Divider()

                // Feature 1: Large Apps
                LargeAppsView(featureManager: featureManager, isExpanded: $showLargeApps)

                Divider()

                // Feature 2: Duplicate Files
                DuplicateFilesView(featureManager: featureManager, isExpanded: $showDuplicates)

                Divider()

                // Feature 3: Old Files
                OldFilesView(featureManager: featureManager, isExpanded: $showOldFiles)

                Divider()

                // Feature 7: Battery Health
                BatteryHealthView(featureManager: featureManager, isExpanded: $showBattery)

                Divider()

                // Feature 8: Temperature
                TemperatureView(featureManager: featureManager, isExpanded: $showTemperature)

                Divider()

                // Feature 9: RAM Cleaner
                RAMCleanerView(featureManager: featureManager)

                Divider()

                // Feature 10: Usage History
                UsageHistoryView(featureManager: featureManager, isExpanded: $showUsageHistory)

                Divider()

                // Storage Cleanup Section
                VStack(alignment: .leading, spacing: 8) {
                    Label("Storage Cleanup", systemImage: "externaldrive")
                        .font(.subheadline.weight(.semibold))

                    CleanCacheButton(cacheManager: cacheManager) {
                        showCleanupSheet = true
                    }
                }

                Divider()

                // Feature 5: Smart Alerts Toggle
                AlertsToggleView(featureManager: featureManager)

                Divider()

                // Links Section
                HStack(spacing: 12) {
                    Button(action: {
                        if let url = URL(string: "https://github.com/sulimanapps/SystemMonitor#readme") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "book.fill")
                                .font(.caption)
                            Text("Docs")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)

                    Button(action: {
                        if let url = URL(string: "https://github.com/sulimanapps/SystemMonitor/issues") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "ladybug.fill")
                                .font(.caption)
                            Text("Issues")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.orange)

                    Button(action: {
                        if let url = URL(string: "https://github.com/sulimanapps/SystemMonitor") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                            Text("Star")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.yellow)
                }

                Divider()

                // Quit Button
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack {
                        Image(systemName: "power")
                        Text("Quit")
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
            .padding()
        }
        .frame(width: 320, height: 600)
    }

    private func colorForUsage(_ usage: Double) -> Color {
        if usage >= 85 {
            return .red
        } else if usage >= 70 {
            return .yellow
        } else {
            return .green
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        } else {
            let mb = Double(bytes) / 1_048_576
            return String(format: "%.0f MB", mb)
        }
    }

    private func processName(_ fullPath: String) -> String {
        let components = fullPath.components(separatedBy: "/")
        return components.last ?? fullPath
    }
}

struct UsageBar: View {
    let usage: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))

                RoundedRectangle(cornerRadius: 4)
                    .fill(colorForUsage(usage * 100))
                    .frame(width: geometry.size.width * CGFloat(min(usage, 1.0)))
            }
        }
        .frame(height: 8)
    }

    private func colorForUsage(_ usage: Double) -> Color {
        if usage >= 85 {
            return .red
        } else if usage >= 70 {
            return .yellow
        } else {
            return .green
        }
    }
}

struct CPUChartView: View {
    let data: [Double]

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard data.count > 1 else { return }

                let stepX = geometry.size.width / CGFloat(data.count - 1)
                let maxY = geometry.size.height

                path.move(to: CGPoint(x: 0, y: maxY - (CGFloat(data[0]) / 100 * maxY)))

                for index in 1..<data.count {
                    let x = stepX * CGFloat(index)
                    let y = maxY - (CGFloat(data[index]) / 100 * maxY)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(Color.blue, lineWidth: 1.5)

            // Fill area under curve
            Path { path in
                guard data.count > 1 else { return }

                let stepX = geometry.size.width / CGFloat(data.count - 1)
                let maxY = geometry.size.height

                path.move(to: CGPoint(x: 0, y: maxY))
                path.addLine(to: CGPoint(x: 0, y: maxY - (CGFloat(data[0]) / 100 * maxY)))

                for index in 1..<data.count {
                    let x = stepX * CGFloat(index)
                    let y = maxY - (CGFloat(data[index]) / 100 * maxY)
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                path.addLine(to: CGPoint(x: geometry.size.width, y: maxY))
                path.closeSubpath()
            }
            .fill(Color.blue.opacity(0.2))
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(4)
    }
}

#Preview {
    StatusMenuView(systemMonitor: SystemMonitor(), cacheManager: CacheManager(), featureManager: FeatureManager(), showCleanupSheet: .constant(false), showFeedbackSheet: .constant(false))
}
