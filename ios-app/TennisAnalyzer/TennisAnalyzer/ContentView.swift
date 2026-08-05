//
//  ContentView.swift
//  TennisAnalyzer
//
//  Created by m1 on 04/08/2026.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var isRecording = false
    @State private var playbackURL: URL?
    @State private var showHandednessPrompt = false
    @State private var showHandednessSettings = false

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "tennisball.fill")
                    .imageScale(.large)
                    .foregroundStyle(.tint)

                Button {
                    isRecording = true
                } label: {
                    Label("Record Serve", systemImage: "video.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!cameraAvailable)

                if !cameraAvailable {
                    Text("Camera isn't available in the Simulator — use Upload Clip to test playback, or run on a real device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                ClipImportButton { url in
                    playbackURL = ClipStorage.persist(url)
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    HistoryListView()
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("TennisAnalyzer")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showHandednessSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .fullScreenCover(isPresented: $isRecording) {
                CameraRecorderView { url in
                    isRecording = false
                    if let url {
                        playbackURL = ClipStorage.persist(url)
                    }
                }
                .ignoresSafeArea()
            }
            .navigationDestination(item: $playbackURL) { url in
                ClipPlayerView(url: url)
            }
            // First-run only: Phase 2's auto-detection needs to know which
            // side is the hitting arm before it can pick the right joints.
            .sheet(isPresented: $showHandednessPrompt) {
                HandednessPromptView { _ in
                    showHandednessPrompt = false
                }
                .interactiveDismissDisabled()
            }
            .sheet(isPresented: $showHandednessSettings) {
                HandednessPromptView { _ in
                    showHandednessSettings = false
                }
            }
            .onAppear {
                if !HandednessSettings.hasBeenSet {
                    showHandednessPrompt = true
                }
            }
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

#Preview {
    ContentView()
}
