//
//  ClipPlayerView.swift
//  TennisAnalyzer
//

import SwiftUI
import AVKit

/// Thin AVKit wrapper — a future overlay-capable player could draw pose/ball
/// annotations on top of the video once there's something to draw.
struct ClipPlayerView: View {
    let url: URL

    var body: some View {
        VStack(spacing: 0) {
            VideoPlayer(player: AVPlayer(url: url))

            NavigationLink {
                AutoServeAnalysisView(clipURL: url)
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
