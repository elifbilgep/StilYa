//
//  DebugLogView.swift
//  StilYa
//
//  In-app log viewer — shake gesture ile açılır.
//

import SwiftUI

struct DebugLogView: View {
    var onClose: (() -> Void)?
    @State private var logManager = DebugLogManager.shared
    @State private var selectedCategory: DebugLogEntry.LogCategory?
    @State private var showCopiedToast = false

    private var filteredEntries: [DebugLogEntry] {
        var result = logManager.entries
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button {
                    onClose?()
                } label: {
                    Text(L10n.debugClose)
                        .foregroundColor(.blue)
                }

                Spacer()

                Text("Logs (\(logManager.entries.count))")
                    .font(.headline)

                Spacer()

                Menu {
                    Button {
                        UIPasteboard.general.string = logManager.exportText
                        showCopiedToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopiedToast = false
                        }
                    } label: {
                        Label(L10n.debugCopy, systemImage: "doc.on.doc")
                    }

                    Button(role: .destructive) {
                        logManager.clear()
                    } label: {
                        Label(L10n.debugClear, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Category filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "All", isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(DebugLogEntry.LogCategory.allCases, id: \.self) { category in
                        let count = logManager.entries.filter { $0.category == category }.count
                        if count > 0 {
                            FilterChip(
                                title: "\(category.rawValue) (\(count))",
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            Divider()

            // Log entries
            if filteredEntries.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(L10n.debugNoLogs)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(filteredEntries) { entry in
                                LogEntryRow(entry: entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .onAppear {
                        if let last = filteredEntries.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            if showCopiedToast {
                Text(L10n.debugCopied)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 8)
            }
        }
        .background(Color(.systemBackground))
        .preferredColorScheme(.dark)
    }
}

// MARK: - Log Entry Row

private struct LogEntryRow: View {
    let entry: DebugLogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(entry.formattedTime)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 75, alignment: .leading)

            Image(systemName: entry.category.icon)
                .font(.system(size: 9))
                .foregroundColor(entry.category.color)
                .frame(width: 14)

            Text(entry.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
