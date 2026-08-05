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

/// Per-joint confidence stats across a pose sequence.
struct JointStats {
    let framesPresent: Int
    let framesConfident: Int
    let averageConfidence: Double
    let minConfidence: Double
    let maxConfidence: Double
}

/// Always-populated diagnostics for a `detectPhases` run, including a
/// specific human-readable `failureReason` when `result` is nil.
struct PhaseDetectionDiagnostics {
    let result: PhaseDetectionResult?
    let failureReason: String?
    let totalFrames: Int
    let validFrameCount: Int
    let jointStats: [String: JointStats]
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

    /// Per-joint confidence stats across every joint name seen in `frames`.
    ///
    /// Covers all joints present in the data, not just the hitting-side
    /// required ones — this is what surfaces a handedness-setting mismatch
    /// (the real wrist tracked confidently on the *other* side) or a joint
    /// that drops out during a specific phase of the motion.
    static func summarizeJoints(_ frames: [PoseFrame], minConfidence: Double = defaultMinConfidence) -> [String: JointStats] {
        var jointNames = Set<String>()
        for frame in frames { jointNames.formUnion(frame.keys) }

        var stats: [String: JointStats] = [:]
        for name in jointNames {
            let confidences = frames.compactMap { $0[name]?.confidence }
            guard !confidences.isEmpty else { continue }
            stats[name] = JointStats(
                framesPresent: confidences.count,
                framesConfident: confidences.filter { $0 >= minConfidence }.count,
                averageConfidence: confidences.reduce(0, +) / Double(confidences.count),
                minConfidence: confidences.min()!,
                maxConfidence: confidences.max()!
            )
        }
        return stats
    }

    /// Like `detectPhases`, but always returns a populated diagnostics
    /// record — including a specific human-readable `failureReason` at
    /// whichever gate rejected the sequence, instead of a bare nil.
    static func diagnosePhases(
        frames: [PoseFrame],
        hittingSide: String,
        frameDuration: Double,
        minConfidence: Double = defaultMinConfidence
    ) -> PhaseDetectionDiagnostics {
        let jointStats = summarizeJoints(frames, minConfidence: minConfidence)

        func diagnostics(
            result: PhaseDetectionResult? = nil,
            failureReason: String? = nil,
            validFrameCount: Int = 0
        ) -> PhaseDetectionDiagnostics {
            PhaseDetectionDiagnostics(
                result: result,
                failureReason: failureReason,
                totalFrames: frames.count,
                validFrameCount: validFrameCount,
                jointStats: jointStats
            )
        }

        let wristJoint = "\(hittingSide)_wrist"
        let hipJoint = "\(hittingSide)_hip"
        let kneeJoint = "\(hittingSide)_knee"
        let ankleJoint = "\(hittingSide)_ankle"
        let requiredJoints = [wristJoint, hipJoint, kneeJoint, ankleJoint]

        let validIndices = frames.indices.filter {
            isValid(frames[$0], jointNames: requiredJoints, minConfidence: minConfidence)
        }
        guard validIndices.count >= minValidFrames else {
            return diagnostics(
                failureReason: "only \(validIndices.count) of \(frames.count) frames had all required "
                    + "\(hittingSide)-side joints (\(requiredJoints.joined(separator: ", "))) tracked above "
                    + "\(minConfidence) confidence (need >= \(minValidFrames))",
                validFrameCount: validIndices.count
            )
        }

        var wristSpeeds = [Double](repeating: -.infinity, count: frames.count)
        for (prevIndex, currIndex) in zip(validIndices, validIndices.dropFirst()) {
            let a = frames[prevIndex][wristJoint]!.point
            let b = frames[currIndex][wristJoint]!.point
            let dt = frameDuration * Double(currIndex - prevIndex)
            wristSpeeds[currIndex] = speed(a, b, dt: dt)
        }
        guard wristSpeeds.contains(where: { $0 != -.infinity }) else {
            return diagnostics(
                failureReason: "could not compute a wrist speed for any frame (\(validIndices.count) "
                    + "valid frame(s) found, but none formed a consecutive pair to measure movement between)",
                validFrameCount: validIndices.count
            )
        }

        let contactIndex = detectContactFrame(wristSpeeds)

        let validBeforeContact = Set(validIndices.filter { $0 < contactIndex })
        guard !validBeforeContact.isEmpty else {
            return diagnostics(
                failureReason: "no confidently-tracked frame occurs before the detected contact frame "
                    + "(index \(contactIndex))",
                validFrameCount: validIndices.count
            )
        }

        var kneeAngles = [Double](repeating: .infinity, count: frames.count)
        for index in validBeforeContact {
            let hip = frames[index][hipJoint]!.point
            let knee = frames[index][kneeJoint]!.point
            let ankle = frames[index][ankleJoint]!.point
            kneeAngles[index] = GeometryEngine.angleAtVertex(hip, knee, ankle)
        }

        let trophyIndex = detectTrophyFrame(kneeAngles, beforeIndex: contactIndex)

        return diagnostics(
            result: PhaseDetectionResult(trophyFrameIndex: trophyIndex, contactFrameIndex: contactIndex),
            validFrameCount: validIndices.count
        )
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
    /// Use `diagnosePhases` for the reason why.
    static func detectPhases(
        frames: [PoseFrame],
        hittingSide: String,
        frameDuration: Double,
        minConfidence: Double = defaultMinConfidence
    ) -> PhaseDetectionResult? {
        diagnosePhases(frames: frames, hittingSide: hittingSide, frameDuration: frameDuration, minConfidence: minConfidence).result
    }
}
