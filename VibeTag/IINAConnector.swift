//
//  IINAConnector.swift
//  VibeTag
//
//  Handles connection to IINA media player via AppleScript
//

import Foundation
import AppKit

enum IINAError: Error {
    case iinaNotRunning
    case noFileLoaded
    case appleScriptError
    case invalidPath

    var localizedDescription: String {
        switch self {
        case .iinaNotRunning:
            return "IINA is not running"
        case .noFileLoaded:
            return "No file currently playing in IINA"
        case .appleScriptError:
            return "Failed to communicate with IINA"
        case .invalidPath:
            return "Invalid file path from IINA"
        }
    }
}

class IINAConnector {
    static let shared = IINAConnector()

    private var cachedFilePath: String?

    private init() {}

    /// Attempts to get the currently playing file from IINA via AppleScript
    func getCurrentlyPlayingFile(completion: @escaping (Result<String, IINAError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Check if IINA is running
            print("DEBUG: Checking if IINA is running...")
            guard self.isIINARunning() else {
                print("DEBUG: IINA is not running")
                DispatchQueue.main.async {
                    completion(.failure(.iinaNotRunning))
                }
                return
            }
            print("DEBUG: IINA is running")

            // Use AppleScript to get the current file path
            do {
                print("DEBUG: Attempting to query IINA history...")
                let filePath = try self.queryIINAViaAppleScript()
                print("DEBUG: Successfully got file path: \(filePath)")
                self.cachedFilePath = filePath

                DispatchQueue.main.async {
                    completion(.success(filePath))
                }
            } catch let error as IINAError {
                print("DEBUG: IINAError: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            } catch {
                print("DEBUG: Unknown error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(.appleScriptError))
                }
            }
        }
    }

    /// Check if IINA is currently running
    private func isIINARunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { $0.bundleIdentifier == "com.colliderli.iina" }
    }

    /// Query IINA using GUI automation (clicks "Show in Finder" menu) via helper script
    private func queryIINAViaAppleScript() throws -> String {
        print("DEBUG: Attempting to get file from IINA via helper script")

        // Call the external helper script which runs outside the sandbox
        let scriptPath = "/Users/jpw/Library/Mobile Documents/com~apple~CloudDocs/Code&Scripts/vsc-xcode/vibetag/TagManager/get_iina_file.sh"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            if process.terminationStatus != 0 {
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                print("DEBUG: Helper script error: \(errorMessage)")

                if errorMessage.contains("not running") {
                    throw IINAError.iinaNotRunning
                } else if errorMessage.contains("Finder") || errorMessage.contains("menu") {
                    throw IINAError.noFileLoaded
                }

                throw IINAError.appleScriptError
            }

            guard let filePath = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !filePath.isEmpty else {
                print("DEBUG: No file path returned from helper script")
                throw IINAError.invalidPath
            }

            print("DEBUG: Got file path from IINA via helper script: \(filePath)")

            // Verify the file exists
            guard FileManager.default.fileExists(atPath: filePath) else {
                throw IINAError.invalidPath
            }

            return filePath
        } catch {
            print("DEBUG: Failed to run helper script: \(error)")
            throw IINAError.appleScriptError
        }
    }

    /// Returns the last known file path (cached)
    func getCachedFilePath() -> String? {
        return cachedFilePath
    }

    /// Clears the cached file path
    func clearCache() {
        cachedFilePath = nil
    }
}
