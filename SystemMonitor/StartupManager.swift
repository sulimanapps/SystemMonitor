import Foundation
import AppKit
import ServiceManagement

struct StartupItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let type: StartupItemType
    let isEnabled: Bool
    let bundleID: String?
    var icon: NSImage?
}

enum StartupItemType: String {
    case loginItem = "Login Item"
    case launchAgent = "Launch Agent"
    case launchDaemon = "Launch Daemon"

    var icon: String {
        switch self {
        case .loginItem: return "person.crop.circle"
        case .launchAgent: return "gearshape.2"
        case .launchDaemon: return "server.rack"
        }
    }
}

class StartupManager: ObservableObject {
    @Published var items: [StartupItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadStartupItems() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var allItems: [StartupItem] = []

            // 1. Get User Launch Agents
            allItems.append(contentsOf: self.getLaunchItems(path: "\(NSHomeDirectory())/Library/LaunchAgents", type: .launchAgent))

            // 2. Get System Launch Agents
            allItems.append(contentsOf: self.getLaunchItems(path: "/Library/LaunchAgents", type: .launchAgent))

            // 3. Get System Launch Daemons (read-only)
            allItems.append(contentsOf: self.getLaunchItems(path: "/Library/LaunchDaemons", type: .launchDaemon))

            DispatchQueue.main.async {
                self.items = allItems
                self.isLoading = false
            }
        }
    }

    private func getLaunchItems(path: String, type: StartupItemType) -> [StartupItem] {
        var items: [StartupItem] = []
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return items
        }

        for file in contents where file.hasSuffix(".plist") {
            let fullPath = "\(path)/\(file)"

            guard let plistData = fileManager.contents(atPath: fullPath),
                  let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
                continue
            }

            let label = plist["Label"] as? String ?? file.replacingOccurrences(of: ".plist", with: "")
            let programArgs = plist["ProgramArguments"] as? [String]
            let program = plist["Program"] as? String ?? programArgs?.first ?? ""
            let disabled = plist["Disabled"] as? Bool ?? false

            // Check if loaded via launchctl
            let isLoaded = checkIfLoaded(label: label)

            // Get app name from label or program
            let name = extractName(from: label, program: program)

            let item = StartupItem(
                name: name,
                path: fullPath,
                type: type,
                isEnabled: !disabled && isLoaded,
                bundleID: label,
                icon: nil
            )
            items.append(item)
        }

        return items
    }

    private func checkIfLoaded(label: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list", label]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func extractName(from label: String, program: String) -> String {
        // Try to extract a friendly name
        let components = label.components(separatedBy: ".")

        // Skip common prefixes
        let meaningfulParts = components.filter { part in
            !["com", "local", "user", "io", "org", "net", "app"].contains(part.lowercased())
        }

        if let name = meaningfulParts.last, !name.isEmpty {
            return name
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }

        // Fall back to last component
        if let lastName = components.last, !lastName.isEmpty {
            return lastName.capitalized
        }

        // Fall back to program name
        return (program as NSString).lastPathComponent
    }

    func toggleItem(_ item: StartupItem) {
        guard item.type == .launchAgent,
              item.path.contains(NSHomeDirectory()) else {
            errorMessage = "Can only modify user Launch Agents"
            return
        }

        // Read the plist
        guard let plistData = FileManager.default.contents(atPath: item.path),
              var plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            errorMessage = "Failed to read plist"
            return
        }

        // Toggle disabled state
        plist["Disabled"] = item.isEnabled

        // Write back
        do {
            let newData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try newData.write(to: URL(fileURLWithPath: item.path))

            // Reload the item
            if item.isEnabled {
                launchctl(action: "unload", path: item.path)
            } else {
                launchctl(action: "load", path: item.path)
            }

            loadStartupItems()
        } catch {
            errorMessage = "Failed to update: \(error.localizedDescription)"
        }
    }

    func removeItem(_ item: StartupItem) {
        guard item.type == .launchAgent,
              item.path.contains(NSHomeDirectory()) else {
            errorMessage = "Can only remove user Launch Agents"
            return
        }

        do {
            // Unload first
            launchctl(action: "unload", path: item.path)

            // Move to trash
            try FileManager.default.trashItem(at: URL(fileURLWithPath: item.path), resultingItemURL: nil)

            loadStartupItems()
        } catch {
            errorMessage = "Failed to remove: \(error.localizedDescription)"
        }
    }

    private func launchctl(action: String, path: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = [action, path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try? process.run()
        process.waitUntilExit()
    }

    func openInFinder(_ item: StartupItem) {
        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
    }
}
