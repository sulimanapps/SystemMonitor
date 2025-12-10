import SwiftUI

struct SmartCleanView: View {
    @ObservedObject var smartCleanManager: SmartCleanManager
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            if smartCleanManager.cleanComplete {
                cleanCompleteView
            } else if smartCleanManager.isCleaning {
                cleaningProgressView
            } else if smartCleanManager.isScanning {
                scanningView
            } else if smartCleanManager.categorySummaries.isEmpty {
                emptyStateView
            } else {
                categoriesListView
            }
        }
        .frame(width: 500, height: 550)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if smartCleanManager.categorySummaries.isEmpty && !smartCleanManager.isScanning {
                smartCleanManager.scanAll()
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Smart Clean")
                    .font(.headline)
                Text("One-click system cleanup")
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
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Ready to Clean")
                .font(.headline)

            Text("Scan your system to find junk files, caches, and leftovers that can be safely removed.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { smartCleanManager.scanAll() }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Scan System")
                }
                .frame(width: 150)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Scanning View
    private var scanningView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Scanning...")
                .font(.headline)

            Text(smartCleanManager.currentTask)
                .font(.caption)
                .foregroundColor(.secondary)

            ProgressView(value: smartCleanManager.scanProgress)
                .frame(width: 200)

            Text("\(Int(smartCleanManager.scanProgress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Categories List
    private var categoriesListView: some View {
        VStack(spacing: 0) {
            // Info banner
            infoBanner

            // Explanation
            explanationBanner

            // Categories list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(smartCleanManager.categorySummaries) { summary in
                        CategoryRow(
                            summary: summary,
                            onToggle: {
                                smartCleanManager.toggleCategory(summary.category)
                            }
                        )
                    }
                }
                .padding()
            }

            Divider()

            // Action area
            actionArea
        }
    }

    private var infoBanner: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(.green)

            Text("Found \(SmartCleanManager.formatBytes(totalFoundSize)) that can be cleaned")
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            Button("Rescan") {
                smartCleanManager.scanAll()
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color.green.opacity(0.1))
    }

    private var explanationBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("What will be cleaned?")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            Text("Select categories below. All files are moved to Trash for safety - you can recover them if needed.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
    }

    private var actionArea: some View {
        VStack(spacing: 12) {
            // Selection info
            HStack {
                if smartCleanManager.selectedCategoriesCount > 0 {
                    Text("\(smartCleanManager.selectedCategoriesCount) categories selected")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(SmartCleanManager.formatBytes(smartCleanManager.totalCleanableSize))
                        .font(.headline)
                        .foregroundColor(.orange)
                } else {
                    Text("Select categories to clean")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal)

            // Buttons
            HStack(spacing: 12) {
                Button("Select All") {
                    smartCleanManager.selectAll()
                }
                .buttonStyle(.bordered)

                Button("Deselect All") {
                    smartCleanManager.deselectAll()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(action: { isPresented = false }) {
                    Text("Cancel")
                }
                .buttonStyle(.bordered)

                Button(action: {
                    smartCleanManager.cleanSelected()
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Clean")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(smartCleanManager.selectedCategoriesCount == 0)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.top)
    }

    private var totalFoundSize: UInt64 {
        smartCleanManager.categorySummaries.reduce(0) { $0 + $1.size }
    }

    // MARK: - Cleaning Progress
    private var cleaningProgressView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Cleaning...")
                .font(.headline)

            Text(smartCleanManager.currentTask)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            ProgressView(value: smartCleanManager.cleanProgress)
                .frame(width: 200)

            Text("\(Int(smartCleanManager.cleanProgress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Clean Complete
    private var cleanCompleteView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Cleanup Complete!")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                Text("Freed \(SmartCleanManager.formatBytes(smartCleanManager.totalCleaned))")
                    .font(.title)
                    .foregroundColor(.orange)

                Text("\(smartCleanManager.itemsCleaned) items moved to Trash")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                Button("Scan Again") {
                    smartCleanManager.cleanComplete = false
                    smartCleanManager.scanAll()
                }
                .buttonStyle(.bordered)

                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Category Row
struct CategoryRow: View {
    let summary: CategorySummary
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: summary.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(summary.isSelected ? categoryColor : .secondary)
            }
            .buttonStyle(.plain)

            // Icon
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: summary.category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(categoryColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(summary.category.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Size and count
            VStack(alignment: .trailing, spacing: 2) {
                Text(SmartCleanManager.formatBytes(summary.size))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(categoryColor)

                Text("\(summary.itemCount) items")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(summary.isSelected ? categoryColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(summary.isSelected ? categoryColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private var categoryColor: Color {
        switch summary.category.color {
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "gray": return .gray
        case "yellow": return .yellow
        case "green": return .green
        case "cyan": return .cyan
        case "red": return .red
        default: return .orange
        }
    }
}

// MARK: - Preview
#Preview {
    SmartCleanView(
        smartCleanManager: SmartCleanManager(),
        isPresented: .constant(true)
    )
}
