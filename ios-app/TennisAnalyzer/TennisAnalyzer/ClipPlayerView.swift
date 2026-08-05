//
//  ClipPlayerView.swift
//  TennisAnalyzer
//

import SwiftUI
import AVKit

/// Thin AVKit wrapper — Phase 2 replaces this with an overlay-capable player
/// once pose/ball detection has annotations to draw on top of the video.
struct ClipPlayerView: View {
    let url: URL

    var body: some View {
        VStack(spacing: 0) {
            VideoPlayer(player: AVPlayer(url: url))

            NavigationLink {
                ServeMarkingFlowView(clipURL: url)
            } label: {
                Label("Analyze Serve", systemImage: "figure.tennis")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .navigationTitle("Clip")
        .navigationBarTitleDisplayMode(.inline)
    }
}
