import SwiftUI
import AppKit

struct ProcessManagerView: View {
    @ObservedObject var processManager: ProcessManager
    @Binding var isPresented: Bool
    @State private var selectedProcess: ProcessInfo?
    @State private var showKillConfirmation = false
    @State private var forceKill = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.title2)
                    .foregroundColor(.purple)
                Text("Process Manager")
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

            // Toolbar
            HStack {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search processes...", text: $processManager.searchText)
                        .textFieldStyle(.plain)
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                Spacer()

                // Sort picker
                Picker("", selection: $processManager.sortBy) {
                    ForEach(ProcessManager.SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .labelsHidden()

                // Show system toggle
                Toggle("System", isOn: $processManager.showSystemProcesses)
                    .toggleStyle(.checkbox)
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Process list
            if processManager.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading processes...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(processManager.filteredProcesses) { process in
                            ProcessRowItem(
                                process: process,
                                isSelected: selectedProcess?.id == process.id,
                                onSelect: { selectedProcess = process },
                                onKill: {
                                    selectedProcess = process
                                    forceKill = false
                                    showKillConfirmation = true
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Error message
            if let error = processManager.killError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Dismiss") {
                        processManager.killError = nil
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
                .padding(8)
                .background(Color.yellow.opacity(0.1))
            }

            Divider()

            // Footer
            HStack {
                Text("\(processManager.filteredProcesses.count) processes")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { processManager.loadProcesses() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                }
                .buttonStyle(.bordered)

                if selectedProcess != nil {
                    Button(action: {
                        forceKill = false
                        showKillConfirmation = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle")
                            Text("End Process")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)

                    Button(action: {
                        forceKill = true
                        showKillConfirmation = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Force Quit")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .onAppear {
            processManager.loadProcesses()
        }
        .alert("Terminate Process?", isPresented: $showKillConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button(forceKill ? "Force Quit" : "End Process", role: .destructive) {
                if let process = selectedProcess {
                    processManager.killProcess(process, force: forceKill)
                    selectedProcess = nil
                }
            }
        } message: {
            if let process = selectedProcess {
                Text("Are you sure you want to \(forceKill ? "force quit" : "end") \"\(process.name)\"? Unsaved changes may be lost.")
            }
        }
    }
}

struct ProcessRowItem: View {
    let process: ProcessInfo
    let isSelected: Bool
    let onSelect: () -> Void
    let onKill: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: process.isSystemProcess ? "gearshape.fill" : "app.fill")
                .font(.title3)
                .foregroundColor(process.isSystemProcess ? .orange : .blue)
                .frame(width: 24, height: 24)

            // Name and PID
            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(.system(.body, design: .default))
                    .lineLimit(1)
                Text("PID: \(process.pid)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 150, alignment: .leading)

            Spacer()

            // CPU
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f%%", process.cpuUsage))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(cpuColor(process.cpuUsage))
                Text("CPU")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)

            // Memory
            VStack(alignment: .trailing, spacing: 2) {
                Text(process.memoryString)
                    .font(.system(.caption, design: .monospaced))
                Text("Memory")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 70)

            // User
            Text(process.user)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60)

            // Kill button
            Button(action: onKill) {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
            .opacity(isSelected ? 1 : 0.5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }

    private func cpuColor(_ cpu: Double) -> Color {
        if cpu > 50 { return .red }
        if cpu > 20 { return .orange }
        return .primary
    }
}

// Compact view for menu bar
struct ProcessManagerCompactView: View {
    @ObservedObject var processManager: ProcessManager
    @Binding var isExpanded: Bool
    var onOpenFullView: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Label("Process Manager", systemImage: "list.bullet.rectangle.portrait")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(processManager.processes.filter { !$0.isSystemProcess }.count) apps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    // Top 5 by memory
                    ForEach(Array(processManager.filteredProcesses.prefix(5))) { process in
                        HStack {
                            Image(systemName: "app.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text(process.name)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(process.memoryString)
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                    }

                    Button(action: onOpenFullView) {
                        HStack {
                            Text("Open Process Manager")
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
            if processManager.processes.isEmpty {
                processManager.loadProcesses()
            }
        }
    }
}

#Preview {
    ProcessManagerView(processManager: ProcessManager(), isPresented: .constant(true))
}
