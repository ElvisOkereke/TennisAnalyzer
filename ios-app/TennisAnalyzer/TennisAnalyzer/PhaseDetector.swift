import CoreGraphics
import Foundation

/// A single tracked joint's position (image-pixel space) and Vision's
/// per-joint detection confidence (0...1).
struct TrackedJoint {
    let point: CGPoint
    let confidence: Double
}

/// One frame's worth of tracked joints, keyed by name (e.g. "right_wrist").
typealias PoseFrame = [String: TrackedJoint]

struct PhaseDetectionResult {
    let trophyFrameIndex: Int
    let contactFrameIndex: Int
}

/// Phase-detection heuristics: auto-locate the trophy and contact frames
/// from a per-frame pose time series (Phase 2).
///
/// Mirrors `python/tennis_analyzer/phase_detector.py`, which was prototyped
/// and unit-tested first per the playbook's Python-before-Swift workflow.
enum PhaseDetector {
    static let minValidFrames = 3
    static let defaultMinConfidence = 0.3

    /// Finite-difference speed between two points over `dt` seconds.
    /// Returns 0 if `dt` is zero or negative (degenerate).
    static func speed(_ a: CGPoint, _ b: CGPoint, dt: Double) -> Double {
        guard dt > 0 else { return 0.0 }
        return Double(hypot(b.x - a.x, b.y - a.y)) / dt
    }

    /// Which wrist has the higher peak speed across the sequence. Used
    /// only as a fallback when no handedness setting is available. Ties
    /// favor "right".
    static func hittingSide(leftWristSpeeds: [Double], rightWristSpeeds: [Double]) -> String {
        let leftPeak = leftWristSpeeds.max() ?? 0.0
        let rightPeak = rightWristSpeeds.max() ?? 0.0
        return leftPeak > rightPeak ? "left" : "right"
    }

    /// Index of peak wrist speed.
    static func detectContactFrame(_ wristSpeeds: [Double]) -> Int {
        wristSpeeds.indices.max(by: { wristSpeeds[$0] < wristSpeeds[$1] })!
    }

    /// Index of the most-bent knee, restricted to frames strictly before
    /// `beforeIndex` (the detected contact frame).
    static func detectTrophyFrame(_ kneeAngles: [Double], beforeIndex: Int) -> Int {
        (0..<beforeIndex).min(by: { kneeAngles[$0] < kneeAngles[$1] })!
    }

    private static func isValid(_ frame: PoseFrame, jointNames: [String], minConfidence: Double) -> Bool {
        for name in jointNames {
            guard let joint = frame[name], joint.confidence >= minConfidence else { return false }
        }
        return true
    }

    /// Auto-locates the trophy and contact frame indices.
    ///
    /// `frames` is one entry per decoded video frame, in image-pixel
    /// space. `hittingSide` is "left" or "right" (from the user's
    /// handedness setting). `frameDuration` is the time between frames,
    /// in seconds.
    ///
    /// Returns nil if there aren't enough confidently-tracked frames to
    /// make a reliable call — callers should fall back to manual marking.
    static func detectPhases(
        frames: [PoseFrame],
        hittingSide: String,
        frameDuration: Double,
        minConfidence: Double = defaultMinConfidence
    ) -> PhaseDetectionResult? {
        let wristJoint = "\(hittingSide)_wrist"
        let hipJoint = "\(hittingSide)_hip"
        let kneeJoint = "\(hittingSide)_knee"
        let ankleJoint = "\(hittingSide)_ankle"
        let requiredJoints = [wristJoint, hipJoint, kneeJoint, ankleJoint]

        let validIndices = frames.indices.filter {
            isValid(frames[$0], jointNames: requiredJoints, minConfidence: minConfidence)
        }
        guard validIndices.count >= minValidFrames else { return nil }

        var wristSpeeds = [Double](repeating: -.infinity, count: frames.count)
        for (prevIndex, currIndex) in zip(validIndices, validIndices.dropFirst()) {
            let a = frames[prevIndex][wristJoint]!.point
            let b = frames[currIndex][wristJoint]!.point
            let dt = frameDuration * Double(currIndex - prevIndex)
            wristSpeeds[currIndex] = speed(a, b, dt: dt)
        }
        guard wristSpeeds.contains(where: { $0 != -.infinity }) else { return nil }

        let contactIndex = detectContactFrame(wristSpeeds)

        let validBeforeContact = Set(validIndices.filter { $0 < contactIndex })
        guard !validBeforeContact.isEmpty else { return nil }

        var kneeAngles = [Double](repeating: .infinity, count: frames.count)
        for index in validBeforeContact {
            let hip = frames[index][hipJoint]!.point
            let knee = frames[index][kneeJoint]!.point
            let ankle = frames[index][ankleJoint]!.point
            kneeAngles[index] = GeometryEngine.angleAtVertex(hip, knee, ankle)
        }

        let trophyIndex = detectTrophyFrame(kneeAngles, beforeIndex: contactIndex)

        return PhaseDetectionResult(trophyFrameIndex: trophyIndex, contactFrameIndex: contactIndex)
    }
}
