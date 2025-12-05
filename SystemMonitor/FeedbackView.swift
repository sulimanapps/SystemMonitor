import SwiftUI

struct FeedbackView: View {
    @ObservedObject var feedbackManager: FeedbackManager
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.bubble.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Report Bug / Feedback")
                        .font(.headline)
                    Text("الإبلاغ عن خطأ / ملاحظات")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if feedbackManager.showSuccess {
                // Success view
                VStack(spacing: 16) {
                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)

                    Text("Thank you!")
                        .font(.headline)
                    Text("شكراً لك!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Your feedback has been saved.")
                        .font(.caption)
                    Text("تم حفظ ملاحظاتك.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    HStack(spacing: 12) {
                        Button("View Feedback File") {
                            feedbackManager.openFeedbackFile()
                        }
                        .buttonStyle(.bordered)

                        Button("Done") {
                            feedbackManager.reset()
                            isPresented = false
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                    .padding(.bottom)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Form view
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Category picker
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Category")
                                    .font(.subheadline.weight(.semibold))
                                Text("| الفئة")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Picker("Category", selection: $feedbackManager.selectedCategory) {
                                ForEach(FeedbackCategory.allCases, id: \.self) { category in
                                    Text(category.displayName).tag(category)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        // Description field
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Description")
                                    .font(.subheadline.weight(.semibold))
                                Text("| الوصف")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            TextEditor(text: $feedbackManager.feedbackText)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(height: 150)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .overlay(
                                    Group {
                                        if feedbackManager.feedbackText.isEmpty {
                                            VStack(alignment: .leading) {
                                                Text("Describe the bug or feature request...")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Text("صف الخطأ أو طلب الميزة...")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary.opacity(0.7))
                                            }
                                            .padding(8)
                                            .allowsHitTesting(false)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }

                        // Tips section
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Tips for good feedback:", systemImage: "lightbulb.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.orange)

                            Group {
                                Text("• Be specific about what happened")
                                Text("• Include steps to reproduce (for bugs)")
                                Text("• Describe expected vs actual behavior")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)

                        // Error message
                        if !feedbackManager.errorMessage.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(feedbackManager.errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }

                        // System info
                        VStack(alignment: .leading, spacing: 4) {
                            Text("System Info (auto-included)")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                            Text("App Version: 1.0.0")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }

                Divider()

                // Actions
                HStack {
                    Button("Cancel | إلغاء") {
                        feedbackManager.reset()
                        isPresented = false
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(action: {
                        feedbackManager.submitFeedback()
                    }) {
                        if feedbackManager.isSubmitting {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Submit | إرسال")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(feedbackManager.isSubmitting || feedbackManager.feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
        }
        .frame(width: 400, height: 450)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// Button to show feedback window
struct ReportBugButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "ladybug.fill")
                Text("Report Bug")
                Text("| الإبلاغ عن خطأ")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(.orange)
    }
}

#Preview {
    FeedbackView(feedbackManager: FeedbackManager(), isPresented: .constant(true))
}
