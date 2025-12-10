import SwiftUI

// MARK: - Line Chart with Gradient Fill
struct LineChart: View {
    let dataSeries: [ChartDataSeries]
    let showGrid: Bool
    let showLegend: Bool
    let height: CGFloat

    struct ChartDataSeries: Identifiable {
        let id = UUID()
        let name: String
        let data: [Double]
        let color: Color
    }

    init(
        dataSeries: [ChartDataSeries],
        showGrid: Bool = true,
        showLegend: Bool = true,
        height: CGFloat = 150
    ) {
        self.dataSeries = dataSeries
        self.showGrid = showGrid
        self.showLegend = showLegend
        self.height = height
    }

    private var maxValue: Double {
        dataSeries.flatMap { $0.data }.max() ?? 100
    }

    private var minValue: Double {
        0 // Always start from 0 for percentage charts
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Chart area
            GeometryReader { geometry in
                ZStack {
                    // Grid lines
                    if showGrid {
                        GridLines(width: geometry.size.width, height: geometry.size.height)
                    }

                    // Data series
                    ForEach(dataSeries) { series in
                        ChartLine(
                            data: series.data,
                            color: series.color,
                            width: geometry.size.width,
                            height: geometry.size.height,
                            maxValue: maxValue
                        )
                    }
                }
            }
            .frame(height: height)
            .background(Theme.Colors.cardBorder.opacity(0.3))
            .cornerRadius(Theme.Radius.medium)

            // Legend
            if showLegend && dataSeries.count > 1 {
                HStack(spacing: Theme.Spacing.lg) {
                    ForEach(dataSeries) { series in
                        HStack(spacing: Theme.Spacing.xxs) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(series.color)
                                .frame(width: 16, height: 3)
                            Text(series.name)
                                .font(Theme.Typography.footnote)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Chart Line (Individual Series)
struct ChartLine: View {
    let data: [Double]
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let maxValue: Double

    @State private var animationProgress: CGFloat = 0

    var body: some View {
        ZStack {
            // Gradient fill
            Path { path in
                guard data.count > 1 else { return }

                let stepX = width / CGFloat(data.count - 1)
                path.move(to: CGPoint(x: 0, y: height))

                for (index, value) in data.enumerated() {
                    let x = stepX * CGFloat(index)
                    let normalizedValue = maxValue > 0 ? min(value / maxValue, 1.0) : 0
                    let y = height * (1 - normalizedValue)
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                path.addLine(to: CGPoint(x: width, y: height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [color.opacity(0.4), color.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Line
            Path { path in
                guard data.count > 1 else { return }

                let stepX = width / CGFloat(data.count - 1)

                for (index, value) in data.enumerated() {
                    let x = stepX * CGFloat(index)
                    let normalizedValue = maxValue > 0 ? min(value / maxValue, 1.0) : 0
                    let y = height * (1 - normalizedValue)

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .trim(from: 0, to: animationProgress)
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .shadow(color: color.opacity(0.5), radius: 3, x: 0, y: 0)

            // End point
            if let lastValue = data.last, animationProgress >= 1.0 {
                let normalizedValue = maxValue > 0 ? min(lastValue / maxValue, 1.0) : 0
                let y = height * (1 - normalizedValue)

                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .position(x: width, y: y)
                    .shadow(color: color.opacity(0.6), radius: 4, x: 0, y: 0)
            }
        }
        .onAppear {
            animationProgress = 1.0
        }
    }
}

// MARK: - Grid Lines
struct GridLines: View {
    let width: CGFloat
    let height: CGFloat
    let horizontalLines: Int = 4
    let verticalLines: Int = 6

    var body: some View {
        ZStack {
            // Horizontal lines
            ForEach(0..<horizontalLines, id: \.self) { i in
                let y = height * CGFloat(i) / CGFloat(horizontalLines)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
                .stroke(Theme.Colors.cardBorder.opacity(0.5), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
            }

            // Vertical lines
            ForEach(0..<verticalLines, id: \.self) { i in
                let x = width * CGFloat(i) / CGFloat(verticalLines)
                Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
                .stroke(Theme.Colors.cardBorder.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
            }
        }
    }
}

// MARK: - Area Chart (Single Series with Labels)
struct AreaChart: View {
    let title: String
    let data: [Double]
    let color: Color
    let height: CGFloat
    let showLabels: Bool

    @State private var selectedIndex: Int? = nil
    @State private var animationProgress: CGFloat = 0

    init(
        title: String,
        data: [Double],
        color: Color,
        height: CGFloat = 120,
        showLabels: Bool = true
    ) {
        self.title = title
        self.data = data
        self.color = color
        self.height = height
        self.showLabels = showLabels
    }

    private var maxValue: Double {
        max(data.max() ?? 100, 100) // At least 100 for percentage charts
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // Header with current value
            HStack {
                Text(title)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)

                Spacer()

                if let last = data.last {
                    Text(String(format: "%.1f%%", last))
                        .font(Theme.Typography.mono)
                        .foregroundColor(color)
                }
            }

            // Chart
            GeometryReader { geometry in
                ZStack {
                    // Gradient fill
                    Path { path in
                        guard data.count > 1 else { return }

                        let stepX = geometry.size.width / CGFloat(data.count - 1)
                        path.move(to: CGPoint(x: 0, y: geometry.size.height))

                        for (index, value) in data.enumerated() {
                            let x = stepX * CGFloat(index)
                            let normalizedValue = min(value / maxValue, 1.0)
                            let y = geometry.size.height * (1 - normalizedValue)
                            path.addLine(to: CGPoint(x: x, y: y))
                        }

                        path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.5), color.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Line
                    Path { path in
                        guard data.count > 1 else { return }

                        let stepX = geometry.size.width / CGFloat(data.count - 1)

                        for (index, value) in data.enumerated() {
                            let x = stepX * CGFloat(index)
                            let normalizedValue = min(value / maxValue, 1.0)
                            let y = geometry.size.height * (1 - normalizedValue)

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .trim(from: 0, to: animationProgress)
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .shadow(color: color.opacity(0.5), radius: 2, x: 0, y: 0)
                }
            }
            .frame(height: height)
            .background(Theme.Colors.cardBorder.opacity(0.2))
            .cornerRadius(Theme.Radius.small)

            // Labels
            if showLabels && data.count > 0 {
                HStack {
                    Text("60m ago")
                        .font(Theme.Typography.footnote)
                        .foregroundColor(Theme.Colors.textMuted)
                    Spacer()
                    Text("Now")
                        .font(Theme.Typography.footnote)
                        .foregroundColor(Theme.Colors.textMuted)
                }
            }
        }
        .onAppear {
            animationProgress = 1.0
        }
    }
}

// MARK: - Network Activity Chart
struct NetworkChart: View {
    let downloadData: [Double]
    let uploadData: [Double]
    let height: CGFloat

    @State private var animationProgress: CGFloat = 0

    init(downloadData: [Double], uploadData: [Double], height: CGFloat = 100) {
        self.downloadData = downloadData
        self.uploadData = uploadData
        self.height = height
    }

    private var maxValue: Double {
        max(downloadData.max() ?? 0, uploadData.max() ?? 0, 1)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            // Header
            HStack {
                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.Colors.success)
                    Text(formatSpeed(downloadData.last ?? 0))
                        .font(Theme.Typography.mono)
                        .foregroundColor(Theme.Colors.success)
                }

                Spacer()

                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.Colors.info)
                    Text(formatSpeed(uploadData.last ?? 0))
                        .font(Theme.Typography.mono)
                        .foregroundColor(Theme.Colors.info)
                }
            }

            // Chart
            GeometryReader { geometry in
                ZStack {
                    // Download area
                    NetworkAreaPath(
                        data: downloadData,
                        color: Theme.Colors.success,
                        width: geometry.size.width,
                        height: geometry.size.height,
                        maxValue: maxValue,
                        animationProgress: animationProgress
                    )

                    // Upload area (inverted from bottom)
                    NetworkAreaPath(
                        data: uploadData,
                        color: Theme.Colors.info,
                        width: geometry.size.width,
                        height: geometry.size.height,
                        maxValue: maxValue,
                        animationProgress: animationProgress,
                        inverted: true
                    )
                }
            }
            .frame(height: height)
            .background(Theme.Colors.cardBorder.opacity(0.2))
            .cornerRadius(Theme.Radius.small)

            // Legend
            HStack(spacing: Theme.Spacing.lg) {
                HStack(spacing: Theme.Spacing.xxs) {
                    Circle()
                        .fill(Theme.Colors.success)
                        .frame(width: 8, height: 8)
                    Text("Download")
                        .font(Theme.Typography.footnote)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                HStack(spacing: Theme.Spacing.xxs) {
                    Circle()
                        .fill(Theme.Colors.info)
                        .frame(width: 8, height: 8)
                    Text("Upload")
                        .font(Theme.Typography.footnote)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
        .onAppear {
            animationProgress = 1.0
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
}

// MARK: - Network Area Path
struct NetworkAreaPath: View {
    let data: [Double]
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let maxValue: Double
    let animationProgress: CGFloat
    var inverted: Bool = false

    var body: some View {
        ZStack {
            // Fill
            Path { path in
                guard data.count > 1 else { return }

                let stepX = width / CGFloat(data.count - 1)
                let midY = height / 2

                if inverted {
                    path.move(to: CGPoint(x: 0, y: midY))
                } else {
                    path.move(to: CGPoint(x: 0, y: midY))
                }

                for (index, value) in data.enumerated() {
                    let x = stepX * CGFloat(index)
                    let normalizedValue = maxValue > 0 ? min(value / maxValue, 1.0) : 0
                    let yOffset = (height / 2) * normalizedValue

                    let y = inverted ? midY + yOffset : midY - yOffset
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                path.addLine(to: CGPoint(x: width, y: midY))
                path.closeSubpath()
            }
            .fill(color.opacity(0.3))

            // Line
            Path { path in
                guard data.count > 1 else { return }

                let stepX = width / CGFloat(data.count - 1)
                let midY = height / 2

                for (index, value) in data.enumerated() {
                    let x = stepX * CGFloat(index)
                    let normalizedValue = maxValue > 0 ? min(value / maxValue, 1.0) : 0
                    let yOffset = (height / 2) * normalizedValue
                    let y = inverted ? midY + yOffset : midY - yOffset

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .trim(from: 0, to: animationProgress)
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }
}

// MARK: - Disk Usage Chart (Donut)
struct DiskDonutChart: View {
    let used: Double
    let total: Double
    let segments: [(label: String, value: Double, color: Color)]
    let size: CGFloat

    @State private var animationProgress: Double = 0

    init(
        used: Double,
        total: Double,
        segments: [(label: String, value: Double, color: Color)] = [],
        size: CGFloat = 100
    ) {
        self.used = used
        self.total = total
        self.segments = segments
        self.size = size
    }

    private var usedPercentage: Double {
        total > 0 ? (used / total) * 100 : 0
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Theme.Colors.cardBorder, lineWidth: size * 0.15)

            // Used segment
            Circle()
                .trim(from: 0, to: animationProgress * (used / total))
                .stroke(
                    Theme.Colors.statusGradient(for: usedPercentage),
                    style: StrokeStyle(lineWidth: size * 0.15, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.Colors.statusColor(for: usedPercentage).opacity(0.4), radius: 4, x: 0, y: 0)

            // Center text
            VStack(spacing: 2) {
                Text(formatBytes(UInt64(used)))
                    .font(.system(size: size * 0.16, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("of \(formatBytes(UInt64(total)))")
                    .font(.system(size: size * 0.1, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            animationProgress = 1.0
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.0f GB", gb)
        } else {
            let mb = Double(bytes) / 1_048_576
            return String(format: "%.0f MB", mb)
        }
    }
}

// MARK: - Previews
#Preview("Charts") {
    ScrollView {
        VStack(spacing: 30) {
            LineChart(
                dataSeries: [
                    LineChart.ChartDataSeries(name: "CPU", data: [30, 45, 40, 60, 55, 70, 65, 80, 75, 50, 45, 55], color: Theme.Colors.chartCPU),
                    LineChart.ChartDataSeries(name: "Memory", data: [50, 52, 55, 60, 58, 62, 65, 68, 70, 72, 68, 65], color: Theme.Colors.chartMemory)
                ],
                height: 150
            )

            AreaChart(
                title: "CPU Usage",
                data: [30, 45, 40, 60, 55, 70, 65, 80, 75, 50, 45, 55],
                color: Theme.Colors.chartCPU
            )

            NetworkChart(
                downloadData: [500000, 800000, 1200000, 900000, 1500000, 2000000, 1800000, 2500000],
                uploadData: [100000, 150000, 200000, 180000, 250000, 300000, 280000, 350000]
            )

            DiskDonutChart(
                used: 374_700_000_000,
                total: 926_400_000_000,
                size: 120
            )
        }
        .padding(30)
    }
    .background(Theme.Colors.background)
}
