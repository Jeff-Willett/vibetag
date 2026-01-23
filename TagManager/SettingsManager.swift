//
//  SettingsManager.swift
//  TagManager
//
//  Created by Jeff Willett on 10/28/25.
//
import Foundation
import Combine
import SwiftUI

struct TagConfig: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    var isEnabled: Bool
}

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var tagConfigs: [TagConfig] = [] {
        didSet {
            saveTags()
        }
    }
    
    // Default tags if none are saved
    private let defaultTags = ["Arc", "KP", "TMP", "PRG", "HW-SGR", "RPLY", "Other1"]
    private let storageKey = "TagConfigs"
    
    var enabledTags: [String] {
        tagConfigs.filter { $0.isEnabled }.map { $0.name }
    }
    
    private init() {
        loadTags()
    }
    
    private func loadTags() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([TagConfig].self, from: data) {
            self.tagConfigs = decoded
        } else {
            // First run: populate with defaults
            self.tagConfigs = defaultTags.map { TagConfig(name: $0, isEnabled: true) }
        }
    }
    
    private func saveTags() {
        if let encoded = try? JSONEncoder().encode(tagConfigs) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    func moveTags(from source: IndexSet, to destination: Int) {
        tagConfigs.move(fromOffsets: source, toOffset: destination)
    }
    
    func resetToDefaults() {
         self.tagConfigs = defaultTags.map { TagConfig(name: $0, isEnabled: true) }
    }
}
