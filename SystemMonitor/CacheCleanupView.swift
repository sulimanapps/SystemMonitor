import SwiftUI

struct CacheCleanupView: View {
    @ObservedObject var cacheManager: CacheManager
    @Binding var isPresented: Bool
    @State private var showConfirmation: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "trash.circle.fill")
                    .font(.title)
                    .foregroundColor(.green)
                Text("Storage Cleanup")
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

            Divider()

            if cacheManager.isScanning {
                // Scanning state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Scanning for cache files...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if cacheManager.isCleaning {
                // Cleaning state with live file log
                VStack(spacing: 12) {
                    // Progress section
                    VStack(spacing: 8) {
                        HStack {
                            Text("Cleaning...")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(cacheManager.cleaningProgress * 100))%")
                                .font(.headline.monospacedDigit())
                                .foregroundColor(.green)
                        }

                        ProgressView(value: cacheManager.cleaningProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    Divider()

                    // Live file deletion log
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.secondary)
                            Text("Deleting files...")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(cacheManager.deletedFiles.count) files")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)

                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 2) {
                                    ForEach(cacheManager.deletedFiles) { entry in
                                        HStack(spacing: 6) {
                                            Image(systemName: "trash")
                                                .font(.caption2)
                                                .foregroundColor(.red.opacity(0.7))
                                            Text(entry.path)
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                            Spacer()
                                            Text(CacheManager.formatBytes(entry.size))
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .id(entry.id)
                                    }
                                }
                            }
                            .frame(maxHeight: .infinity)
                            .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                            .cornerRadius(6)
                            .padding(.horizontal)
                            .onChange(of: cacheManager.deletedFiles.count) {
                                if let lastEntry = cacheManager.deletedFiles.last {
                                    withAnimation(.easeOut(duration: 0.1)) {
                                        proxy.scrollTo(lastEntry.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }

                    // Currently deleting indicator
                    if !cacheManager.currentlyDeleting.isEmpty {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text(cacheManager.currentlyDeleting)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
            } else if cacheManager.cleaningComplete {
                // Completion state
                VStack(spacing: 12) {
                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)

                    Text("Cleanup Complete!")
                        .font(.headline)

                    Text("Freed \(CacheManager.formatBytes(cacheManager.lastCleanedAmount))")
                        .font(.title2)
                        .foregroundColor(.green)

                    Text("\(cacheManager.deletedFiles.count) files deleted")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    // Show summary of deleted files
                    if !cacheManager.deletedFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Deleted files:")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 1) {
                                    ForEach(cacheManager.deletedFiles.suffix(50)) { entry in
                                        HStack(spacing: 6) {
                                            Text(entry.path)
                                                .font(.system(size: 9, design: .monospaced))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                            Spacer()
                                            Text(CacheManager.formatBytes(entry.size))
                                                .font(.system(size: 9, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 1)
                                    }
                                }
                            }
                            .frame(height: 100)
                            .background(Color(NSColor.textBackgroundColor).opacity(0.3))
                            .cornerRadius(6)
                            .padding(.horizontal)
                        }
                    }

                    Button("Done") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .padding(.top, 8)
                    .padding(.bottom)
                }
            } else {
                // Summary view
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Warning banner
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("These files are safe to delete")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)

                        // Breakdown
                        VStack(spacing: 2) {
                            CacheRowView(
                                icon: "globe",
                                title: "Browser Cache",
                                size: cacheManager.cacheBreakdown.browserCache,
                                color: .blue
                            )

                            CacheRowView(
                                icon: "app.badge",
                                title: "App Cache",
                                size: cacheManager.cacheBreakdown.appCache,
                                color: .purple
                            )

                            CacheRowView(
                                icon: "hammer.fill",
                                title: "Xcode Data",
                                size: cacheManager.cacheBreakdown.xcodeData,
                                color: .cyan
                            )

                            CacheRowView(
                                icon: "doc.text",
                                title: "Logs",
                                size: cacheManager.cacheBreakdown.logs,
                                color: .orange
                            )

                            CacheRowView(
                                icon: "clock.arrow.circlepath",
                                title: "Temporary Files",
                                size: cacheManager.cacheBreakdown.tempFiles,
                                color: .gray
                            )
                        }

                        Divider()
                            .padding(.vertical, 4)

                        // Total
                        HStack {
                            Image(systemName: "sum")
                                .font(.title3)
                                .foregroundColor(.green)
                                .frame(width: 24)
                            Text("Total Cleanable")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(CacheManager.formatBytes(cacheManager.cacheBreakdown.total))
                                .font(.title3.weight(.bold).monospacedDigit())
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding()
                }

                // Action buttons
                VStack(spacing: 12) {
                    Divider()

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            isPresented = false
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)

                        Button(action: {
                            showConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Clean Now")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .frame(maxWidth: .infinity)
                        .disabled(cacheManager.cacheBreakdown.total == 0)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
        .frame(width: 380, height: 480)
        .background(Color(NSColor.windowBackgroundColor))
        .alert("Clean Cache?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clean Now", role: .destructive) {
                cacheManager.cleanCaches { _ in }
            }
        } message: {
            Text("Are you sure you want to clean \(CacheManager.formatBytes(cacheManager.cacheBreakdown.total)) of cache files? This action cannot be undone.")
        }
        .onAppear {
            cacheManager.scanCaches()
        }
    }
}

struct CacheRowView: View {
    let icon: String
    let title: String
    let size: UInt64
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)

            Spacer()

            Text(CacheManager.formatBytes(size))
                .font(.subheadline.monospacedDigit())
                .foregroundColor(size > 0 ? .primary : .secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
}

// Compact button for the main menu
struct CleanCacheButton: View {
    @ObservedObject var cacheManager: CacheManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "trash.circle.fill")
                    .foregroundColor(.green)
                Text("Clean Cache")
                Spacer()
                if cacheManager.isScanning {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if cacheManager.cacheBreakdown.total > 0 {
                    Text(CacheManager.formatBytes(cacheManager.cacheBreakdown.total))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            // Scan for cache sizes when view appears
            if cacheManager.cacheBreakdown.total == 0 && !cacheManager.isScanning {
                cacheManager.scanCaches()
            }
        }
    }
}

#Preview {
    CacheCleanupView(cacheManager: CacheManager(), isPresented: .constant(true))
}
