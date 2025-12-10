import SwiftUI

// MARK: - Circular Gauge
struct CircularGauge: View {
    let value: Double // 0-100
    let maxValue: Double
    let title: String
    let subtitle: String
    let color: Color
    let size: CGFloat

    @State private var animatedValue: Double = 0

    init(value: Double, maxValue: Double = 100, title: String, subtitle: String, color: Color, size: CGFloat = 100) {
        self.value = value
        self.maxValue = maxValue
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.size = size
    }

    private var progress: Double {
        min(animatedValue / maxValue, 1.0)
    }

    private var statusColor: Color {
        Theme.Colors.statusColor(for: value)
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Theme.Colors.cardBorder, lineWidth: size * 0.08)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [color.opacity(0.5), color]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * progress)
                    ),
                    style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.4), radius: 4, x: 0, y: 0)

            // Center content
            VStack(spacing: 2) {
                Text(String(format: "%.0f", animatedValue))
                    .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .contentTransition(.numericText())

                Text("%")
                    .font(.system(size: size * 0.12, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .onChange(of: value) { _, newValue in
            animatedValue = newValue
        }
        .onAppear {
            animatedValue = value
        }
    }
}

// MARK: - Arc Gauge (180 degree)
struct ArcGauge: View {
    let value: Double
    let maxValue: Double
    let title: String
    let unit: String
    let color: Color
    let size: CGFloat

    @State private var animatedValue: Double = 0

    init(value: Double, maxValue: Double = 100, title: String, unit: String = "%", color: Color, size: CGFloat = 120) {
        self.value = value
        self.maxValue = maxValue
        self.title = title
        self.unit = unit
        self.color = color
        self.size = size
    }

    private var progress: Double {
        min(animatedValue / maxValue, 1.0)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            ZStack {
                // Background arc
                ArcShape(startAngle: 135, endAngle: 405)
                    .stroke(Theme.Colors.cardBorder, lineWidth: size * 0.1)

                // Progress arc
                ArcShape(startAngle: 135, endAngle: 135 + (270 * progress))
                    .stroke(
                        LinearGradient(
                            colors: [color.opacity(0.6), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round)
                    )
                    .shadow(color: color.opacity(0.5), radius: 6, x: 0, y: 0)

                // Value text
                VStack(spacing: 0) {
                    Spacer()
                    Text(String(format: "%.0f", animatedValue))
                        .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .contentTransition(.numericText())

                    Text(unit)
                        .font(.system(size: size * 0.1, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .frame(height: size * 0.7)
            }
            .frame(width: size, height: size * 0.6)

            // Title
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .onChange(of: value) { _, newValue in
            animatedValue = newValue
        }
        .onAppear {
            animatedValue = value
        }
    }
}

// MARK: - Arc Shape
struct ArcShape: Shape {
    let startAngle: Double
    let endAngle: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )

        return path
    }
}

// MARK: - Linear Progress Bar
struct ProgressBar: View {
    let value: Double
    let maxValue: Double
    let color: Color
    let height: CGFloat
    let showLabel: Bool

    @State private var animatedValue: Double = 0

    init(value: Double, maxValue: Double = 100, color: Color, height: CGFloat = 8, showLabel: Bool = false) {
        self.value = value
        self.maxValue = maxValue
        self.color = color
        self.height = height
        self.showLabel = showLabel
    }

    private var progress: Double {
        min(animatedValue / maxValue, 1.0)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(Theme.Colors.cardBorder)

                    // Progress
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.7), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress)
                        .shadow(color: color.opacity(0.4), radius: 3, x: 0, y: 0)
                }
            }
            .frame(height: height)

            if showLabel {
                Text(String(format: "%.1f%%", animatedValue))
                    .font(Theme.Typography.monoSmall)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .onChange(of: value) { _, newValue in
            animatedValue = newValue
        }
        .onAppear {
            animatedValue = value
        }
    }
}

// MARK: - Segmented Progress Bar
struct SegmentedProgressBar: View {
    let segments: [(value: Double, color: Color, label: String)]
    let total: Double
    let height: CGFloat

