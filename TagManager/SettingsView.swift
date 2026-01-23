//
//  SettingsView.swift
//  TagManager
//
//  Created by Jeff Willett on 10/28/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Tag Settings")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Tag List
            List {
                Section(header: Text("AVAILABLE TAGS (DRAG TO REORDER)")) {
                    ForEach($settingsManager.tagConfigs) { $config in
                        HStack {
                            Toggle("", isOn: $config.isEnabled)
                                .labelsHidden()
                            Text(config.name)
                            Spacer()
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.gray)
                        }
                    }
                    .onMove(perform: settingsManager.moveTags)
                }
            }
            .listStyle(InsetListStyle())
            
            Divider()
            
            // Footer
            HStack {
                Button("Reset to Defaults") {
                    settingsManager.resetToDefaults()
                }
                Spacer()
            }
            .padding()
        }
        .frame(width: 300, height: 400)
    }
}

#Preview {
    SettingsView()
}
