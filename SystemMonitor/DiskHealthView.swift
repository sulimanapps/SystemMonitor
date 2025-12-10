import SwiftUI

struct DiskHealthView: View {
    @ObservedObject var diskHealthManager: DiskHealthManager
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "internaldrive.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Disk Health")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if diskHealthManager.isScanning {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Scanning disks...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if diskHealthManager.disks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "internaldrive.trianglebadge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No disks found")
                        .font(.headline)
                    Button("Scan Disks") {
                        diskHealthManager.scanDisks()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(diskHealthManager.disks) { disk in
                            DiskHealthCard(disk: disk, manager: diskHealthManager)
                        }
                    }
                    .padding()
                }
            }

            Divider()

            // Footer
            HStack {
                if let lastScan = diskHealthManager.lastScanDate {
                    Text("Last scan: \(lastScan, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Rescan") {
                    diskHealthManager.scanDisks()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .frame(width: 450, height: 500)
        .onAppear {
            if diskHealthManager.disks.isEmpty {
                diskHealthManager.scanDisks()
            }
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

struct DiskHealthCard: View {
    let disk: DiskHealthInfo
    let manager: DiskHealthManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: disk.isSSD ? "memorychip" : "internaldrive")
                    .font(.title2)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(disk.name)
                        .font(.headline)
                    Text(disk.model)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Health Status Badge
                HStack(spacing: 4) {
                    Image(systemName: disk.healthStatus.icon)
                    Text(disk.healthStatus.rawValue)
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(healthColor(disk.healthStatus))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(healthColor(disk.healthStatus).opacity(0.15))
                .cornerRadius(8)
            }

            Divider()

            // Info Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                InfoRow(label: "Type", value: disk.isSSD ? "SSD" : "HDD")
                InfoRow(label: "Capacity", value: manager.formatBytes(disk.capacity))
                InfoRow(label: "Serial", value: disk.serialNumber)

                if let temp = disk.temperature {
                    InfoRow(label: "Temperature", value: "\(temp)°C")
                }

                if let hours = disk.powerOnHours {
                    InfoRow(label: "Power On Hours", value: formatHours(hours))
                }

                if let cycles = disk.powerCycleCount {
                    InfoRow(label: "Power Cycles", value: "\(cycles)")
                }
            }

            // S.M.A.R.T. Status
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundColor(.blue)
                Text("S.M.A.R.T. Status")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(disk.healthStatus == .healthy ? "Verified" : disk.healthStatus.rawValue)
                    .font(.caption)
                    .foregroundColor(healthColor(disk.healthStatus))
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func healthColor(_ status: DiskHealthStatus) -> Color {
        switch status {
        case .healthy: return .green
        case .warning: return .yellow
        case .critical: return .red
        case .unknown: return .gray
        }
    }

    private func formatHours(_ hours: Int) -> String {
        let days = hours / 24
        if days > 365 {
            let years = Double(days) / 365.0
            return String(format: "%.1f years", years)
        } else if days > 0 {
            return "\(days) days"
        }
        return "\(hours) hours"
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
        }
    }
}

// Compact view for menu
struct DiskHealthCompactView: View {
    @ObservedObject var diskHealthManager: DiskHealthManager
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Label("Disk Health", systemImage: "internaldrive.fill")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if let disk = diskHealthManager.disks.first {
                        HStack(spacing: 4) {
                            Image(systemName: disk.healthStatus.icon)
                                .font(.caption)
                            Text(disk.healthStatus.rawValue)
                                .font(.caption)
                        }
                        .foregroundColor(healthColor(disk.healthStatus))
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                if diskHealthManager.isScanning {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Scanning...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let disk = diskHealthManager.disks.first {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(disk.name)
                                .font(.caption.weight(.medium))
                            Spacer()
                            Text(diskHealthManager.formatBytes(disk.capacity))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Image(systemName: disk.isSSD ? "memorychip" : "internaldrive")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(disk.isSSD ? "SSD" : "HDD")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: "shield.checkered")
                                    .font(.caption)
                                Text("S.M.A.R.T.: \(disk.healthStatus == .healthy ? "OK" : disk.healthStatus.rawValue)")
                                    .font(.caption)
                            }
                            .foregroundColor(healthColor(disk.healthStatus))
                        }
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    Button("Scan Disks") {
                        diskHealthManager.scanDisks()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }
        }
        .onAppear {
            if diskHealthManager.disks.isEmpty {
                diskHealthManager.scanDisks()
            }
        }
    }

    private func healthColor(_ status: DiskHealthStatus) -> Color {
        switch status {
        case .healthy: return .green
        case .warning: return .yellow
        case .critical: return .red
        case .unknown: return .gray
        }
    }
}

#Preview {
    DiskHealthView(diskHealthManager: DiskHealthManager(), isPresented: .constant(true))
}
