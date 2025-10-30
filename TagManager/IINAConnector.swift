//
//  IINAConnector.swift
//  TagManager
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

    /// Attempts to get the currently playing file from IINA
    func getCurrentlyPlayingFile(completion: @escaping (Result<String, IINAError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Check if IINA is running
            guard self.isIINARunning() else {
                DispatchQueue.main.async {
                    completion(.failure(.iinaNotRunning))
                }
                return
            }

            // Get the current file path using lsof
            do {
                let filePath = try self.getFilePathFromIINA()
                self.cachedFilePath = filePath

                DispatchQueue.main.async {
                    completion(.success(filePath))
                }
            } catch let error as IINAError {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            } catch {
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

    /// Get currently playing file from IINA using lsof
    private func getFilePathFromIINA() throws -> String {
        // Get the helper script from app bundle
        guard let scriptPath = Bundle.main.path(forResource: "get_iina_file", ofType: "sh") else {
            print("ERROR: Could not find get_iina_file.sh in app bundle")
            throw IINAError.appleScriptError
        }

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

                if errorMessage.contains("not running") {
                    throw IINAError.iinaNotRunning
                } else if errorMessage.contains("No video file") {
                    throw IINAError.noFileLoaded
                }

                throw IINAError.appleScriptError
            }

            guard let filePath = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !filePath.isEmpty else {
                throw IINAError.invalidPath
            }

            // Verify the file exists
            guard FileManager.default.fileExists(atPath: filePath) else {
                throw IINAError.invalidPath
            }

            return filePath
        } catch {
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
