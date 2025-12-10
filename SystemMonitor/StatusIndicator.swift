import SwiftUI

// MARK: - Status Dot (Pulsing)
struct StatusDot: View {
    let status: Status
    let size: CGFloat

    enum Status {
        case normal
        case warning
        case critical
        case inactive

        var color: Color {
            switch self {
            case .normal: return Theme.Colors.success
            case .warning: return Theme.Colors.warning
            case .critical: return Theme.Colors.critical
            case .inactive: return Theme.Colors.textMuted
            }
        }

        var shouldPulse: Bool {
            switch self {
            case .normal, .critical: return true
            case .warning, .inactive: return false
            }
        }
    }

    @State private var isPulsing = false

    init(status: Status, size: CGFloat = 8) {
        self.status = status
        self.size = size
    }

    var body: some View {
        ZStack {
            // Glow effect
            if status.shouldPulse {
                Circle()
                    .fill(status.color.opacity(0.3))
                    .frame(width: size * 2.5, height: size * 2.5)
                    .scaleEffect(isPulsing ? 1.2 : 0.8)
                    .opacity(isPulsing ? 0.3 : 0.6)
            }

            // Main dot
            Circle()
                .fill(status.color)
                .frame(width: size, height: size)
                .shadow(color: status.color.opacity(0.6), radius: 4, x: 0, y: 0)
        }
        .onAppear {
            isPulsing = status.shouldPulse
        }
        .onChange(of: status) { _, newStatus in
            isPulsing = newStatus.shouldPulse
        }
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let label: String
    let status: StatusDot.Status

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            StatusDot(status: status, size: 6)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xxs)
        .background(status.color.opacity(0.1))
        .cornerRadius(Theme.Radius.small)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.small)
                .stroke(status.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Alert Banner
struct AlertBanner: View {
    let message: String
    let type: AlertType
    let onDismiss: () -> Void

    @State private var isVisible = false

    enum AlertType {
        case info
        case warning
        case critical

        var color: Color {
            switch self {
            case .info: return Theme.Colors.info
            case .warning: return Theme.Colors.warning
            case .critical: return Theme.Colors.critical
            }
        }

        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .critical: return "xmark.octagon.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: type.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(type.color)

            Text(message)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textPrimary)

            Spacer()

            Button(action: {
                withAnimation(Theme.Animation.fast) {
                    isVisible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.md)
        .background(type.color.opacity(0.15))
        .cornerRadius(Theme.Radius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .stroke(type.color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: type.color.opacity(0.2), radius: 8, x: 0, y: 4)
        .offset(y: isVisible ? 0 : -100)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(Theme.Animation.spring) {
                isVisible = true
            }
            // Auto-dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation(Theme.Animation.fast) {
                    isVisible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
    }
}

// MARK: - Live Update Indicator
struct LiveIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            Circle()
                .fill(Theme.Colors.critical)
                .frame(width: 6, height: 6)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .opacity(isAnimating ? 1.0 : 0.6)

            Text("LIVE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.Colors.critical)
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.vertical, 2)
        .background(Theme.Colors.critical.opacity(0.1))
        .cornerRadius(Theme.Radius.small)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Uptime Display
struct UptimeDisplay: View {
    let uptime: TimeInterval

    private var formattedUptime: String {
        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        let minutes = (Int(uptime) % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: "clock")
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.textMuted)

            Text("Uptime:")
                .font(Theme.Typography.footnote)
                .foregroundColor(Theme.Colors.textMuted)

            Text(formattedUptime)
                .font(Theme.Typography.monoSmall)
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }
}

// MARK: - Network Speed Indicator
struct NetworkSpeedIndicator: View {
    let downloadSpeed: Double // bytes per second
    let uploadSpeed: Double

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

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Download
            HStack(spacing: Theme.Spacing.xxs) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.success)
                Text(formatSpeed(downloadSpeed))
                    .font(Theme.Typography.monoSmall)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            // Upload
            HStack(spacing: Theme.Spacing.xxs) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.info)
                Text(formatSpeed(uploadSpeed))
                    .font(Theme.Typography.monoSmall)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Sparkline (Mini Chart)
struct Sparkline: View {
    let data: [Double]
    let color: Color
    let height: CGFloat

    init(data: [Double], color: Color = Theme.Colors.primary, height: CGFloat = 30) {
        self.data = data
        self.color = color
        self.height = height
    }

    var body: some View {
        GeometryReader { geometry in
            if data.count > 1 {
                let maxVal = data.max() ?? 100
                let minVal = data.min() ?? 0
                let range = max(maxVal - minVal, 1)

                ZStack {
                    // Fill
                    Path { path in
                        let stepX = geometry.size.width / CGFloat(data.count - 1)
                        path.move(to: CGPoint(x: 0, y: geometry.size.height))

                        for (index, value) in data.enumerated() {
                            let x = stepX * CGFloat(index)
                            let normalizedValue = (value - minVal) / range
                            let y = geometry.size.height * (1 - normalizedValue)
                            path.addLine(to: CGPoint(x: x, y: y))
                        }

                        path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Line
                    Path { path in
                        let stepX = geometry.size.width / CGFloat(data.count - 1)

                        for (index, value) in data.enumerated() {
                            let x = stepX * CGFloat(index)
                            let normalizedValue = (value - minVal) / range
                            let y = geometry.size.height * (1 - normalizedValue)

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .shadow(color: color.opacity(0.5), radius: 2, x: 0, y: 0)

                    // End dot
                    if let lastValue = data.last {
                        let normalizedValue = (lastValue - minVal) / range
                        let y = geometry.size.height * (1 - normalizedValue)
                        Circle()
                            .fill(color)
                            .frame(width: 4, height: 4)
                            .position(x: geometry.size.width, y: y)
                            .shadow(color: color.opacity(0.6), radius: 3, x: 0, y: 0)
                    }
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Trend Arrow
struct TrendArrow: View {
    let trend: Double // positive = up, negative = down, 0 = stable

    private var icon: String {
        if trend > 5 { return "arrow.up.right" }
        else if trend < -5 { return "arrow.down.right" }
        else { return "arrow.right" }
    }

    private var color: Color {
        if trend > 5 { return Theme.Colors.critical }
        else if trend < -5 { return Theme.Colors.success }
        else { return Theme.Colors.textMuted }
    }

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(color)
    }
}

// MARK: - Previews
#Preview("Status Dot") {
    HStack(spacing: 30) {
        StatusDot(status: .normal)
        StatusDot(status: .warning)
        StatusDot(status: .critical)
    }
    .padding(30)
    .background(Theme.Colors.background)
}
