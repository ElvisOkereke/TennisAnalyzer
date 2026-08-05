import AVFoundation
import UIKit

/// Extracts still frames from a clip for the manual joint-marking flow.
enum FrameExtractor {
    static func duration(of url: URL) async -> CMTime {
        let asset = AVURLAsset(url: url)
        return (try? await asset.load(.duration)) ?? .zero
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
