import Foundation
import AppKit

enum FeedbackCategory: String, CaseIterable {
    case bug = "Bug"
    case featureRequest = "Feature Request"
    case other = "Other"

    var displayName: String {
        return rawValue
    }
}

class FeedbackManager: ObservableObject {
    @Published var feedbackText: String = ""
    @Published var selectedCategory: FeedbackCategory = .bug
    @Published var isSubmitting: Bool = false
    @Published var showSuccess: Bool = false
    @Published var errorMessage: String = ""

    private var feedbackFilePath: String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("SystemMonitor-Feedback.txt").path
    }

    func submitFeedback() {
        guard !feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your feedback"
            return
        }

        isSubmitting = true
        errorMessage = ""

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .medium
        dateFormatter.locale = Locale(identifier: "en_US")
        let readableDate = dateFormatter.string(from: Date())

        let feedbackEntry = """

        ========================================
        FEEDBACK REPORT
        ========================================
        Date: \(readableDate)
        Timestamp: \(timestamp)
        Category: \(selectedCategory.rawValue)
        App Version: 2.0.0
        macOS: \(Foundation.ProcessInfo.processInfo.operatingSystemVersionString)
        ----------------------------------------

        \(feedbackText)

        ========================================

        """

        do {
            let fileManager = FileManager.default

            if fileManager.fileExists(atPath: feedbackFilePath) {
                // Append to existing file
                let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: feedbackFilePath))
                fileHandle.seekToEndOfFile()
                if let data = feedbackEntry.data(using: String.Encoding.utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                // Create new file with header
                let header = """
                # SystemMonitor Pro - Feedback Log
                # Created: \(readableDate)

                """
                let fullContent = header + feedbackEntry
                try fullContent.write(toFile: feedbackFilePath, atomically: true, encoding: String.Encoding.utf8)
            }

            DispatchQueue.main.async {
                self.isSubmitting = false
                self.showSuccess = true
                self.feedbackText = ""
            }
        } catch {
            DispatchQueue.main.async {
                self.isSubmitting = false
                self.errorMessage = "Failed to save feedback: \(error.localizedDescription)"
            }
        }
    }

    func openFeedbackFile() {
        if FileManager.default.fileExists(atPath: feedbackFilePath) {
            NSWorkspace.shared.open(URL(fileURLWithPath: feedbackFilePath))
        }
    }

    func openGitHubIssues() {
        if let url = URL(string: "https://github.com/sulimanapps/SystemMonitor/issues/new") {
            NSWorkspace.shared.open(url)
        }
    }

    func reset() {
        feedbackText = ""
        selectedCategory = .bug
        showSuccess = false
        errorMessage = ""
    }
}
