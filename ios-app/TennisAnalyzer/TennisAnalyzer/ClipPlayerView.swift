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
        VideoPlayer(player: AVPlayer(url: url))
            .navigationTitle("Clip")
            .navigationBarTitleDisplayMode(.inline)
    }
}
