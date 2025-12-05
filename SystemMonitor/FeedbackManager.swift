import Foundation
import AppKit

enum FeedbackCategory: String, CaseIterable {
    case bug = "Bug"
    case featureRequest = "Feature Request"
    case other = "Other"

    var arabicName: String {
        switch self {
        case .bug: return "خطأ"
        case .featureRequest: return "طلب ميزة"
        case .other: return "أخرى"
        }
    }

    var displayName: String {
        return "\(rawValue) | \(arabicName)"
    }
}

class FeedbackManager: ObservableObject {
    @Published var feedbackText: String = ""
    @Published var selectedCategory: FeedbackCategory = .bug
    @Published var isSubmitting: Bool = false
    @Published var showSuccess: Bool = false
    @Published var errorMessage: String = ""

    private let feedbackFilePath: String

    init() {
        // Save feedback to the project directory
        feedbackFilePath = NSHomeDirectory() + "/Desktop/SystemMonitor/feedback.txt"
    }

    func submitFeedback() {
        guard !feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter feedback | الرجاء إدخال ملاحظات"
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
        FEEDBACK REPORT | تقرير ملاحظات
        ========================================
        Date: \(readableDate)
        Timestamp: \(timestamp)
        Category: \(selectedCategory.displayName)
        App Version: 1.0.0
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
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
                if let data = feedbackEntry.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                // Create new file with header
                let header = """
                # SystemMonitor Feedback Log
                # سجل ملاحظات مراقب النظام
                # Created: \(readableDate)

                """
                let fullContent = header + feedbackEntry
                try fullContent.write(toFile: feedbackFilePath, atomically: true, encoding: .utf8)
            }

            DispatchQueue.main.async {
                self.isSubmitting = false
                self.showSuccess = true
                self.feedbackText = ""
            }
        } catch {
            DispatchQueue.main.async {
                self.isSubmitting = false
                self.errorMessage = "Failed to save feedback | فشل حفظ الملاحظات"
            }
        }
    }

    func openFeedbackFile() {
        if FileManager.default.fileExists(atPath: feedbackFilePath) {
            NSWorkspace.shared.open(URL(fileURLWithPath: feedbackFilePath))
        }
    }

    func reset() {
        feedbackText = ""
        selectedCategory = .bug
        showSuccess = false
        errorMessage = ""
    }
}
