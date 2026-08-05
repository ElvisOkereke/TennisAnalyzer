import AVFoundation
import UIKit

/// Extracts still frames from a clip for the manual joint-marking flow.
enum FrameExtractor {
    static func duration(of url: URL) async -> CMTime {
        let asset = AVURLAsset(url: url)
        return (try? await asset.load(.duration)) ?? .zero
    }

    /// Duration of a single video frame, in seconds, derived from the
    /// clip's actual frame rate — falls back to 1/30s if unavailable.
    static func frameDuration(of url: URL) async -> Double {
        let asset = AVURLAsset(url: url)
        guard
            let track = try? await asset.loadTracks(withMediaType: .video).first,
            let frameRate = try? await track.load(.nominalFrameRate),
            frameRate > 0
        else {
            return 1.0 / 30.0
        }
        return 1.0 / Double(frameRate)
    }

    static func image(from url: URL, at time: CMTime) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        do {
            let cgImage = try await generator.image(at: time).image
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
}
