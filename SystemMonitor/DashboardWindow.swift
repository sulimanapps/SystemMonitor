import SwiftUI
import AppKit

// MARK: - Dashboard Window Controller
class DashboardWindowController: NSObject, ObservableObject {
    private var window: NSWindow?
    private let systemMonitor: SystemMonitor
    private let featureManager: FeatureManager
    private let cacheManager: CacheManager
    private let appManager: AppManager
    private let smartCleanManager: SmartCleanManager
    private let settings: SettingsManager

    init(
        systemMonitor: SystemMonitor,
        featureManager: FeatureManager,
        cacheManager: CacheManager,
        appManager: AppManager,
        smartCleanManager: SmartCleanManager,
        settings: SettingsManager
    ) {
        self.systemMonitor = systemMonitor
        self.featureManager = featureManager
        self.cacheManager = cacheManager
        self.appManager = appManager
        self.smartCleanManager = smartCleanManager
        self.settings = settings
        super.init()
    }

    func toggleWindow() {
        if let window = window, window.isVisible {
            closeWindow()
        } else {
            showWindow()
        }
    }

    func showWindow() {
        if window == nil {
            createWindow()
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Restore saved position if available
        if let positionData = UserDefaults.standard.data(forKey: "dashboardWindowPosition"),
           let position = try? JSONDecoder().decode(WindowPosition.self, from: positionData) {
            window?.setFrame(
                NSRect(x: position.x, y: position.y, width: position.width, height: position.height),
                display: true
            )
        }
    }

    func closeWindow() {
        // Save window position
        if let frame = window?.frame {
            let position = WindowPosition(
                x: frame.origin.x,
                y: frame.origin.y,
                width: frame.size.width,
                height: frame.size.height
            )
            if let data = try? JSONEncoder().encode(position) {
                UserDefaults.standard.set(data, forKey: "dashboardWindowPosition")
            }
        }

        window?.close()
    }

    private func createWindow() {
        let dashboardView = DashboardView(
            systemMonitor: systemMonitor,
            featureManager: featureManager,
            cacheManager: cacheManager,
            appManager: appManager,
            smartCleanManager: smartCleanManager,
            settings: settings
        )
        .frame(minWidth: 800, minHeight: 500)

        let hostingController = NSHostingController(rootView: dashboardView)
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 900, height: 600)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.title = "SystemMonitor Pro"
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.backgroundColor = NSColor(Theme.Colors.background)
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 800, height: 500)
        window.setContentSize(NSSize(width: 900, height: 600))
        window.center()

        // Handle window close
        window.delegate = self

        self.window = window
    }

    struct WindowPosition: Codable {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
    }
}

// MARK: - NSWindowDelegate
extension DashboardWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Save position when closing
        if let frame = window?.frame {
            let position = WindowPosition(
                x: frame.origin.x,
                y: frame.origin.y,
                width: frame.size.width,
                height: frame.size.height
            )
            if let data = try? JSONEncoder().encode(position) {
                UserDefaults.standard.set(data, forKey: "dashboardWindowPosition")
            }
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Allow normal close behavior - window stays in memory for reopen
        return true
    }
}

// MARK: - Keyboard Event Handler
class DashboardKeyHandler: NSObject {
    private weak var windowController: DashboardWindowController?
    private var eventMonitor: Any?

    init(windowController: DashboardWindowController) {
        self.windowController = windowController
        super.init()

        // Add global escape key handler
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape key
                self?.windowController?.closeWindow()
                return nil
            }
            return event
        }
    }

    deinit {
        // Remove event monitor to prevent memory leak
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
