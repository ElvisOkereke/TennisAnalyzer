//
//  TennisAnalyzerApp.swift
//  TennisAnalyzer
//
//  Created by m1 on 04/08/2026.
//

import SwiftUI
import SwiftData

@main
struct TennisAnalyzerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: ServeRecord.self)
    }
}
