import SwiftUI

// MARK: - Collapsible Section
struct CollapsibleSection<Content: View>: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack {
                    Label(title, systemImage: icon)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Feature 1: Large Apps View
struct LargeAppsView: View {
    @ObservedObject var featureManager: FeatureManager
    @Binding var isExpanded: Bool

    var body: some View {
        CollapsibleSection(title: "Large Apps", icon: "app.badge", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 4) {
                if featureManager.isLoadingApps {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Scanning apps...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if featureManager.largeApps.isEmpty {
                    Button("Scan Apps") {
                        featureManager.loadLargeApps()
                    }
                    .font(.caption)
                } else {
                    ForEach(featureManager.largeApps.prefix(5)) { app in
                        HStack(spacing: 8) {
                            if let icon = app.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            }
                            Text(app.name)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer()
                            Text(FeatureManager.formatBytes(app.size))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                            Button(action: { featureManager.revealInFinder(path: app.path) }) {
                                Image(systemName: "folder")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.blue)
                        }
                    }

                    Button("Refresh") {
                        featureManager.loadLargeApps()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - Feature 2: Duplicate Files View
struct DuplicateFilesView: View {
    @ObservedObject var featureManager: FeatureManager
    @Binding var isExpanded: Bool
    @State private var selectedFiles: Set<String> = []

    var body: some View {
        CollapsibleSection(title: "Duplicate Files", icon: "doc.on.doc", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 4) {
                if featureManager.isScannningDuplicates {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(featureManager.duplicateScanProgress)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if featureManager.duplicateGroups.isEmpty {
                    Button("Scan for Duplicates") {
                        featureManager.scanForDuplicates()
                    }
                    .font(.caption)
                } else {
                    let totalWasted = featureManager.duplicateGroups.reduce(0) { $0 + $1.totalWastedSpace }
                    Text("Found \(featureManager.duplicateGroups.count) duplicate groups (\(FeatureManager.formatBytes(totalWasted)) wasted)")
                        .font(.caption)
                        .foregroundColor(.orange)

                    ForEach(featureManager.duplicateGroups.prefix(3)) { group in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(group.files.count) copies • \(FeatureManager.formatBytes(group.files.first?.size ?? 0)) each")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            ForEach(group.files) { file in
                                HStack(spacing: 4) {
                                    Image(systemName: selectedFiles.contains(file.path) ? "checkmark.circle.fill" : "circle")
                                        .font(.caption2)
                                        .foregroundColor(selectedFiles.contains(file.path) ? .green : .secondary)
                                        .onTapGesture {
                                            if selectedFiles.contains(file.path) {
                                                selectedFiles.remove(file.path)
                                            } else {
                                                selectedFiles.insert(file.path)
                                            }
                                        }

                                    Text(file.name)
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    HStack {
                        Button("Rescan") {
                            featureManager.scanForDuplicates()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)

                        Spacer()

                        if !selectedFiles.isEmpty {
                            Button("Delete Selected (\(selectedFiles.count))") {
                                for path in selectedFiles {
                                    _ = featureManager.deleteFile(at: path)
                                }
                                selectedFiles.removeAll()
                                featureManager.scanForDuplicates()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - Feature 3: Old Files View
struct OldFilesView: View {
    @ObservedObject var featureManager: FeatureManager
    @Binding var isExpanded: Bool

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()

    var body: some View {
        CollapsibleSection(title: "Old Files (6+ months)", icon: "clock.arrow.circlepath", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 4) {
                if featureManager.isLoadingOldFiles {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Scanning for old files...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if featureManager.oldFiles.isEmpty {
                    Button("Find Old Files") {
                        featureManager.loadOldFiles()
                    }
                    .font(.caption)
                } else {
                    Text("Found \(featureManager.oldFiles.count) old files")
                        .font(.caption)
                        .foregroundColor(.orange)

                    ForEach(featureManager.oldFiles.prefix(5)) { file in
                        HStack(spacing: 6) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(file.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text("Last opened: \(dateFormatter.string(from: file.lastAccessed))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(FeatureManager.formatBytes(file.size))
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(.secondary)
                            Button(action: {
                                _ = featureManager.moveToTrash(path: file.path)
                                featureManager.loadOldFiles()
                            }) {
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.red)
                        }
                    }

                    Button("Refresh") {
                        featureManager.loadOldFiles()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - Feature 4: Network Stats View (Inline for menu bar)
struct NetworkStatsView: View {
    @ObservedObject var featureManager: FeatureManager

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .font(.caption2)
                    .foregroundColor(.green)
                Text(featureManager.formatSpeed(featureManager.uploadSpeed))
                    .font(.caption.monospacedDigit())
            }

            HStack(spacing: 2) {
                Image(systemName: "arrow.down")
                    .font(.caption2)
                    .foregroundColor(.blue)
                Text(featureManager.formatSpeed(featureManager.downloadSpeed))
                    .font(.caption.monospacedDigit())
            }
        }
    }
}

// MARK: - Feature 5: Alerts Toggle View
struct AlertsToggleView: View {
    @ObservedObject var featureManager: FeatureManager

    var body: some View {
        HStack {
            Label("Smart Alerts", systemImage: "bell.badge")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Toggle("", isOn: $featureManager.alertsEnabled)
                .toggleStyle(.switch)
                .scaleEffect(0.7)
        }
    }
}

// MARK: - Feature 6: Process Killer View
struct ProcessKillerView: View {
    @ObservedObject var featureManager: FeatureManager
    @Binding var isExpanded: Bool
    @State private var confirmKillPid: Int32?

    var body: some View {
        CollapsibleSection(title: "Top Processes", icon: "cpu", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 4) {
                if featureManager.isLoadingProcesses {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading processes...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if featureManager.topProcesses.isEmpty {
                    Button("Load Processes") {
                        featureManager.loadTopProcesses()
                    }
                    .font(.caption)
                } else {
                    // Header
                    HStack {
                        Text("Name")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("CPU")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 40)
                        Text("RAM")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 50)
                        Text("")
                            .frame(width: 24)
                    }

                    ForEach(featureManager.topProcesses.prefix(6)) { process in
                        HStack(spacing: 4) {
                            Text(process.name)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer()
                            Text(String(format: "%.1f%%", process.cpu))
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(process.cpu > 50 ? .red : .secondary)
                                .frame(width: 40)
                            Text(FeatureManager.formatBytes(process.memory))
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(.secondary)
                                .frame(width: 50)

                            if confirmKillPid == process.pid {
                                Button(action: {
                                    _ = featureManager.forceKillProcess(pid: process.pid)
                                    confirmKillPid = nil
                                }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.red)
                            } else {
                                Button(action: {
                                    confirmKillPid = process.pid
                                    // Auto-reset after 3 seconds
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        if confirmKillPid == process.pid {
                                            confirmKillPid = nil
                                        }
                                    }
                                }) {
                                    Image(systemName: "xmark.circle")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.orange)
                            }
                        }
                    }

                    Button("Refresh") {
                        featureManager.loadTopProcesses()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - Feature 7: Battery Health View
struct BatteryHealthView: View {
    @ObservedObject var featureManager: FeatureManager
    @Binding var isExpanded: Bool

    var body: some View {
        CollapsibleSection(title: "Battery Health", icon: "battery.100", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 6) {
                if !featureManager.batteryInfo.isPresent {
                    Text("No battery detected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    // Charge level with visual bar
                    HStack {
                        Text("Charge")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(featureManager.batteryInfo.currentCapacity)%")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(batteryChargeColor)
                        batteryIcon
                    }

                    // Status
                    HStack {
                        Text("Status")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 4) {
                            if featureManager.batteryInfo.isCharging {
                                Image(systemName: "bolt.fill")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                                Text("Charging")
                            } else if featureManager.batteryInfo.isPluggedIn {
                                Image(systemName: "powerplug.fill")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                Text("Plugged In")
                            } else {
                                Image(systemName: "battery.100")
                                    .font(.caption2)
                                Text("On Battery")
                            }
                        }
                        .font(.caption)
                    }

                    // Time remaining
                    HStack {
                        Text(featureManager.batteryInfo.isCharging ? "Time to Full" : "Time Remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(featureManager.formatTimeRemaining(featureManager.batteryInfo.timeRemaining))
                            .font(.caption)
                    }

                    Divider()

                    // Health
                    HStack {
                        Text("Health")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f%%", featureManager.batteryInfo.health))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(healthColor)
                    }

                    // Cycle count
                    HStack {
                        Text("Cycle Count")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(featureManager.batteryInfo.cycleCount)")
                            .font(.caption.monospacedDigit())
                    }

                    // Condition
                    HStack {
                        Text("Condition")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(featureManager.batteryInfo.condition)
                            .font(.caption)
                            .foregroundColor(conditionColor)
                    }

                    Button("Refresh") {
                        featureManager.updateBatteryInfo()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 4)
                }
            }
        }
    }

    private var batteryChargeColor: Color {
        let charge = featureManager.batteryInfo.currentCapacity
        if charge <= 20 { return .red }
        else if charge <= 40 { return .orange }
        else { return .green }
    }

    private var batteryIcon: some View {
        let charge = featureManager.batteryInfo.currentCapacity
        let iconName: String
        if charge > 75 { iconName = "battery.100" }
        else if charge > 50 { iconName = "battery.75" }
        else if charge > 25 { iconName = "battery.50" }
        else { iconName = "battery.25" }

        return Image(systemName: iconName)
            .font(.caption)
            .foregroundColor(batteryChargeColor)
    }

    private var healthColor: Color {
        let health = featureManager.batteryInfo.health
        if health >= 80 { return .green }
        else if health >= 60 { return .orange }
        else { return .red }
    }

    private var conditionColor: Color {
        switch featureManager.batteryInfo.condition {
        case "Normal": return .green
        case "Service Recommended": return .orange
        default: return .red
        }
    }
}

// MARK: - Feature 8: Temperature View
struct TemperatureView: View {
    @ObservedObject var featureManager: FeatureManager
    @Binding var isExpanded: Bool

    var body: some View {
        CollapsibleSection(title: "Temperature", icon: "thermometer.medium", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 6) {
                // CPU Temperature
                HStack {
                    Image(systemName: "cpu")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("CPU")
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.0f°C", featureManager.cpuTemperature))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(temperatureColor(featureManager.cpuTemperature))
                    temperatureIndicator(featureManager.cpuTemperature)
                }

                // GPU Temperature
                HStack {
                    Image(systemName: "rectangle.3.group")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("GPU")
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.0f°C", featureManager.gpuTemperature))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(temperatureColor(featureManager.gpuTemperature))
                    temperatureIndicator(featureManager.gpuTemperature)
                }

                // Thermal status
                HStack {
                    Text("Thermal State")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(thermalStateText)
                        .font(.caption)
                        .foregroundColor(thermalStateColor)
                }

                Button("Refresh") {
                    featureManager.updateTemperatures()
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.top, 4)
            }
        }
    }

    private func temperatureColor(_ temp: Double) -> Color {
        if temp >= 85 { return .red }
        else if temp >= 70 { return .orange }
        else if temp >= 55 { return .yellow }
        else { return .green }
    }

    private func temperatureIndicator(_ temp: Double) -> some View {
        let iconName: String
        if temp >= 85 { iconName = "thermometer.sun.fill" }
        else if temp >= 70 { iconName = "thermometer.high" }
        else if temp >= 55 { iconName = "thermometer.medium" }
        else { iconName = "thermometer.low" }

        return Image(systemName: iconName)
            .font(.caption)
            .foregroundColor(temperatureColor(temp))
    }

    private var thermalStateText: String {
        let avgTemp = (featureManager.cpuTemperature + featureManager.gpuTemperature) / 2
        if avgTemp >= 85 { return "Critical" }
        else if avgTemp >= 70 { return "Warm" }
        else if avgTemp >= 55 { return "Normal" }
        else { return "Cool" }
    }

    private var thermalStateColor: Color {
        let avgTemp = (featureManager.cpuTemperature + featureManager.gpuTemperature) / 2
        if avgTemp >= 85 { return .red }
        else if avgTemp >= 70 { return .orange }
        else if avgTemp >= 55 { return .primary }
        else { return .green }
    }
}

// MARK: - Feature 10: Usage History View
struct UsageHistoryView: View {
    @ObservedObject var featureManager: FeatureManager
    @Binding var isExpanded: Bool

    var body: some View {
        CollapsibleSection(title: "Usage History", icon: "chart.xyaxis.line", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                if featureManager.usageHistory.isEmpty {
                    Text("Collecting data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    // Mini charts
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CPU (last \(featureManager.usageHistory.count) min)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        UsageHistoryChart(data: featureManager.usageHistory.map { $0.cpuUsage }, color: .blue)
                            .frame(height: 30)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Memory (last \(featureManager.usageHistory.count) min)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        UsageHistoryChart(data: featureManager.usageHistory.map { $0.memoryUsage }, color: .purple)
                            .frame(height: 30)
                    }

                    // Stats
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Avg CPU")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f%%", featureManager.getAverageCPU()))
                                .font(.caption.monospacedDigit())
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Peak CPU")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f%%", featureManager.getPeakCPU()))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.orange)
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Avg RAM")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f%%", featureManager.getAverageMemory()))
                                .font(.caption.monospacedDigit())
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Peak RAM")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f%%", featureManager.getPeakMemory()))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Usage History Chart
struct UsageHistoryChart: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            if data.count > 1 {
                // Line
                Path { path in
                    let stepX = geometry.size.width / CGFloat(data.count - 1)
                    let maxY = geometry.size.height

                    path.move(to: CGPoint(x: 0, y: maxY - (CGFloat(data[0]) / 100 * maxY)))

                    for index in 1..<data.count {
                        let x = stepX * CGFloat(index)
                        let y = maxY - (CGFloat(data[index]) / 100 * maxY)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(color, lineWidth: 1.5)

                // Fill
                Path { path in
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
                .fill(color.opacity(0.2))
            }
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(4)
    }
}
