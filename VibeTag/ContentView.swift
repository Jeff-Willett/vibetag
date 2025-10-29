//
//  ContentView.swift
//  VibeTag
//
//  Created by Jeff Willett on 10/28/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    // Available tags for the project
    private let availableTags = ["Arc", "KP", "TMP", "PRG", "HW-SGR", "RPLY", "Other1"]

    // State for current file and tags
    @State private var currentFilePath: String = "No file selected"
    @State private var currentFileURL: URL?
    @State private var appliedTags: Set<String> = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var statusMessage: String = ""

    // Auto-refresh timer
    @State private var autoRefreshTimer: Timer?
    @State private var lastDetectedFilePath: String?
    @State private var isAutoRefreshEnabled: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Header with file info
            headerView

            Divider()

            // Search/Filter field
            searchField

            // Tags list
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(filteredTags, id: \.self) { tag in
                        tagRow(tag: tag)
                    }
                }
                .padding()
            }

            Divider()

            // Footer with actions
            footerView
        }
        .frame(width: 320, height: 450)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            // Auto-detect IINA file on first appear
            detectCurrentFile()
            // Start auto-refresh timer
            startAutoRefresh()
        }
        .onDisappear {
            // Stop timer when view disappears
            stopAutoRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .detectIINAFile)) { _ in
            // Detect file when triggered by global shortcut
            detectCurrentFile()
        }
    }

    // MARK: - View Components

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(.accentColor)
                Text("TagManager NEW BUILD")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            Text(currentFilePath)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)
                .truncationMode(.middle)

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search tags...", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func tagRow(tag: String) -> some View {
        let isApplied = appliedTags.contains(tag)

        return Button(action: {
            toggleTag(tag)
        }) {
            HStack {
                Image(systemName: isApplied ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isApplied ? .accentColor : .secondary)
                    .imageScale(.large)

                Text(tag)
                    .font(.body)
                    .foregroundColor(isApplied ? .primary : .secondary)

                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isApplied ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isApplied ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var footerView: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: {
                    isAutoRefreshEnabled.toggle()
                    if isAutoRefreshEnabled {
                        startAutoRefresh()
                    } else {
                        stopAutoRefresh()
                    }
                }) {
                    Image(systemName: isAutoRefreshEnabled ? "arrow.clockwise.circle.fill" : "arrow.clockwise.circle")
                        .foregroundColor(isAutoRefreshEnabled ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help(isAutoRefreshEnabled ? "Auto-refresh enabled" : "Auto-refresh disabled")

                Button("Refresh") {
                    detectCurrentFile()
                }
                .keyboardShortcut("r", modifiers: .command)

                Spacer()

                Button("Select File...") {
                    selectFileManually()
                }
            }

            // Debug info
            if !statusMessage.isEmpty {
                Text("Debug: Check Console for detailed logs")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Computed Properties

    private var filteredTags: [String] {
        if searchText.isEmpty {
            return availableTags
        }
        return availableTags.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: - Actions

    private func detectCurrentFile() {
        isLoading = true
        currentFilePath = "Detecting IINA..."
        statusMessage = "Connecting to IINA mpv socket..."

        IINAConnector.shared.getCurrentlyPlayingFile { [self] result in
            isLoading = false

            switch result {
            case .success(let filePath):
                // Successfully got file from IINA
                lastDetectedFilePath = filePath
                currentFilePath = (filePath as NSString).lastPathComponent
                currentFileURL = URL(fileURLWithPath: filePath)
                statusMessage = "Connected to IINA ✓"

                // Load tags from this file
                loadTagsFromFile(filePath)

            case .failure(let error):
                // Failed to get file from IINA - show helpful message
                currentFilePath = "IINA not detected"
                statusMessage = error.localizedDescription

                // Check if we have a cached file path
                if let cachedPath = IINAConnector.shared.getCachedFilePath() {
                    lastDetectedFilePath = cachedPath
                    currentFilePath = (cachedPath as NSString).lastPathComponent + " (cached)"
                    currentFileURL = URL(fileURLWithPath: cachedPath)
                    statusMessage = "Using last known file"
                    loadTagsFromFile(cachedPath)
                }
            }
        }
    }

    private func selectFileManually() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        panel.message = "Select a video file to manage its Finder tags"
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            // Start accessing the security-scoped resource
            let didStartAccessing = url.startAccessingSecurityScopedResource()

            currentFilePath = url.lastPathComponent
            currentFileURL = url
            statusMessage = "File selected manually"
            loadTagsFromFile(url.path)

            // Keep the security scope active
            if didStartAccessing {
                print("DEBUG: Security-scoped resource access granted for \(url.path)")
            }
        }
    }

    private func toggleTag(_ tag: String) {
        // Update local state
        if appliedTags.contains(tag) {
            appliedTags.remove(tag)
        } else {
            appliedTags.insert(tag)
        }

        // Write tags to file immediately
        guard let fileURL = currentFileURL else {
            statusMessage = "No file selected"
            return
        }

        saveTagsToFile(fileURL.path)
    }

    private func loadTagsFromFile(_ filePath: String) {
        let result = FinderTagManager.shared.readTags(from: filePath)

        switch result {
        case .success(let tags):
            // Filter to only show tags that are in our available list
            let relevantTags = tags.filter { availableTags.contains($0) }
            appliedTags = Set(relevantTags)

            if tags.isEmpty {
                statusMessage = "No tags on this file"
            } else if relevantTags.isEmpty && !tags.isEmpty {
                statusMessage = "File has \(tags.count) tag(s), none matching our list"
            } else {
                statusMessage = "Loaded \(relevantTags.count) tag(s)"
            }

        case .failure(let error):
            appliedTags = []
            statusMessage = "Error: \(error.localizedDescription)"
        }
    }

    private func saveTagsToFile(_ filePath: String) {
        let tagsArray = Array(appliedTags)
        let result = FinderTagManager.shared.writeTags(tagsArray, to: filePath)

        switch result {
        case .success:
            statusMessage = "Tags saved ✓"

            // Clear status message after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if statusMessage == "Tags saved ✓" {
                    statusMessage = ""
                }
            }

        case .failure(let error):
            statusMessage = "Error: Permission denied. Grant Full Disk Access in Settings."
        }
    }

    // MARK: - Auto-Refresh

    private func startAutoRefresh() {
        print("DEBUG: Starting auto-refresh timer")
        stopAutoRefresh() // Stop any existing timer

        // Create a timer that fires every 2 seconds
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [self] _ in
            checkForFileChange()
        }
    }

    private func stopAutoRefresh() {
        print("DEBUG: Stopping auto-refresh timer")
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }

    private func checkForFileChange() {
        // Don't check if already loading
        guard !isLoading else { return }

        print("DEBUG: Auto-refresh checking IINA...")

        IINAConnector.shared.getCurrentlyPlayingFile { [self] result in
            switch result {
            case .success(let filePath):
                // Check if file path has changed
                if filePath != lastDetectedFilePath {
                    print("DEBUG: File changed from '\(lastDetectedFilePath ?? "none")' to '\(filePath)'")
                    lastDetectedFilePath = filePath

                    // Update UI with new file
                    currentFilePath = (filePath as NSString).lastPathComponent
                    currentFileURL = URL(fileURLWithPath: filePath)
                    statusMessage = "Auto-detected new file ✓"

                    // Load tags from the new file
                    loadTagsFromFile(filePath)
                } else {
                    // Same file, no change
                    print("DEBUG: Same file, no change")
                }

            case .failure(let error):
                // Only update if we had a file before
                if lastDetectedFilePath != nil {
                    print("DEBUG: Lost IINA connection: \(error.localizedDescription)")
                    lastDetectedFilePath = nil
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 320, height: 450)
}
