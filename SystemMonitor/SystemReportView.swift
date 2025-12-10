import SwiftUI
import AppKit

struct SystemReportView: View {
    @ObservedObject var reportManager: SystemReportManager
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Export System Report")
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

            // Content
            VStack(spacing: 20) {
                if reportManager.isGenerating {
                    // Progress view
                    VStack(spacing: 16) {
                        ProgressView(value: reportManager.progress)
                            .progressViewStyle(.linear)
                            .frame(width: 250)

                        Text(reportManager.currentTask)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("\(Int(reportManager.progress * 100))%")
                            .font(.title2.monospacedDigit())
                            .foregroundColor(.blue)
                    }
                    .padding(40)
                } else if reportManager.reportGenerated {
                    // Success view
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)

                        Text("Report Generated!")
                            .font(.headline)

                        if let path = reportManager.lastReportPath {
                            Text("Saved to Desktop")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text((path as NSString).lastPathComponent)
                                .font(.caption.monospaced())
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                        }

                        HStack(spacing: 12) {
                            Button("Show in Finder") {
                                reportManager.openReport()
                            }
                            .buttonStyle(.bordered)

                            Button("Generate New") {
                                reportManager.reportGenerated = false
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(40)
                } else {
                    // Initial view
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("Generate System Report")
                            .font(.headline)

                        Text("Create a detailed report of your system including hardware info, memory, disk usage, running processes, and installed applications.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        // What's included
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Report includes:")
                                .font(.caption.weight(.semibold))

                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 4) {
                                    ReportItem(icon: "desktopcomputer", text: "System Info")
                                    ReportItem(icon: "cpu", text: "CPU Details")
                                    ReportItem(icon: "memorychip", text: "Memory Usage")
                                    ReportItem(icon: "internaldrive", text: "Disk Space")
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    ReportItem(icon: "battery.100", text: "Battery Status")
                                    ReportItem(icon: "network", text: "Network Info")
                                    ReportItem(icon: "list.bullet", text: "Top Processes")
                                    ReportItem(icon: "app.badge", text: "Installed Apps")
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)

                        Button(action: {
                            reportManager.generateReport { _ in }
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Generate Report")
                            }
                            .frame(width: 180)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding(30)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 400, height: 450)
    }
}

struct ReportItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 16)
            Text(text)
                .font(.caption)
        }
    }
}

// Compact view for menu
struct SystemReportCompactView: View {
    @ObservedObject var reportManager: SystemReportManager
    var onOpenFullView: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("System Report", systemImage: "doc.text.fill")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            if reportManager.isGenerating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("\(Int(reportManager.progress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            } else {
                Button(action: onOpenFullView) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Export Report")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

#Preview {
    SystemReportView(reportManager: SystemReportManager(), isPresented: .constant(true))
}
