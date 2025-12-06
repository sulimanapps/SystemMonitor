import SwiftUI
import AppKit

class StatusBarController: ObservableObject {
    private var statusItem: NSStatusItem
    private var cleanupWindow: NSWindow?
    private var feedbackWindow: NSWindow?
    private var timer: Timer?
    private var historyTimer: Timer?
    private let systemMonitor = SystemMonitor()
    private let cacheManager = CacheManager()
    private let featureManager = FeatureManager()
    private let feedbackManager = FeedbackManager()
    private let appManager = AppManager()
    private let settings = SettingsManager()
    private var dashboardController: DashboardWindowController?
    private var settingsObserver: NSObjectProtocol?
    private var currentRefreshRate: Double = 2.0
    @Published var showCleanupSheet: Bool = false

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Create dashboard controller
        dashboardController = DashboardWindowController(
            systemMonitor: systemMonitor,
            featureManager: featureManager,
            cacheManager: cacheManager,
            appManager: appManager,
            settings: settings
        )

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "System Monitor Pro")
            button.image?.isTemplate = false
            updateStatusIcon()
            button.action = #selector(toggleDashboard)
            button.target = self
        }

        currentRefreshRate = settings.refreshRate
        startMonitoring()

        // Observe settings changes to update timer
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restartMonitoringIfNeeded()
        }
    }

    private func restartMonitoringIfNeeded() {
        settings.loadSettings()
        let newRate = settings.refreshRate
        if newRate != currentRefreshRate {
            currentRefreshRate = newRate
            timer?.invalidate()
            startMainTimer()
        }
    }

    @objc func toggleDashboard() {
        dashboardController?.toggleWindow()
    }

    private func startMonitoring() {
        startMainTimer()

        // Separate timer for usage history (every 60 seconds)
        historyTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.featureManager.recordUsagePoint(
                cpuUsage: self.systemMonitor.cpuUsage,
                memoryUsage: self.systemMonitor.memoryUsage
            )
        }

        // Record initial point
        featureManager.recordUsagePoint(
            cpuUsage: systemMonitor.cpuUsage,
            memoryUsage: systemMonitor.memoryUsage
        )
    }

    private func startMainTimer() {
        // Use settings refresh rate
        let interval = currentRefreshRate

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Run heavy operations on background thread
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self = self else { return }

                self.systemMonitor.updateStats()
                self.featureManager.updateNetworkStats()
                self.featureManager.updateBatteryInfo()
                self.featureManager.updateTemperatures()

                // Check for alerts
                self.featureManager.checkForAlerts(
                    cpuUsage: self.systemMonitor.cpuUsage,
                    memoryUsage: self.systemMonitor.memoryUsage,
                    diskUsage: self.systemMonitor.diskUsage
                )

                DispatchQueue.main.async { [weak self] in
                    self?.updateStatusIcon()
                }
            }
        }
        timer?.fire()
    }

    private func updateStatusIcon() {
        guard let button = statusItem.button else { return }

        let maxUsage = max(systemMonitor.cpuUsage, systemMonitor.memoryUsage, systemMonitor.diskUsage)
        let color: NSColor

        if maxUsage >= 85 {
            color = NSColor(red: 1.0, green: 0.28, blue: 0.34, alpha: 1.0) // #FF4757
        } else if maxUsage >= 70 {
            color = NSColor(red: 1.0, green: 0.72, blue: 0.0, alpha: 1.0) // #FFB800
        } else {
            color = NSColor(red: 0.0, green: 1.0, blue: 0.53, alpha: 1.0) // #00FF88
        }

        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        if let image = NSImage(systemSymbolName: "cpu", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) {
            let coloredImage = image.tinted(with: color)
            button.image = coloredImage
        }
    }

    private func showCleanupWindow() {
        // Create cleanup window if needed
        if cleanupWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 480),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Storage Cleanup"
            window.center()
            window.isReleasedWhenClosed = false
            cleanupWindow = window
        }

        cacheManager.cleaningComplete = false
        cacheManager.cleaningProgress = 0

        let cleanupView = CacheCleanupView(
            cacheManager: cacheManager,
            isPresented: Binding(
                get: { [weak self] in self?.cleanupWindow?.isVisible ?? false },
                set: { [weak self] newValue in
                    if !newValue {
                        self?.cleanupWindow?.close()
                        self?.systemMonitor.updateStats()
                    }
                }
            )
        )

        cleanupWindow?.contentViewController = NSHostingController(rootView: cleanupView)
        cleanupWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showFeedbackWindow() {
        // Create feedback window if needed
        if feedbackWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 450),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Report Bug"
            window.center()
            window.isReleasedWhenClosed = false
            feedbackWindow = window
        }

        feedbackManager.reset()

        let feedbackView = FeedbackView(
            feedbackManager: feedbackManager,
            isPresented: Binding(
                get: { [weak self] in self?.feedbackWindow?.isVisible ?? false },
                set: { [weak self] newValue in
                    if !newValue {
                        self?.feedbackWindow?.close()
                    }
                }
            )
        )

        feedbackWindow?.contentViewController = NSHostingController(rootView: feedbackView)
        feedbackWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    deinit {
        timer?.invalidate()
        historyTimer?.invalidate()
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()
        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
