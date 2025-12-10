import SwiftUI

// MARK: - Hardware Integrity View
struct HardwareIntegrityView: View {
    @ObservedObject var manager: HardwareIntegrityManager
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            if manager.isScanning {
                scanningView
            } else if manager.scanComplete {
                resultsView
            } else {
                welcomeView
            }
        }
        .frame(width: 600, height: 650)
        .background(Theme.Colors.background)
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 24))
                .foregroundColor(Theme.Colors.primary)

            Text("Hardware Integrity Check")
                .font(.title2.bold())
                .foregroundColor(Theme.Colors.textPrimary)

            Spacer()

            Button(action: { isPresented = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Theme.Colors.cardBackground)
    }

    // MARK: - Welcome View
    private var welcomeView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "laptopcomputer.and.iphone")
                .font(.system(size: 64))
                .foregroundColor(Theme.Colors.primary)

            Text("Hardware Integrity Check")
                .font(.title.bold())
                .foregroundColor(Theme.Colors.textPrimary)

            Text("Analyze your Mac's hardware to check for modifications,\nreplaced components, and overall system integrity.")
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.Colors.textSecondary)

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "cpu", text: "System identifiers verification")
                FeatureRow(icon: "battery.100", text: "Battery health analysis")
                FeatureRow(icon: "internaldrive", text: "Storage integrity check")
                FeatureRow(icon: "display", text: "Display component verification")
                FeatureRow(icon: "memorychip", text: "Memory configuration check")
            }
            .padding()
            .background(Theme.Colors.cardBackground)
            .cornerRadius(12)

            Button(action: { manager.performScan() }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Scan")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Theme.Colors.primary)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding()
    }

    // MARK: - Scanning View
    private var scanningView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primary))

            Text(manager.currentTask)
                .font(.headline)
                .foregroundColor(Theme.Colors.textPrimary)

            ProgressView(value: manager.scanProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: Theme.Colors.primary))
                .frame(width: 300)

            Text("\(Int(manager.scanProgress * 100))%")
                .font(.caption)
                .foregroundColor(Theme.Colors.textSecondary)

            Spacer()
        }
        .padding()
    }

    // MARK: - Results View
    private var resultsView: some View {
        VStack(spacing: 0) {
            // Score Card
            scoreCard
                .padding()

            Divider()

            // Results List
            ScrollView {
                VStack(spacing: 16) {
                    // Findings (if any)
                    if !manager.findings.isEmpty {
                        findingsSection
                    }

                    // Check Results by Category
                    resultsSection
                }
                .padding()
            }

            Divider()

            // Bottom Actions
            HStack {
                Button(action: { manager.performScan() }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Rescan")
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(Theme.Colors.primary)

                Spacer()

                Button(action: exportReport) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Report")
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(Theme.Colors.primary)
            }
            .padding()
            .background(Theme.Colors.cardBackground)
        }
    }

    // MARK: - Score Card
    private var scoreCard: some View {
        HStack(spacing: 24) {
            // Score Circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: CGFloat(manager.overallScore) / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(manager.overallScore)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("/100")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(manager.overallStatus)
                    .font(.title2.bold())
                    .foregroundColor(scoreColor)

                Text(statusDescription)
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.textSecondary)

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(okCount) passed")
                        .font(.caption)

                    if warningCount > 0 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("\(warningCount) warnings")
                            .font(.caption)
                    }

                    if issueCount > 0 {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("\(issueCount) issues")
                            .font(.caption)
                    }
                }
                .foregroundColor(Theme.Colors.textSecondary)
            }

            Spacer()

            // Quick Info
            VStack(alignment: .trailing, spacing: 4) {
                if !manager.hardwareProfile.modelName.isEmpty {
                    Text(manager.hardwareProfile.modelName)
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                if !manager.hardwareProfile.chipType.isEmpty {
                    Text(manager.hardwareProfile.chipType)
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                Text("macOS \(manager.hardwareProfile.osVersion)")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .padding()
        .background(Theme.Colors.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Findings Section
    private var findingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Findings")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            ForEach(manager.findings) { finding in
                FindingCard(finding: finding)
            }
        }
    }

    // MARK: - Results Section
    private var resultsSection: some View {
        let categories = Dictionary(grouping: manager.checkResults) { $0.category }

        return ForEach(categories.keys.sorted(), id: \.self) { category in
            VStack(alignment: .leading, spacing: 8) {
                Text(category)
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.top, 8)

                VStack(spacing: 4) {
                    ForEach(categories[category] ?? []) { result in
                        ResultRow(result: result)
                    }
                }
                .padding()
                .background(Theme.Colors.cardBackground)
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Computed Properties
    private var scoreColor: Color {
        if manager.overallScore >= 90 { return .green }
        else if manager.overallScore >= 75 { return .yellow }
        else if manager.overallScore >= 50 { return .orange }
        else { return .red }
    }

    private var statusDescription: String {
        if manager.overallScore >= 90 {
            return "Your Mac's hardware appears to be in original condition."
        } else if manager.overallScore >= 75 {
            return "Minor concerns detected. Review the findings below."
        } else if manager.overallScore >= 50 {
            return "Some issues detected that may need attention."
        } else {
            return "Significant issues detected. Review recommended."
        }
    }

    private var okCount: Int {
        manager.checkResults.filter { $0.status == .ok }.count
    }

    private var warningCount: Int {
        manager.checkResults.filter { $0.status == .warning }.count
    }

    private var issueCount: Int {
        manager.checkResults.filter { $0.status == .issue }.count
    }

    // MARK: - Actions
    private func exportReport() {
        if let url = manager.exportReport() {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Theme.Colors.primary)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }
}

// MARK: - Finding Card
struct FindingCard: View {
    let finding: IntegrityFinding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: severityIcon)
                    .foregroundColor(severityColor)
                Text(finding.title)
                    .font(.subheadline.bold())
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            Text(finding.description)
                .font(.caption)
                .foregroundColor(Theme.Colors.textSecondary)

            if let rec = finding.recommendation {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text(rec)
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(severityColor.opacity(0.1))
        .cornerRadius(8)
    }

    private var severityIcon: String {
        switch finding.severity {
        case .critical: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var severityColor: Color {
        switch finding.severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

// MARK: - Result Row
struct ResultRow: View {
    let result: HardwareCheckResult

    var body: some View {
        HStack {
            Image(systemName: result.status.icon)
                .foregroundColor(statusColor)
                .frame(width: 20)

            Text(result.item)
                .font(.subheadline)
                .foregroundColor(Theme.Colors.textPrimary)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(result.value)
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(Theme.Colors.textSecondary)

                if let detail = result.detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundColor(Theme.Colors.textSecondary.opacity(0.7))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch result.status {
        case .ok: return .green
        case .warning: return .orange
        case .issue: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Preview
#Preview {
    HardwareIntegrityView(
        manager: HardwareIntegrityManager(),
        isPresented: .constant(true)
    )
}
