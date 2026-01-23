//
//  ContentView.swift
//  TagManager
//
//  Created by Jeff Willett on 10/28/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    // Available tags for the project
    @ObservedObject var settingsManager = SettingsManager.shared

    // State for current file and tags
    @State private var currentFilePath: String = "No file selected"
    @State private var currentFileURL: URL?
    @State private var currentFileSize: String = ""
    @State private var appliedTags: Set<String> = []
    @State private var isLoading: Bool = false

    // Auto-refresh timer
    @State private var autoRefreshTimer: Timer?
    @State private var lastDetectedFilePath: String?
    @State private var isAutoRefreshEnabled: Bool = true
    @State private var showingSettings = false

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
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
                .padding(.horizontal, 8)
                .onHover { hovering in
                    if hovering {
                        WindowManager.shared.showTooltip(text: currentFilePath)
                    } else {
                        WindowManager.shared.hideTooltip()
                    }
                }

            // Tags grid - ultra compact
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 60), spacing: 6)
            ], spacing: 6) {
                ForEach(settingsManager.enabledTags, id: \.self) { tag in
                    tagButton(tag: tag)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 2)

            Spacer(minLength: 0)

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
                    showingSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                }

                Button(action: {
                    detectCurrentFile()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)



                // Skip Previous
                Button(action: {
                    skipToPreviousFile()
                }) {
                    Image(systemName: "backward.end.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)

                // Skip Next
                Button(action: {
                    skipToNextFile()
                }) {
                    Image(systemName: "forward.end.fill")
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
        .frame(minWidth: 80, maxWidth: .infinity, minHeight: 60, maxHeight: .infinity)
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

        IINAConnector.shared.getCurrentlyPlayingFile { [self] result in
            isLoading = false

            switch result {
            case .success(let filePath):
                lastDetectedFilePath = filePath
                currentFilePath = (filePath as NSString).lastPathComponent
                currentFileURL = URL(fileURLWithPath: filePath)
                currentFileSize = getFileSize(filePath)
                loadTagsFromFile(filePath)

            case .failure(_):
                currentFilePath = "IINA not detected"

                // Check if we have a cached file path
                if let cachedPath = IINAConnector.shared.getCachedFilePath() {
                    lastDetectedFilePath = cachedPath
                    currentFilePath = (cachedPath as NSString).lastPathComponent + " (cached)"
                    currentFileURL = URL(fileURLWithPath: cachedPath)
                    loadTagsFromFile(cachedPath)
                }
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
        guard let fileURL = currentFileURL else { return }
        saveTagsToFile(fileURL.path)
    }

    private func loadTagsFromFile(_ filePath: String) {
        if let tags = try? FinderTagManager.shared.readTags(from: filePath).get() {
            let relevantTags = tags.filter { settingsManager.enabledTags.contains($0) }
            appliedTags = Set(relevantTags)
        } else {
            appliedTags = []
        }
    }

    private func saveTagsToFile(_ filePath: String) -> Void {
        let tagsArray = Array(appliedTags)
        _ = FinderTagManager.shared.writeTags(tagsArray, to: filePath)
    }

    // MARK: - Video Skipping Logic

    private func skipToNextFile() {
        IINAConnector.shared.nextTrack()
    }

    private func skipToPreviousFile() {
        IINAConnector.shared.previousTrack()
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
        stopAutoRefresh() // Stop any existing timer

        // Create a timer that fires every 2 seconds
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [self] _ in
            checkForFileChange()
        }
    }

    private func stopAutoRefresh() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }

    private func checkForFileChange() {
        guard !isLoading else { return }

        IINAConnector.shared.getCurrentlyPlayingFile { [self] result in
            switch result {
            case .success(let filePath):
                if filePath != lastDetectedFilePath {
                    lastDetectedFilePath = filePath
                    currentFilePath = (filePath as NSString).lastPathComponent
                    currentFileURL = URL(fileURLWithPath: filePath)
                    currentFileSize = getFileSize(filePath)
                    loadTagsFromFile(filePath)
                }

            case .failure(_):
                if lastDetectedFilePath != nil {
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
