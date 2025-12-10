import SwiftUI
import AppKit

// MARK: - App Uninstall View
struct AppUninstallView: View {
    @ObservedObject var appManager: AppManager
    @Binding var isPresented: Bool
    @State private var selectedApps: Set<UUID> = []
    @State private var searchText = ""
    @State private var showConfirmation = false
    @State private var showRunningWarning = false
    @State private var runningAppsSelected: [InstalledApp] = []
    @State private var uninstallComplete = false
    @State private var uninstalledCount = 0
    @State private var freedSize: UInt64 = 0
    @State private var expandedApps: Set<UUID> = []
    @State private var selectedTab = 0 // 0 = Apps, 1 = Leftovers
    @State private var selectedLeftovers: Set<UUID> = []
    @State private var showResetConfirmation = false
    @State private var appToReset: InstalledApp?
    @State private var resetComplete = false
    @State private var resetFreedSize: UInt64 = 0
    @State private var cleanupComplete = false
    @State private var cleanupCount = 0
    @State private var cleanupSize: UInt64 = 0

    var filteredApps: [InstalledApp] {
        if searchText.isEmpty {
            return appManager.installedApps
        }
        return appManager.installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var selectedSize: UInt64 {
        appManager.installedApps
            .filter { selectedApps.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    var selectedAppsList: [InstalledApp] {
        appManager.installedApps.filter { selectedApps.contains($0.id) }
    }

    var selectedLeftoversSize: UInt64 {
        appManager.leftoverFiles
            .filter { selectedLeftovers.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Tab Picker
            Picker("", selection: $selectedTab) {
                Text("Apps").tag(0)
                Text("Leftovers").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Content
            if selectedTab == 0 {
                appTabContent
            } else {
                leftoverTabContent
            }
        }
        .frame(width: 600, height: 650)
        .background(Color(NSColor.windowBackgroundColor))
        .alert("Uninstall Apps?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Uninstall", role: .destructive) {
                performUninstall()
            }
        } message: {
            Text("Are you sure you want to uninstall \(selectedApps.count) app(s)? This will move them to Trash and clean up leftover files.\n\nTotal space to free: \(formatBytes(selectedSize))")
        }
        .alert("Running Apps Detected", isPresented: $showRunningWarning) {
            Button("Skip Running Apps") {
                for app in runningAppsSelected {
                    selectedApps.remove(app.id)
                }
                if !selectedApps.isEmpty {
                    showConfirmation = true
                }
            }
            Button("Force Quit & Uninstall", role: .destructive) {
                performForceUninstall()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            let names = runningAppsSelected.map { $0.name }.joined(separator: ", ")
            Text("The following apps are currently running:\n\(names)\n\nYou can skip them, or force quit and uninstall.")
        }
        .alert("Reset App?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                if let app = appToReset {
                    performReset(app)
                }
            }
        } message: {
            if let app = appToReset {
                Text("Reset \(app.name)?\n\nThis will delete all preferences, caches, and saved data. The app will start fresh like a new install.")
            } else {
                Text("Reset this app?")
            }
        }
        .onAppear {
            appManager.scanApps()
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Image(systemName: "app.badge.checkmark")
                .font(.title)
                .foregroundColor(.red)
            Text("App Manager")
                .font(.headline)
            Spacer()
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
    }

    // MARK: - App Tab Content
    @ViewBuilder
    private var appTabContent: some View {
        if appManager.isScanning {
            scanningView
        } else if appManager.isUninstalling {
            uninstallingView
        } else if uninstallComplete {
            completionView
        } else if resetComplete {
            resetCompletionView
        } else {
            appListView
        }
    }

    // MARK: - Leftover Tab Content
    @ViewBuilder
    private var leftoverTabContent: some View {
        if cleanupComplete {
            cleanupCompletionView
        } else if appManager.isScanningLeftovers {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Scanning for leftover files...")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if appManager.leftoverFiles.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                Text("No Leftovers Found")
                    .font(.headline)
                Text("Your system is clean!")
                    .foregroundColor(.secondary)
                Button("Scan Again") {
                    appManager.scanLeftoverFiles()
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                if appManager.leftoverFiles.isEmpty && !appManager.isScanningLeftovers {
                    appManager.scanLeftoverFiles()
                }
            }
        } else {
            leftoverListView
        }
    }

    // MARK: - Cleanup Completion View
    private var cleanupCompletionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Cleanup Complete!")
                .font(.headline)

            if cleanupCount > 0 {
                Text("Removed \(cleanupCount) leftover file(s)")
                    .foregroundColor(.secondary)
                Text("Freed \(formatBytes(cleanupSize))")
                    .font(.title2)
                    .foregroundColor(.orange)
            }

            Button("Done") {
                cleanupComplete = false
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Scanning View
    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning installed apps...")
                .foregroundColor(.secondary)
            Text("Checking /Applications and ~/Applications")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Uninstalling View
    private var uninstallingView: some View {
        VStack(spacing: 20) {
            ProgressView(value: appManager.uninstallProgress)
                .progressViewStyle(.linear)
                .frame(width: 300)

            if !appManager.currentAppBeingUninstalled.isEmpty {
                Text("Uninstalling \(appManager.currentAppBeingUninstalled)...")
                    .foregroundColor(.secondary)
            }

            Text("Cleaning up leftover files...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Completion View
    private var completionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("Uninstall Complete!")
                .font(.headline)

            if uninstalledCount > 0 {
                Text("Removed \(uninstalledCount) app(s)")
                    .foregroundColor(.secondary)
                Text("Freed \(formatBytes(freedSize))")
                    .font(.title2)
                    .foregroundColor(.green)
            } else {
                Text("No apps were uninstalled")
                    .foregroundColor(.secondary)
            }

            Button("Done") {
                uninstallComplete = false
                selectedApps.removeAll()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Reset Completion View
    private var resetCompletionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text("Reset Complete!")
                .font(.headline)

            Text("Freed \(formatBytes(resetFreedSize))")
                .font(.title2)
                .foregroundColor(.blue)

            Text("The app will start fresh on next launch")
                .foregroundColor(.secondary)

            Button("Done") {
                resetComplete = false
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - App List View
    private var appListView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search apps...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Info banner
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("System apps protected • Running apps shown with ⚡ • Click arrow to see related files")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()

                Button("Select All") {
                    for app in filteredApps where !app.isSystemApp {
                        selectedApps.insert(app.id)
                    }
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(.blue)

                Button("Clear") {
                    selectedApps.removeAll()
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(.orange)
            }
            .padding(10)
            .background(Color.blue.opacity(0.1))

            // App list
            if filteredApps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "No apps found" : "No matching apps")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(filteredApps.enumerated()), id: \.element.id) { index, app in
                            AppRowExpanded(
                                app: app,
                                isSelected: selectedApps.contains(app.id),
                                isExpanded: expandedApps.contains(app.id),
                                onToggle: {
                                    if !app.isSystemApp {
                                        if selectedApps.contains(app.id) {
                                            selectedApps.remove(app.id)
                                        } else {
                                            selectedApps.insert(app.id)
                                        }
                                    }
                                },
                                onExpand: {
                                    if expandedApps.contains(app.id) {
                                        expandedApps.remove(app.id)
                                    } else {
                                        expandedApps.insert(app.id)
                                        // Load related files if not already loaded
                                        if !app.relatedFilesLoaded {
                                            appManager.loadRelatedFiles(for: index)
                                        }
                                    }
                                },
                                onReset: {
                                    appToReset = app
                                    showResetConfirmation = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }

            // Bottom action area
            actionArea
        }
    }

    // MARK: - Leftover List View
    private var leftoverListView: some View {
        VStack(spacing: 0) {
            // Explanation banner
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("What are Leftovers?")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                Text("When you delete an app, some files remain: caches, preferences, and app data. These orphaned files waste disk space. Select and clean them safely.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.1))

            // Info banner
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                    .foregroundColor(.orange)
                Text("Found \(appManager.leftoverFiles.count) orphaned files")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()

                Button("Select All") {
                    for file in appManager.leftoverFiles {
                        selectedLeftovers.insert(file.id)
                    }
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(.blue)

                Button("Clear") {
                    selectedLeftovers.removeAll()
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(.orange)

                Button("Rescan") {
                    selectedLeftovers.removeAll()
                    appManager.scanLeftoverFiles()
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(.green)
            }
            .padding(10)
            .background(Color.orange.opacity(0.1))

            // Leftover list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(appManager.leftoverFiles) { file in
                        LeftoverFileRow(
                            file: file,
                            isSelected: selectedLeftovers.contains(file.id),
                            onToggle: {
                                if selectedLeftovers.contains(file.id) {
                                    selectedLeftovers.remove(file.id)
                                } else {
                                    selectedLeftovers.insert(file.id)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            // Bottom action area for leftovers
            leftoverActionArea
        }
    }

    // MARK: - Leftover Action Area
    private var leftoverActionArea: some View {
        VStack(spacing: 12) {
            Divider()

            if !selectedLeftovers.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("\(selectedLeftovers.count) file(s) selected")
                    Spacer()
                    Text(formatBytes(selectedLeftoversSize))
                        .font(.headline.monospacedDigit())
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(action: {
                    let filesToClean = appManager.leftoverFiles.filter { selectedLeftovers.contains($0.id) }
                    appManager.cleanLeftoverFiles(filesToClean) { count, size in
                        cleanupSize = size
                        cleanupCount = count
                        cleanupComplete = true
                        selectedLeftovers.removeAll()
                    }
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Clean Selected")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .frame(maxWidth: .infinity)
                .disabled(selectedLeftovers.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    // MARK: - Action Area
    private var actionArea: some View {
        VStack(spacing: 12) {
            Divider()

            // Selected summary
            if !selectedApps.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.red)
                    Text("\(selectedApps.count) app(s) selected")
                    Spacer()
                    Text(formatBytes(selectedSize))
                        .font(.headline.monospacedDigit())
                        .foregroundColor(.red)
                }
                .padding(.horizontal)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(action: {
                    initiateUninstall()
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Uninstall Selected")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .frame(maxWidth: .infinity)
                .disabled(selectedApps.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    // MARK: - Helper Methods
    private func initiateUninstall() {
        runningAppsSelected = selectedAppsList.filter { $0.isRunning }

        if !runningAppsSelected.isEmpty {
            showRunningWarning = true
        } else {
            showConfirmation = true
        }
    }

    private func performUninstall() {
        let appsToUninstall = selectedAppsList
        appManager.uninstallApps(appsToUninstall) { count, size in
            uninstalledCount = count
            freedSize = size
            uninstallComplete = true
            selectedApps.removeAll()
        }
    }

    private func performForceUninstall() {
        let appsToUninstall = selectedAppsList
        appManager.forceQuitAndUninstall(appsToUninstall) { count, size in
            uninstalledCount = count
            freedSize = size
            uninstallComplete = true
            selectedApps.removeAll()
        }
    }

    private func performReset(_ app: InstalledApp) {
        appManager.resetApp(app) { success, size in
            if success {
                resetFreedSize = size
                resetComplete = true
            }
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        } else {
            let mb = Double(bytes) / 1_048_576
            return String(format: "%.0f MB", mb)
        }
    }
}

// MARK: - App Row Expanded
struct AppRowExpanded: View {
    let app: InstalledApp
    let isSelected: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let onExpand: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    // Expand arrow
                    Button(action: onExpand) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 16)
                    }
                    .buttonStyle(.plain)

                    // Checkbox or locked icon
                    if app.isSystemApp {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .frame(width: 22)
                    } else {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundColor(isSelected ? .red : .secondary)
                            .frame(width: 22)
                    }

                    // App icon
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 32, height: 32)
                            .cornerRadius(6)
                    } else {
                        Image(systemName: "app")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                    }

                    // App info
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(app.name)
                                .font(.subheadline)
                                .foregroundColor(app.isSystemApp ? .secondary : .primary)
                                .lineLimit(1)

                            if app.isRunning {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.yellow)
                            }

                            if app.isSystemApp {
                                Text("System")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.gray)
                                    .cornerRadius(3)
                            }
                        }

                        HStack(spacing: 8) {
                            if let lastUsed = app.lastUsed {
                                Text("Last used: \(formatDate(lastUsed))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text(app.path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }

                    Spacer()

                    // Reset button (only for non-system apps)
                    if !app.isSystemApp {
                        Button(action: onReset) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash.circle")
                                    .font(.system(size: 12))
                                Text("Clear Data")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .help("Delete app cache & preferences")
                    }

                    // Size
                    Text(formatBytes(app.size))
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(app.size > 1_073_741_824 ? .orange : .secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    isSelected ? Color.red.opacity(0.1) :
                        (app.isSystemApp ? Color.gray.opacity(0.05) : Color(NSColor.controlBackgroundColor).opacity(0.5))
                )
                .cornerRadius(8)
                .opacity(app.isSystemApp ? 0.7 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(app.isSystemApp)

            // Expanded related files
            if isExpanded {
                if app.relatedFilesLoaded && !app.relatedFiles.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(app.relatedFiles) { file in
                            HStack(spacing: 8) {
                                Image(systemName: iconForType(file.type))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .frame(width: 16)

                                Text(file.type.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .leading)

                                Text(file.name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Spacer()

                                Text(formatBytes(file.size))
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 60)
                            .padding(.vertical, 2)
                        }

                        // Total related files size
                        let totalRelatedSize = app.relatedFiles.reduce(0) { $0 + $1.size }
                        HStack {
                            Spacer()
                            Text("Related files: \(formatBytes(totalRelatedSize))")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 4)
                    }
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    .cornerRadius(4)
                    .padding(.horizontal, 8)
                    .padding(.top, 2)
                } else if app.relatedFilesLoaded && app.relatedFiles.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("No related files found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 8)
                } else {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Loading related files...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func iconForType(_ type: AppLeftoverFile.LeftoverType) -> String {
        switch type {
        case .preferences: return "gear"
        case .cache: return "internaldrive"
        case .applicationSupport: return "folder"
        case .savedState: return "doc"
        case .logs: return "doc.text"
        case .containers: return "shippingbox"
        case .other: return "questionmark.folder"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        } else {
            let mb = Double(bytes) / 1_048_576
            return String(format: "%.0f MB", mb)
        }
    }
}

// MARK: - Leftover File Row
struct LeftoverFileRow: View {
    let file: AppLeftoverFile
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .orange : .secondary)
                    .frame(width: 22)

                Image(systemName: iconForType(file.type))
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(file.type.rawValue)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(colorForType(file.type))
                            .cornerRadius(3)

                        Text(file.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer()

                Text(formatBytes(file.size))
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(file.size > 100_000_000 ? .orange : .secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                isSelected ? Color.orange.opacity(0.1) : Color(NSColor.controlBackgroundColor).opacity(0.5)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private func iconForType(_ type: AppLeftoverFile.LeftoverType) -> String {
        switch type {
        case .preferences: return "gear"
        case .cache: return "internaldrive"
        case .applicationSupport: return "folder.fill"
        case .savedState: return "doc.fill"
        case .logs: return "doc.text.fill"
        case .containers: return "shippingbox.fill"
        case .other: return "questionmark.folder.fill"
        }
    }

    private func colorForType(_ type: AppLeftoverFile.LeftoverType) -> Color {
        switch type {
        case .preferences: return .blue
        case .cache: return .orange
        case .applicationSupport: return .green
        case .savedState: return .purple
        case .logs: return .gray
        case .containers: return .cyan
        case .other: return .secondary
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        } else {
            let mb = Double(bytes) / 1_048_576
            if mb >= 1 {
                return String(format: "%.0f MB", mb)
            } else {
                let kb = Double(bytes) / 1024
                return String(format: "%.0f KB", kb)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    AppUninstallView(
        appManager: AppManager(),
        isPresented: .constant(true)
    )
}
