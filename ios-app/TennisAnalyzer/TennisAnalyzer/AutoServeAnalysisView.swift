import SwiftUI

/// Orchestrates Phase 2's zero-marking flow for a single clip: run pose
/// detection across every frame, auto-locate the trophy/contact frames, then
/// compute the same metrics/feedback the Phase 1 manual flow produces.
///
/// Falls back to the existing manual flow (`ServeMarkingFlowView`) if
/// detection fails outright — e.g. no person detected, or too few
/// confidently-tracked frames to trust — per the playbook's "automatic
/// first, manual as fallback" principle (§5).
struct AutoServeAnalysisView: View {
    let clipURL: URL

    private enum Stage {
        case detectingPose
        case locatingPhases
        case failed
        case results(ServeMetrics, [String], Double)
    }

    @State private var stage: Stage = .detectingPose

    var body: some View {
        Group {
            switch stage {
            case .detectingPose:
                ProgressStatus(text: "Detecting your pose…")
            case .locatingPhases:
                ProgressStatus(text: "Locating trophy and contact…")
            case .failed:
                FailedDetectionView(clipURL: clipURL)
            case .results(let metrics, let feedback, let confidence):
                ServeResultsView(
                    metrics: metrics,
                    feedback: feedback,
                    clipURL: clipURL,
                    provenance: .auto(confidence: confidence)
                )
            }
        }
        .navigationTitle("Analyze Serve")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await runAnalysis()
        }
    }

    private func runAnalysis() async {
        let hittingSide = HandednessSettings.current.rawValue

        guard let sequence = try? await PoseEstimator.extractPoseSequence(from: clipURL) else {
            stage = .failed
            return
        }

        stage = .locatingPhases

        guard let phases = PhaseDetector.detectPhases(
            frames: sequence.frames,
            hittingSide: hittingSide,
            frameDuration: sequence.frameDuration
        ) else {
            stage = .failed
            return
        }

        let trophyFrame = sequence.frames[phases.trophyFrameIndex]
        let contactFrame = sequence.frames[phases.contactFrameIndex]

        guard
            let hip = trophyFrame["\(hittingSide)_hip"],
            let knee = trophyFrame["\(hittingSide)_knee"],
            let ankle = trophyFrame["\(hittingSide)_ankle"],
            let shoulder = contactFrame["\(hittingSide)_shoulder"],
            let elbow = contactFrame["\(hittingSide)_elbow"],
            let wrist = contactFrame["\(hittingSide)_wrist"],
            let foot = contactFrame["\(hittingSide)_ankle"],
            let head = PoseEstimator.headPoint(in: contactFrame)
        else {
            stage = .failed
            return
        }

        let kneeBendDegrees = GeometryEngine.angleAtVertex(hip.point, knee.point, ankle.point)
        let elbowAngleDegrees = GeometryEngine.angleAtVertex(shoulder.point, elbow.point, wrist.point)
        let contactHeightRatio = GeometryEngine.heightRatio(contact: wrist.point, head: head.point, foot: foot.point)

        let metrics = ServeMetrics(
            kneeBendDegrees: kneeBendDegrees,
            elbowAngleDegrees: elbowAngleDegrees,
            contactHeightRatio: contactHeightRatio
        )
        let feedback = FeedbackEngine.generateFeedback(
            kneeBendDegrees: kneeBendDegrees,
            elbowAngleDegrees: elbowAngleDegrees,
            contactHeightRatio: contactHeightRatio
        )

        let usedJoints = [hip, knee, ankle, shoulder, elbow, wrist, foot, head]
        let confidence = usedJoints.map(\.confidence).reduce(0, +) / Double(usedJoints.count)

        stage = .results(metrics, feedback, confidence)
    }
}

private struct ProgressStatus: View {
    let text: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FailedDetectionView: View {
    let clipURL: URL

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Couldn't confidently detect your serve mechanics automatically — this can happen with unusual camera angles or partly out-of-frame footage.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            NavigationLink {
                ServeMarkingFlowView(clipURL: clipURL)
            } label: {
                Label("Mark Manually Instead", systemImage: "hand.point.up.left")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
