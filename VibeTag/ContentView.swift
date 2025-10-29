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
    @State private var currentFileSize: String = ""
    @State private var appliedTags: Set<String> = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var statusMessage: String = ""

    // Auto-refresh timer
    @State private var autoRefreshTimer: Timer?
    @State private var lastDetectedFilePath: String?
    @State private var isAutoRefreshEnabled: Bool = true

    var body: some View {
        VStack(spacing: 1) {
            // File size
            if !currentFileSize.isEmpty {
                Text(currentFileSize)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.top, 0)
            }

            // Minimal file info
            Text(currentFilePath)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 8)

            // Tags grid - ultra compact
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6)
            ], spacing: 6) {
                ForEach(availableTags, id: \.self) { tag in
                    tagButton(tag: tag)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 2)

            // Minimal footer with just refresh controls
            HStack(spacing: 8) {
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
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)

                Button(action: {
                    detectCurrentFile()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 2)
            .padding(.bottom, 0)
        }
        .frame(width: 220, height: 160)
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

    private func tagButton(tag: String) -> some View {
        let isApplied = appliedTags.contains(tag)

        return Button(action: {
            toggleTag(tag)
        }) {
            Text(tag)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isApplied ? Color.blue : Color.black)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed Properties (removed - using availableTags directly)

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

                // Get file size
                currentFileSize = getFileSize(filePath)

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

    // MARK: - Helper Functions

    private func getFileSize(_ filePath: String) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
            if let fileSize = attributes[.size] as? Int64 {
                return formatBytes(fileSize)
            }
        } catch {
            print("DEBUG: Could not get file size: \(error)")
        }
        return ""
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let gigabyte: Double = 1024 * 1024 * 1024
        let megabyte: Double = 1024 * 1024

        if bytes >= Int64(gigabyte) {
            let gb = Double(bytes) / gigabyte
            return String(format: "%.2f GB", gb)
        } else if bytes >= Int64(megabyte) {
            let mb = Double(bytes) / megabyte
            return String(format: "%.0f MB", mb)
        } else {
            let kb = Double(bytes) / 1024
            return String(format: "%.0f KB", kb)
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

                    // Get file size
                    currentFileSize = getFileSize(filePath)

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