    init(segments: [(value: Double, color: Color, label: String)], total: Double, height: CGFloat = 12) {
        self.segments = segments
        self.total = total
        self.height = height
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                        let width = (segment.value / total) * geometry.size.width
                        RoundedRectangle(cornerRadius: height / 2)
                            .fill(segment.color)
                            .frame(width: max(width, 0))
                            .shadow(color: segment.color.opacity(0.3), radius: 2, x: 0, y: 0)
                    }

                    Spacer(minLength: 0)
                }
            }
            .frame(height: height)
            .background(Theme.Colors.cardBorder)
            .cornerRadius(height / 2)

            // Legend
            HStack(spacing: Theme.Spacing.md) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    HStack(spacing: Theme.Spacing.xxs) {
                        Circle()
                            .fill(segment.color)
                            .frame(width: 8, height: 8)
                        Text(segment.label)
                            .font(Theme.Typography.footnote)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Temperature Gauge
struct TemperatureGauge: View {
    let value: Double
    let maxValue: Double
    let label: String
    let icon: String

    private var color: Color {
        if value >= 85 { return Theme.Colors.critical }
        else if value >= 70 { return Theme.Colors.warning }
        else if value >= 55 { return Color.yellow }
        else { return Theme.Colors.success }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack {
                    Text(label)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                    Text(String(format: "%.0f°C", value))
                        .font(Theme.Typography.mono)
                        .foregroundColor(color)
                }

                ProgressBar(value: value, maxValue: maxValue, color: color, height: 4)
            }
        }
    }
}

// MARK: - Battery Indicator
struct BatteryIndicator: View {
    let percentage: Int
    let isCharging: Bool
    let isPluggedIn: Bool

    private var color: Color {
        if percentage <= 20 { return Theme.Colors.critical }
        else if percentage <= 40 { return Theme.Colors.warning }
        else { return Theme.Colors.success }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            // Battery icon
            ZStack(alignment: .leading) {
                // Battery outline
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Theme.Colors.textSecondary, lineWidth: 1.5)
                    .frame(width: 28, height: 14)

                // Battery cap
                Rectangle()
                    .fill(Theme.Colors.textSecondary)
                    .frame(width: 2, height: 6)
                    .offset(x: 28)

                // Battery fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: max(CGFloat(percentage) / 100 * 24, 2), height: 10)
                    .offset(x: 2)

                // Charging bolt
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.Colors.background)
                        .offset(x: 10)
                }
            }
            .frame(width: 32)

            // Percentage
            Text("\(percentage)%")
                .font(Theme.Typography.mono)
                .foregroundColor(color)

            // Status
            if isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.warning)
            } else if isPluggedIn {
                Image(systemName: "powerplug.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.success)
            }
        }
    }
}

// MARK: - Previews
#Preview("Gauges") {
    VStack(spacing: 30) {
        HStack(spacing: 30) {
            CircularGauge(value: 45, title: "CPU", subtitle: "10 cores", color: Theme.Colors.chartCPU, size: 100)
            CircularGauge(value: 67, title: "Memory", subtitle: "16GB", color: Theme.Colors.chartMemory, size: 100)
            CircularGauge(value: 89, title: "Disk", subtitle: "500GB", color: Theme.Colors.critical, size: 100)
        }

        HStack(spacing: 30) {
            ArcGauge(value: 52, title: "CPU Temp", unit: "°C", color: Theme.Colors.warning, size: 100)
            ArcGauge(value: 48, title: "GPU Temp", unit: "°C", color: Theme.Colors.success, size: 100)
        }

        ProgressBar(value: 67, color: Theme.Colors.chartMemory, height: 10, showLabel: true)

        SegmentedProgressBar(
            segments: [
                (200, Theme.Colors.chartCPU, "Apps"),
                (150, Theme.Colors.chartMemory, "System"),
                (100, Theme.Colors.chartDisk, "Other")
            ],
            total: 500,
            height: 16
        )

        HStack(spacing: 20) {
            BatteryIndicator(percentage: 85, isCharging: true, isPluggedIn: true)
            BatteryIndicator(percentage: 25, isCharging: false, isPluggedIn: false)
        }
    }
    .padding(30)
    .background(Theme.Colors.background)
}
