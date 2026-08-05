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
                    playbackURL = url
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("TennisAnalyzer")
            .fullScreenCover(isPresented: $isRecording) {
                CameraRecorderView { url in
                    isRecording = false
                    if let url {
                        playbackURL = url
                    }
                }
                .ignoresSafeArea()
            }
            .navigationDestination(item: $playbackURL) { url in
                ClipPlayerView(url: url)
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
