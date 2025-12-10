import SwiftUI

// MARK: - Dashboard Card
struct DashboardCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: Content
    @State private var isHovered = false

    init(
        title: String,
        icon: String,
        iconColor: Color = Theme.Colors.primary,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
                    .glowEffect(color: iconColor.opacity(0.5), radius: 3)

                Text(title)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)

                Spacer()
            }

            // Content
            content
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.Radius.large)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.large)
                .stroke(
                    isHovered ? iconColor.opacity(0.3) : Theme.Colors.cardBorder,
                    lineWidth: 1
                )
        )
        .shadow(color: isHovered ? iconColor.opacity(0.15) : Theme.Shadows.card, radius: isHovered ? 12 : 6, x: 0, y: isHovered ? 4 : 2)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(Theme.Animation.fast, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Stat Card (for big numbers)
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let trend: Trend?
    @State private var isHovered = false
    @State private var animatedValue: Double = 0

    enum Trend {
        case up, down, stable

        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .stable: return "arrow.right"
            }
        }

        var color: Color {
            switch self {
            case .up: return Theme.Colors.critical
            case .down: return Theme.Colors.success
            case .stable: return Theme.Colors.textSecondary
            }
        }
    }

    init(title: String, value: String, subtitle: String, icon: String, color: Color, trend: Trend? = nil) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.trend = trend
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // Header with icon
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(color)

                Text(title)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)

                Spacer()

                if let trend = trend {
                    Image(systemName: trend.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(trend.color)
                }
            }

            // Big value
            Text(value)
                .font(Theme.Typography.statLarge)
                .foregroundColor(Theme.Colors.textPrimary)
                .contentTransition(.numericText())

            // Subtitle
            Text(subtitle)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.Radius.large)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.large)
                .stroke(isHovered ? color.opacity(0.3) : Theme.Colors.cardBorder, lineWidth: 1)
        )
        .shadow(color: Theme.Shadows.card, radius: 6, x: 0, y: 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(Theme.Animation.fast, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Mini Card
struct MiniCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.15))
                .cornerRadius(Theme.Radius.small)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                Text(value)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            Spacer()
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.cardBackground.opacity(0.5))
        .cornerRadius(Theme.Radius.medium)
    }
}

// MARK: - Process Row
struct ProcessRow: View {
    let rank: Int
    let name: String
    let cpu: Double
    let memory: String
    let pid: Int32
    let onKill: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Rank
            Text("\(rank)")
                .font(Theme.Typography.mono)
                .foregroundColor(Theme.Colors.textMuted)
                .frame(width: 20)

            // Name
            Text(name)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // CPU
            Text(String(format: "%.1f%%", cpu))
                .font(Theme.Typography.mono)
                .foregroundColor(Theme.Colors.chartCPU)
                .frame(width: 50, alignment: .trailing)

            // Memory
            Text(memory)
                .font(Theme.Typography.mono)
                .foregroundColor(Theme.Colors.chartMemory)
                .frame(width: 60, alignment: .trailing)

            // Kill button
            Button(action: onKill) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isHovered ? Theme.Colors.critical : Theme.Colors.textMuted)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.5)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(isHovered ? Theme.Colors.cardBorder.opacity(0.3) : Color.clear)
        .cornerRadius(Theme.Radius.small)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false

    init(title: String, icon: String, color: Color = Theme.Colors.primary, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .progressViewStyle(CircularProgressViewStyle(tint: color))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                }
                Text(title)
                    .font(Theme.Typography.caption)
            }
            .foregroundColor(isHovered ? Theme.Colors.background : color)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(
                Group {
                    if isHovered {
                        color
                    } else {
                        color.opacity(0.15)
                    }
                }
            )
            .cornerRadius(Theme.Radius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(Theme.Animation.fast, value: isHovered)
        .animation(Theme.Animation.fast, value: isPressed)
        .onHover { hovering in
            isHovered = hovering
        }
        .disabled(isLoading)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)

            Text(title)
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.textPrimary)

            Spacer()
        }
    }
}

// MARK: - Animated Number
struct AnimatedNumber: View {
    let value: Double
    let format: String
    let color: Color

    @State private var displayValue: Double = 0

    var body: some View {
        Text(String(format: format, displayValue))
            .font(Theme.Typography.statLarge)
            .foregroundColor(color)
            .contentTransition(.numericText())
            .onChange(of: value) { _, newValue in
                displayValue = newValue
            }
            .onAppear {
                displayValue = value
            }
    }
}

// MARK: - Previews
#Preview {
    VStack(spacing: 20) {
        DashboardCard(title: "CPU Usage", icon: "cpu", iconColor: Theme.Colors.chartCPU) {
            Text("45%")
                .font(Theme.Typography.statLarge)
                .foregroundColor(Theme.Colors.textPrimary)
        }

        StatCard(
            title: "CPU",
            value: "45%",
            subtitle: "10 cores • 3.2 GHz",
            icon: "cpu",
            color: Theme.Colors.chartCPU,
            trend: .up
        )

        ActionButton(title: "Clean Cache", icon: "trash", color: Theme.Colors.primary) {
            print("Cleaning...")
        }
    }
    .padding()
    .background(Theme.Colors.background)
}
