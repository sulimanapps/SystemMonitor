import SwiftUI

// MARK: - Settings Panel (Slide-out)
struct SettingsPanel: View {
    @ObservedObject var settings: SettingsManager
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.textPrimary)

                Spacer()

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.headerBackground)

            Divider()
                .background(Theme.Colors.cardBorder)

            // Settings content
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // General Section
                    SettingsSection(title: "General", icon: "gearshape.fill") {
                        // Refresh Rate
                        SettingsRow(
                            title: "Refresh Rate",
                            subtitle: "How often to update metrics",
                            icon: "clock"
                        ) {
                            Picker("", selection: $settings.refreshRate) {
                                Text("1 second").tag(1.0)
                                Text("2 seconds").tag(2.0)
                                Text("5 seconds").tag(5.0)
                            }
                            .pickerStyle(.menu)
                            .frame(width: 120)
                        }

                        Divider()
                            .background(Theme.Colors.cardBorder)

                        // Start at Login
                        SettingsRow(
                            title: "Start at Login",
                            subtitle: "Launch automatically on startup",
                            icon: "play.circle"
                        ) {
                            Toggle("", isOn: $settings.startAtLogin)
                                .toggleStyle(.switch)
                                .tint(Theme.Colors.primary)
                        }
                    }

                    // Alerts Section
                    SettingsSection(title: "Alerts", icon: "bell.fill") {
                        // CPU Alert Threshold
                        SettingsRow(
                            title: "CPU Alert",
                            subtitle: "Alert when CPU exceeds this value",
                            icon: "cpu"
                        ) {
                            HStack(spacing: Theme.Spacing.xs) {
                                Slider(value: $settings.cpuAlertThreshold, in: 50...100, step: 5)
                                    .tint(Theme.Colors.chartCPU)
                                    .frame(width: 100)
                                Text("\(Int(settings.cpuAlertThreshold))%")
                                    .font(Theme.Typography.mono)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .frame(width: 40)
                            }
                        }

                        Divider()
                            .background(Theme.Colors.cardBorder)

                        // Memory Alert Threshold
                        SettingsRow(
                            title: "Memory Alert",
                            subtitle: "Alert when memory exceeds this value",
                            icon: "memorychip"
                        ) {
                            HStack(spacing: Theme.Spacing.xs) {
                                Slider(value: $settings.memoryAlertThreshold, in: 50...100, step: 5)
                                    .tint(Theme.Colors.chartMemory)
                                    .frame(width: 100)
                                Text("\(Int(settings.memoryAlertThreshold))%")
                                    .font(Theme.Typography.mono)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .frame(width: 40)
                            }
                        }

                        Divider()
                            .background(Theme.Colors.cardBorder)

                        // Disk Alert Threshold
                        SettingsRow(
                            title: "Disk Alert",
                            subtitle: "Alert when disk exceeds this value",
                            icon: "internaldrive"
                        ) {
                            HStack(spacing: Theme.Spacing.xs) {
                                Slider(value: $settings.diskAlertThreshold, in: 50...100, step: 5)
                                    .tint(Theme.Colors.chartDisk)
                                    .frame(width: 100)
                                Text("\(Int(settings.diskAlertThreshold))%")
                                    .font(Theme.Typography.mono)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .frame(width: 40)
                            }
                        }
                    }

                    // About Section
                    SettingsSection(title: "About", icon: "info.circle.fill") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            HStack {
                                Image(systemName: "cpu")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(Theme.Colors.primary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("SystemMonitor Pro")
                                        .font(Theme.Typography.headline)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    Text("Version 2.0.0")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                            }

                            Divider()
                                .background(Theme.Colors.cardBorder)

                            Text("A premium system monitoring dashboard for macOS. Monitor CPU, memory, disk, network, battery, and more in real-time.")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Divider()
                                .background(Theme.Colors.cardBorder)

                            HStack(spacing: Theme.Spacing.md) {
                                Button(action: openDocumentation) {
                                    Label("Documentation", systemImage: "book")
                                        .font(Theme.Typography.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(Theme.Colors.info)

                                Button(action: openFeedback) {
                                    Label("Report Bug", systemImage: "ladybug")
                                        .font(Theme.Typography.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(Theme.Colors.warning)
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }

            Divider()
                .background(Theme.Colors.cardBorder)

            // Footer with save button
            HStack {
                Spacer()

                Button(action: {
                    settings.saveSettings()
                    isPresented = false
                }) {
                    Text("Save & Close")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.background)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Theme.Colors.primary)
                        .cornerRadius(Theme.Radius.medium)
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.headerBackground)
        }
        .frame(width: 360)
        .background(Theme.Colors.cardBackground)
    }

    private func openDocumentation() {
        if let url = URL(string: "https://github.com/sulimanapps/SystemMonitor") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openFeedback() {
        if let url = URL(string: "https://github.com/sulimanapps/SystemMonitor/issues/new") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Section header
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.primary)

                Text(title)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(1)
            }

            // Section content
            VStack(spacing: 0) {
                content
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.Colors.background)
            .cornerRadius(Theme.Radius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .stroke(Theme.Colors.cardBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - Settings Row
struct SettingsRow<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.Colors.textSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(subtitle)
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.Colors.textMuted)
            }

            Spacer()

            content
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

// MARK: - Preview
#Preview {
    SettingsPanel(settings: SettingsManager(), isPresented: .constant(true))
        .frame(height: 600)
        .background(Theme.Colors.background)
}
