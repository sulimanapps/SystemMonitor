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

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            if appManager.isScanning {
                scanningView
            } else if appManager.isUninstalling {
                uninstallingView
            } else if uninstallComplete {
                completionView
            } else {
                appListView
            }
        }
        .frame(width: 550, height: 600)
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
                // Remove running apps from selection
                for app in runningAppsSelected {
                    selectedApps.remove(app.id)
                }
                if !selectedApps.isEmpty {
                    showConfirmation = true
                }
            }
            Button("Force Quit & Uninstall", role: .destructive) {
                // Terminate running apps first
                for app in runningAppsSelected {
                    appManager.terminateApp(app)
                }
                // Wait a moment then proceed
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showConfirmation = true
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            let names = runningAppsSelected.map { $0.name }.joined(separator: ", ")
            Text("The following apps are currently running:\n\(names)\n\nYou can skip them, or force quit and uninstall.")
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
            Text("Uninstall Apps")
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
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
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
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("System apps cannot be uninstalled. Running apps shown with ⚡")
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
            .background(Color.orange.opacity(0.1))

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
                        ForEach(filteredApps) { app in
                            AppRow(
                                app: app,
                                isSelected: selectedApps.contains(app.id),
                                onToggle: {
                                    if !app.isSystemApp {
                                        if selectedApps.contains(app.id) {
                                            selectedApps.remove(app.id)
                                        } else {
                                            selectedApps.insert(app.id)
                                        }
                                    }
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
        // Check for running apps
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

// MARK: - App Row
struct AppRow: View {
    let app: InstalledApp
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
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

                    Text(app.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

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

// MARK: - Preview
#Preview {
    AppUninstallView(
        appManager: AppManager(),
        isPresented: .constant(true)
    )
}
