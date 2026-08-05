import AVFoundation
import CoreVideo
import Vision

enum PoseEstimationError: Error {
    case noVideoTrack
}

/// Decodes a clip frame-by-frame via `AVAssetReader` and runs Vision's body-pose
/// detector on each frame, producing a per-frame joint time series in the app's
/// image-pixel coordinate convention (top-left origin, y increasing down) — the
/// same convention `GeometryEngine`/`PhaseDetector` already expect.
///
/// `AVAssetReader` (sequential decode) is used instead of repeated
/// `AVAssetImageGenerator.image(at:)` calls, since the latter is far too slow
/// once every frame of a multi-second clip needs to be visited.
enum PoseEstimator {
    /// Vision reports low confidence or omits facial joints entirely when the
    /// face isn't visible (e.g. clips filmed from behind, the common case for
    /// full-body serve mechanics) — this is expected, not a rare failure.
    static let headConfidenceThreshold = 0.5

    struct PoseSequence {
        let frames: [PoseFrame]
        let frameDuration: Double
        let imageSize: CGSize
    }

    static func extractPoseSequence(from url: URL) async throws -> PoseSequence {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw PoseEstimationError.noVideoTrack
        }

        let naturalSize = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let imageSize = naturalSize.applying(transform).absoluteSize
        let frameRate = try await track.load(.nominalFrameRate)
        let frameDuration = frameRate > 0 ? 1.0 / Double(frameRate) : (1.0 / 30.0)
        let orientation = cgImageOrientation(for: transform)

        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        reader.add(output)
        reader.startReading()

        var frames: [PoseFrame] = []
        while let sampleBuffer = output.copyNextSampleBuffer() {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }

            let request = VNDetectHumanBodyPoseRequest()
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
            try? handler.perform([request])

            guard let observation = request.results?.first else {
                frames.append([:])
                continue
            }
            frames.append(poseFrame(from: observation, imageSize: imageSize))
        }
        reader.cancelReading()

        return PoseSequence(frames: frames, frameDuration: frameDuration, imageSize: imageSize)
    }

    /// Prefers `nose` when confident (front/side-angle clips); falls back to
    /// `neck` — a torso-derived joint Vision can localize regardless of
    /// whether the face is visible — for clips filmed from behind.
    static func headPoint(in frame: PoseFrame) -> TrackedJoint? {
        if let nose = frame["nose"], nose.confidence >= headConfidenceThreshold {
            return nose
        }
        return frame["neck"]
    }

    private static let jointNames: [(VNHumanBodyPoseObservation.JointName, String)] = [
        (.nose, "nose"),
        (.neck, "neck"),
        (.leftShoulder, "left_shoulder"), (.rightShoulder, "right_shoulder"),
        (.leftElbow, "left_elbow"), (.rightElbow, "right_elbow"),
        (.leftWrist, "left_wrist"), (.rightWrist, "right_wrist"),
        (.leftHip, "left_hip"), (.rightHip, "right_hip"),
        (.leftKnee, "left_knee"), (.rightKnee, "right_knee"),
        (.leftAnkle, "left_ankle"), (.rightAnkle, "right_ankle")
    ]

    private static func poseFrame(from observation: VNHumanBodyPoseObservation, imageSize: CGSize) -> PoseFrame {
        guard let points = try? observation.recognizedPoints(.all) else { return [:] }

        var frame: PoseFrame = [:]
        for (jointName, name) in jointNames {
            guard let point = points[jointName] else { continue }
            let pixelPoint = CGPoint(
                x: point.location.x * imageSize.width,
                y: (1 - point.location.y) * imageSize.height
            )
            frame[name] = TrackedJoint(point: pixelPoint, confidence: Double(point.confidence))
        }
        return frame
    }

    private static func cgImageOrientation(for transform: CGAffineTransform) -> CGImagePropertyOrientation {
        switch (transform.a, transform.b, transform.c, transform.d) {
        case (0, 1, -1, 0): return .right
        case (0, -1, 1, 0): return .left
        case (-1, 0, 0, -1): return .down
        default: return .up
        }
    }
}

private extension CGSize {
    var absoluteSize: CGSize { CGSize(width: abs(width), height: abs(height)) }
}
