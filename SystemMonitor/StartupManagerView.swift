import SwiftUI
import AppKit

struct StartupManagerView: View {
    @ObservedObject var startupManager: StartupManager
    @Binding var isPresented: Bool
    @State private var selectedItem: StartupItem?
    @State private var showDeleteConfirmation = false
    @State private var filterType: StartupItemType?

    var filteredItems: [StartupItem] {
        if let type = filterType {
            return startupManager.items.filter { $0.type == type }
        }
        return startupManager.items
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "power.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                Text("Startup Items")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            // Filter bar
            HStack {
                Text("Filter:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("", selection: $filterType) {
                    Text("All").tag(nil as StartupItemType?)
                    Text("Launch Agent").tag(StartupItemType.launchAgent as StartupItemType?)
                    Text("Launch Daemon").tag(StartupItemType.launchDaemon as StartupItemType?)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 280)

                Spacer()

                Text("\(filteredItems.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Error message
            if let error = startupManager.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text(error)
                        .font(.caption)
                    Spacer()
                    Button("Dismiss") {
                        startupManager.errorMessage = nil
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
                .padding(8)
                .background(Color.yellow.opacity(0.1))
            }

            // Item list
            if startupManager.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Scanning startup items...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "power.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No startup items found")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredItems) { item in
                            StartupItemRow(
                                item: item,
                                isSelected: selectedItem?.id == item.id,
                                onSelect: { selectedItem = item },
                                onToggle: { startupManager.toggleItem(item) },
                                onShowInFinder: { startupManager.openInFinder(item) }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider()

            // Footer
            HStack {
                Button(action: { startupManager.loadStartupItems() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                }
                .buttonStyle(.bordered)

                Spacer()

                if let item = selectedItem, item.type == .launchAgent, item.path.contains(NSHomeDirectory()) {
                    Button(action: { showDeleteConfirmation = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Remove")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding()
        }
        .frame(width: 550, height: 450)
        .onAppear {
            startupManager.loadStartupItems()
        }
        .alert("Remove Startup Item?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let item = selectedItem {
                    startupManager.removeItem(item)
                    selectedItem = nil
                }
            }
        } message: {
            if let item = selectedItem {
                Text("Are you sure you want to remove \"\(item.name)\" from startup items? The file will be moved to Trash.")
            }
        }
    }
}

struct StartupItemRow: View {
    let item: StartupItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggle: () -> Void
    let onShowInFinder: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            if let icon = item.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: item.type.icon)
                    .font(.title2)
                    .foregroundColor(typeColor(item.type))
                    .frame(width: 28, height: 28)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(.body))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // Type badge
                    Text(item.type.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(typeColor(item.type).opacity(0.15))
                        .foregroundColor(typeColor(item.type))
                        .cornerRadius(4)

                    // Status
                    HStack(spacing: 2) {
                        Circle()
                            .fill(item.isEnabled ? Color.green : Color.gray)
                            .frame(width: 6, height: 6)
                        Text(item.isEnabled ? "Enabled" : "Disabled")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Toggle (only for user launch agents)
            if item.type == .launchAgent && item.path.contains(NSHomeDirectory()) {
                Toggle("", isOn: Binding(
                    get: { item.isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }

            // Show in Finder
            Button(action: onShowInFinder) {
                Image(systemName: "folder")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }

    private func typeColor(_ type: StartupItemType) -> Color {
        switch type {
        case .loginItem: return .blue
        case .launchAgent: return .purple
        case .launchDaemon: return .orange
        }
    }
}

// Compact view for menu
struct StartupManagerCompactView: View {
    @ObservedObject var startupManager: StartupManager
    @Binding var isExpanded: Bool
    var onOpenFullView: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Label("Startup Items", systemImage: "power.circle.fill")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(startupManager.items.filter { $0.isEnabled }.count) enabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(startupManager.items.prefix(4))) { item in
                        HStack {
                            Circle()
                                .fill(item.isEnabled ? Color.green : Color.gray)
                                .frame(width: 6, height: 6)
                            Text(item.name)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(item.type.rawValue)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    if startupManager.items.count > 4 {
                        Text("+ \(startupManager.items.count - 4) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button(action: onOpenFullView) {
                        HStack {
                            Text("Manage Startup Items")
                                .font(.caption)
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    .padding(.top, 4)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .onAppear {
            if startupManager.items.isEmpty {
                startupManager.loadStartupItems()
            }
        }
    }
}

#Preview {
    StartupManagerView(startupManager: StartupManager(), isPresented: .constant(true))
}
