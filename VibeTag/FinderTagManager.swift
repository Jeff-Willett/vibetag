//
//  FinderTagManager.swift
//  VibeTag
//
//  Manages reading and writing Finder tags using xattr
//

import Foundation

enum FinderTagError: Error {
    case fileNotFound
    case readFailed
    case writeFailed
    case parseError
    case invalidData

    var localizedDescription: String {
        switch self {
        case .fileNotFound:
            return "File not found"
        case .readFailed:
            return "Failed to read tags from file"
        case .writeFailed:
            return "Failed to write tags to file"
        case .parseError:
            return "Failed to parse tag data"
        case .invalidData:
            return "Invalid tag data format"
        }
    }
}

class FinderTagManager {
    static let shared = FinderTagManager()

    private init() {}

    /// Read Finder tags from a file
    func readTags(from filePath: String) -> Result<[String], FinderTagError> {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: filePath) else {
            print("DEBUG FinderTagManager: File not found: \(filePath)")
            return .failure(.fileNotFound)
        }

        // Execute xattr command to read tags
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-p", "com.apple.metadata:_kMDItemUserTags", filePath]

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            // If exit code is not 0, the attribute doesn't exist (no tags)
            if process.terminationStatus != 0 {
                print("DEBUG FinderTagManager: No tags attribute on file (exit code: \(process.terminationStatus))")
                return .success([]) // No tags is valid - return empty array
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            print("DEBUG FinderTagManager: Read \(data.count) bytes from xattr")

            // If data is empty or too small, treat as no tags
            if data.count <= 1 {
                print("DEBUG FinderTagManager: Empty or corrupt tag data, treating as no tags")
                return .success([])
            }

            // Try to parse as plist (could be XML or binary)
            do {
                let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
                print("DEBUG FinderTagManager: Parsed plist type: \(type(of: plist))")

                if let tags = plist as? [String] {
                    // Simple array of tag names (XML format or JXA format without colors)
                    print("DEBUG FinderTagManager: Successfully parsed \(tags.count) tags: \(tags)")
                    return .success(tags)
                } else if let tagObjects = plist as? [Any] {
                    // Could be array with color codes or mixed types
                    // Extract just the string tag names, filtering out numbers
                    let tagNames = tagObjects.compactMap { obj -> String? in
                        if let tagName = obj as? String {
                            // Could be "TagName\n6" format or just "TagName"
                            if let newlineIndex = tagName.firstIndex(of: "\n") {
                                return String(tagName[..<newlineIndex])
                            }
                            return tagName
                        }
                        return nil
                    }
                    print("DEBUG FinderTagManager: Extracted \(tagNames.count) tag names from mixed array: \(tagNames)")
                    return .success(tagNames)
                } else if let dict = plist as? [String: Any], dict.isEmpty {
                    // Empty dictionary means no tags
                    print("DEBUG FinderTagManager: Empty dictionary, treating as no tags")
                    return .success([])
                } else {
                    print("DEBUG FinderTagManager: Plist is not a supported format: \(plist)")
                    return .failure(.parseError)
                }
            } catch {
                print("DEBUG FinderTagManager: Plist parse error: \(error)")
                return .failure(.parseError)
            }
        } catch {
            print("DEBUG FinderTagManager: Read error: \(error)")
            return .failure(.readFailed)
        }
    }

    /// Write Finder tags to a file
    func writeTags(_ tags: [String], to filePath: String) -> Result<Void, FinderTagError> {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: filePath) else {
            print("DEBUG FinderTagManager: Write - File not found: \(filePath)")
            return .failure(.fileNotFound)
        }

        // If tags array is empty, remove the attribute entirely
        if tags.isEmpty {
            print("DEBUG FinderTagManager: Removing tags (empty array)")
            return removeTags(from: filePath)
        }

        print("DEBUG FinderTagManager: Writing tags: \(tags)")

        // Create XML plist from tags
        guard let plistData = createXMLPlist(from: tags) else {
            print("DEBUG FinderTagManager: Failed to create XML plist")
            return .failure(.invalidData)
        }

        // Try setxattr first
        let attrName = "com.apple.metadata:_kMDItemUserTags"
        let result = plistData.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> Int32 in
            return setxattr(
                filePath,
                attrName,
                bytes.baseAddress,
                plistData.count,
                0,
                0
            )
        }

        if result == 0 {
            print("DEBUG FinderTagManager: Successfully wrote tags using setxattr")
            return .success(())
        }

        // If setxattr failed (permission denied), try using osascript as fallback
        let errorCode = errno
        print("DEBUG FinderTagManager: setxattr failed with errno \(errorCode), trying osascript fallback")

        return writeTagsViaOsascript(tags, to: filePath)
    }

    /// Fallback method using osascript (runs with user permissions)
    private func writeTagsViaOsascript(_ tags: [String], to filePath: String) -> Result<Void, FinderTagError> {
        print("DEBUG FinderTagManager: Trying osascript with tags: \(tags)")

        // Build JXA script - need to properly escape the tags array
        let tagsJSON = tags.map { "\"\($0)\"" }.joined(separator: ", ")
        let jxaScript = """
        ObjC.import("Foundation");
        const filePath = "\(filePath)";
        const tags = [\(tagsJSON)];
        const fileURL = $.NSURL.fileURLWithPath(filePath);
        const tagArray = $.NSArray.arrayWithArray(tags);
        const result = fileURL.setResourceValueForKeyError(tagArray, $.NSURLTagNamesKey, null);
        console.log("JXA Result: " + result);
        """

        print("DEBUG FinderTagManager: JXA script:\n\(jxaScript)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-l", "JavaScript", "-e", jxaScript]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let outputString = String(data: outputData, encoding: .utf8) ?? ""
            print("DEBUG FinderTagManager: osascript output: \(outputString)")

            if process.terminationStatus == 0 {
                print("DEBUG FinderTagManager: Successfully wrote tags via osascript")
                return .success(())
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? "unknown"
                print("DEBUG FinderTagManager: osascript failed: \(errorString)")
                return .failure(.writeFailed)
            }
        } catch {
            print("DEBUG FinderTagManager: osascript process error: \(error)")
            return .failure(.writeFailed)
        }
    }

    /// Remove all tags from a file
    private func removeTags(from filePath: String) -> Result<Void, FinderTagError> {
        let attrName = "com.apple.metadata:_kMDItemUserTags"
        let result = removexattr(filePath, attrName, 0)

        if result == 0 {
            print("DEBUG FinderTagManager: Successfully removed tags")
            return .success(())
        } else {
            let errorCode = errno
            // ENOATTR (93) means attribute doesn't exist, which is fine
            if errorCode == 93 {
                print("DEBUG FinderTagManager: No tags to remove (attribute doesn't exist)")
                return .success(())
            }

            let errorMessage = String(cString: strerror(errorCode))
            print("DEBUG FinderTagManager: removexattr failed with errno \(errorCode): \(errorMessage)")
            return .failure(.writeFailed)
        }
    }

    // MARK: - Plist Parsing

    /// Parse XML plist data from xattr output
    private func parseXMLPlist(_ data: Data) -> Result<[String], FinderTagError> {
        do {
            guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String] else {
                print("DEBUG FinderTagManager: XML plist is not a string array")
                return .failure(.parseError)
            }

            // Tags in XML format are just plain strings like "Arc", "KP", etc.
            // No need to parse out color codes
            print("DEBUG FinderTagManager: Successfully parsed \(plist.count) tags from XML: \(plist)")
            return .success(plist)
        } catch {
            print("DEBUG FinderTagManager: XML parse error: \(error)")
            return .failure(.parseError)
        }
    }

    /// Parse binary plist data from xattr output (hex-encoded)
    private func parseBinaryPlist(_ data: Data) -> Result<[String], FinderTagError> {
        // The xattr output is hex-encoded binary plist
        // First convert hex string to binary data
        guard let hexString = String(data: data, encoding: .utf8) else {
            return .failure(.parseError)
        }

        // Remove whitespace and newlines
        let cleanHex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let binaryData = hexStringToData(cleanHex) else {
            return .failure(.parseError)
        }

        // Parse the binary plist
        do {
            guard let plist = try PropertyListSerialization.propertyList(from: binaryData, format: nil) as? [String] else {
                return .failure(.parseError)
            }

            // Tags are stored as "TagName\n6" where 6 is the color code
            // We need to extract just the tag name
            let tagNames = plist.compactMap { tag -> String? in
                if let newlineIndex = tag.firstIndex(of: "\n") {
                    return String(tag[..<newlineIndex])
                }
                return tag
            }

            return .success(tagNames)
        } catch {
            return .failure(.parseError)
        }
    }

    /// Create XML plist data from tag names
    private func createXMLPlist(from tags: [String]) -> Data? {
        do {
            // Simple array of tag names - no color codes needed for XML format
            let plistData = try PropertyListSerialization.data(
                fromPropertyList: tags,
                format: .xml,
                options: 0
            )
            return plistData
        } catch {
            print("DEBUG FinderTagManager: Error creating XML plist: \(error)")
            return nil
        }
    }

    /// Create binary plist data from tag names (legacy format)
    private func createBinaryPlist(from tags: [String]) -> Data? {
        // Tags need to be in format "TagName\n6" where 6 is the color code
        // Using 0 for no color (gray)
        let tagStrings = tags.map { "\($0)\n0" }

        do {
            let plistData = try PropertyListSerialization.data(
                fromPropertyList: tagStrings,
                format: .binary,
                options: 0
            )
            return plistData
        } catch {
            return nil
        }
    }

    /// Convert hex string to Data
    private func hexStringToData(_ hex: String) -> Data? {
        var data = Data()
        var hex = hex

        // Remove any spaces or newlines
        hex = hex.replacingOccurrences(of: " ", with: "")
        hex = hex.replacingOccurrences(of: "\n", with: "")

        guard hex.count % 2 == 0 else {
            return nil
        }

        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            let byteString = hex[index..<nextIndex]
            guard let byte = UInt8(byteString, radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }

        return data
    }
}
