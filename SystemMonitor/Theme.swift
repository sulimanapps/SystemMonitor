import SwiftUI

// MARK: - NOC Dashboard Theme
struct Theme {
    // MARK: - Colors
    struct Colors {
        // Background colors
        static let background = Color(hex: "0D0D0D")
        static let cardBackground = Color(hex: "1A1A1A")
        static let cardBorder = Color(hex: "2A2A2A")
        static let headerBackground = Color(hex: "111111")

        // Accent colors
        static let primary = Color(hex: "00FF88")      // Neon green
        static let secondary = Color(hex: "00D4FF")    // Cyan blue
        static let tertiary = Color(hex: "A855F7")     // Purple

        // Status colors
        static let success = Color(hex: "00FF88")
        static let warning = Color(hex: "FFB800")
        static let critical = Color(hex: "FF4757")
        static let info = Color(hex: "00D4FF")

        // Text colors
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "888888")
        static let textMuted = Color(hex: "555555")

        // Chart colors
        static let chartCPU = Color(hex: "00D4FF")
        static let chartMemory = Color(hex: "A855F7")
        static let chartDisk = Color(hex: "00FF88")
        static let chartNetwork = Color(hex: "FFB800")

        // Gradients
        static let primaryGradient = LinearGradient(
            colors: [Color(hex: "00FF88"), Color(hex: "00D4FF")],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let cpuGradient = LinearGradient(
            colors: [Color(hex: "00D4FF"), Color(hex: "0099CC")],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let memoryGradient = LinearGradient(
            colors: [Color(hex: "A855F7"), Color(hex: "7C3AED")],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let diskGradient = LinearGradient(
            colors: [Color(hex: "00FF88"), Color(hex: "00CC6A")],
            startPoint: .leading,
            endPoint: .trailing
        )

        // Status gradient for gauge
        static func statusGradient(for value: Double) -> LinearGradient {
            if value >= 85 {
                return LinearGradient(colors: [Color(hex: "FF4757"), Color(hex: "FF6B7A")], startPoint: .leading, endPoint: .trailing)
            } else if value >= 70 {
                return LinearGradient(colors: [Color(hex: "FFB800"), Color(hex: "FFC933")], startPoint: .leading, endPoint: .trailing)
            } else {
                return LinearGradient(colors: [Color(hex: "00FF88"), Color(hex: "00D4FF")], startPoint: .leading, endPoint: .trailing)
            }
        }

        static func statusColor(for value: Double) -> Color {
            if value >= 85 { return critical }
            else if value >= 70 { return warning }
            else { return success }
        }
    }

    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.system(size: 28, weight: .bold, design: .default)
        static let title = Font.system(size: 18, weight: .semibold, design: .default)
        static let headline = Font.system(size: 16, weight: .semibold, design: .default)
        static let body = Font.system(size: 14, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let footnote = Font.system(size: 10, weight: .regular, design: .default)

        // Stats typography
        static let statLarge = Font.system(size: 32, weight: .bold, design: .rounded)
        static let statMedium = Font.system(size: 24, weight: .bold, design: .rounded)
        static let statSmall = Font.system(size: 18, weight: .semibold, design: .rounded)

        // Monospace for data
        static let mono = Font.system(size: 12, weight: .medium, design: .monospaced)
        static let monoSmall = Font.system(size: 10, weight: .medium, design: .monospaced)
    }

    // MARK: - Spacing
    struct Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Corner Radius
    struct Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 12
        static let xlarge: CGFloat = 16
    }

    // MARK: - Shadows
    struct Shadows {
        static let card = Color.black.opacity(0.3)
        static let glow = Color(hex: "00FF88").opacity(0.3)
        static let glowWarning = Color(hex: "FFB800").opacity(0.3)
        static let glowCritical = Color(hex: "FF4757").opacity(0.3)
    }

    // MARK: - Animation
    struct Animation {
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let normal = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.7)
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers
struct CardStyle: ViewModifier {
    var isHovered: Bool = false

    func body(content: Content) -> some View {
        content
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.Radius.large)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.large)
                    .stroke(Theme.Colors.cardBorder, lineWidth: 1)
            )
            .shadow(color: Theme.Shadows.card, radius: isHovered ? 12 : 6, x: 0, y: isHovered ? 6 : 3)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(Theme.Animation.fast, value: isHovered)
    }
}

struct GlowEffect: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color, radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(0.5), radius: radius * 2, x: 0, y: 0)
    }
}

extension View {
    func cardStyle(isHovered: Bool = false) -> some View {
        modifier(CardStyle(isHovered: isHovered))
    }

    func glowEffect(color: Color = Theme.Colors.primary, radius: CGFloat = 4) -> some View {
        modifier(GlowEffect(color: color, radius: radius))
    }
}

// MARK: - Settings Manager
import ServiceManagement

class SettingsManager: ObservableObject {
    @Published var refreshRate: Double = 2.0
    @Published var startAtLogin: Bool = false {
        didSet {
            updateLoginItem()
        }
    }
    @Published var cpuAlertThreshold: Double = 85
    @Published var memoryAlertThreshold: Double = 85
    @Published var diskAlertThreshold: Double = 90
    @Published var theme: AppTheme = .dark
    @Published var showInDock: Bool = false

    enum AppTheme: String, CaseIterable {
        case dark = "Dark"
        case darker = "Darker"
        case oledBlack = "OLED Black"

        var backgroundColor: Color {
            switch self {
            case .dark: return Color(hex: "0D0D0D")
            case .darker: return Color(hex: "080808")
            case .oledBlack: return Color.black
            }
        }
    }

    init() {
        loadSettings()
        syncLoginStatus()
    }

    // Sync startAtLogin with actual SMAppService status
    func syncLoginStatus() {
        let actualStatus = SMAppService.mainApp.status == .enabled
        if startAtLogin != actualStatus {
            // Update without triggering didSet to avoid loop
            UserDefaults.standard.set(actualStatus, forKey: "startAtLogin")
            startAtLogin = actualStatus
        }
    }

    func loadSettings() {
        if let rate = UserDefaults.standard.object(forKey: "refreshRate") as? Double {
            refreshRate = rate
        }
        // Check actual SMAppService status instead of UserDefaults
        startAtLogin = SMAppService.mainApp.status == .enabled
        if let cpu = UserDefaults.standard.object(forKey: "cpuAlertThreshold") as? Double {
            cpuAlertThreshold = cpu
        }
        if let mem = UserDefaults.standard.object(forKey: "memoryAlertThreshold") as? Double {
            memoryAlertThreshold = mem
        }
        if let disk = UserDefaults.standard.object(forKey: "diskAlertThreshold") as? Double {
            diskAlertThreshold = disk
        }
        if let themeRaw = UserDefaults.standard.string(forKey: "theme"),
           let theme = AppTheme(rawValue: themeRaw) {
            self.theme = theme
        }
    }

    func saveSettings() {
        UserDefaults.standard.set(refreshRate, forKey: "refreshRate")
        UserDefaults.standard.set(startAtLogin, forKey: "startAtLogin")
        UserDefaults.standard.set(cpuAlertThreshold, forKey: "cpuAlertThreshold")
        UserDefaults.standard.set(memoryAlertThreshold, forKey: "memoryAlertThreshold")
        UserDefaults.standard.set(diskAlertThreshold, forKey: "diskAlertThreshold")
        UserDefaults.standard.set(theme.rawValue, forKey: "theme")
    }

    private func updateLoginItem() {
        if #available(macOS 13.0, *) {
            do {
                if startAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update login item: \(error)")
            }
        }
    }
}
