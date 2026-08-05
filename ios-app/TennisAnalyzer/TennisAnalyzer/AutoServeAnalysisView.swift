import SwiftUI
import UIKit

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

    /// Everything needed to explain why auto-detection failed, since the
    /// three failure points below otherwise collapse into the same generic
    /// message with no way to tell them apart.
    fileprivate struct DebugReport {
        let hittingSide: String
        let totalFrames: Int
        let visionErrorCount: Int
        /// nil if pose extraction itself threw before any frames existed.
        let diagnostics: PhaseDetectionDiagnostics?
        /// Populated only when `detectPhases` succeeded but the final
        /// joint-lookup guard below still failed — this is the previously
        /// invisible failure mode where shoulder/elbow/head confidence was
        /// never checked by `PhaseDetector` at all.
        let finalGuardFailure: [String: String]?
        let poseExtractionError: String?

        var reportText: String {
            var lines = [
                "Hitting side: \(hittingSide)",
                "Total frames: \(totalFrames)",
                "Vision errors: \(visionErrorCount)"
            ]

            if let poseExtractionError {
                lines.append("Pose extraction failed: \(poseExtractionError)")
                return lines.joined(separator: "\n")
            }

            if let diagnostics {
                lines.append("Confidently-tracked frames: \(diagnostics.validFrameCount)")
                if let failureReason = diagnostics.failureReason {
                    lines.append("Phase-detection failure: \(failureReason)")
                }
                lines.append("")
                lines.append("Joint confidence (weakest first):")
                let sortedStats = diagnostics.jointStats.sorted { $0.value.averageConfidence < $1.value.averageConfidence }
                for (name, stats) in sortedStats {
                    let avg = String(format: "%.2f", stats.averageConfidence)
                    lines.append("  \(name): avg \(avg), present \(stats.framesPresent)/\(totalFrames), confident \(stats.framesConfident)/\(totalFrames)")
                }
            }

            if let finalGuardFailure {
                lines.append("")
                lines.append("Final joint check at trophy/contact frames:")
                for (name, value) in finalGuardFailure.sorted(by: { $0.key < $1.key }) {
                    lines.append("  \(name): \(value)")
                }
            }

            return lines.joined(separator: "\n")
        }
    }

    private enum Stage {
        case detectingPose
        case locatingPhases
        case failed(DebugReport)
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
            case .failed(let report):
                FailedDetectionView(clipURL: clipURL, report: report)
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

        let sequence: PoseEstimator.PoseSequence
        do {
            sequence = try await PoseEstimator.extractPoseSequence(from: clipURL)
        } catch {
            stage = .failed(DebugReport(
                hittingSide: hittingSide,
                totalFrames: 0,
                visionErrorCount: 0,
                diagnostics: nil,
                finalGuardFailure: nil,
                poseExtractionError: "\(error)"
            ))
            return
        }

        stage = .locatingPhases

        let diagnostics = PhaseDetector.diagnosePhases(
            frames: sequence.frames,
            hittingSide: hittingSide,
            frameDuration: sequence.frameDuration
        )
        guard let phases = diagnostics.result else {
            stage = .failed(DebugReport(
                hittingSide: hittingSide,
                totalFrames: sequence.frames.count,
                visionErrorCount: sequence.visionErrorCount,
                diagnostics: diagnostics,
                finalGuardFailure: nil,
                poseExtractionError: nil
            ))
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
            let candidates: [(String, TrackedJoint?)] = [
                ("\(hittingSide)_hip (trophy)", trophyFrame["\(hittingSide)_hip"]),
                ("\(hittingSide)_knee (trophy)", trophyFrame["\(hittingSide)_knee"]),
                ("\(hittingSide)_ankle (trophy)", trophyFrame["\(hittingSide)_ankle"]),
                ("\(hittingSide)_shoulder (contact)", contactFrame["\(hittingSide)_shoulder"]),
                ("\(hittingSide)_elbow (contact)", contactFrame["\(hittingSide)_elbow"]),
                ("\(hittingSide)_wrist (contact)", contactFrame["\(hittingSide)_wrist"]),
                ("\(hittingSide)_ankle (contact, foot proxy)", contactFrame["\(hittingSide)_ankle"]),
                ("head (nose/neck, contact)", PoseEstimator.headPoint(in: contactFrame))
            ]
            var finalGuardFailure: [String: String] = [:]
            for (name, joint) in candidates {
                finalGuardFailure[name] = joint.map { "confidence: \(String(format: "%.2f", $0.confidence))" } ?? "not detected"
            }
            stage = .failed(DebugReport(
                hittingSide: hittingSide,
                totalFrames: sequence.frames.count,
                visionErrorCount: sequence.visionErrorCount,
                diagnostics: diagnostics,
                finalGuardFailure: finalGuardFailure,
                poseExtractionError: nil
            ))
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
    let report: AutoServeAnalysisView.DebugReport

    var body: some View {
        ScrollView {
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

                DisclosureGroup("Debug Info") {
                    DebugReportView(report: report)
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
}

private struct DebugReportView: View {
    let report: AutoServeAnalysisView.DebugReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetricRow(label: "Hitting side", value: report.hittingSide)
            MetricRow(label: "Total frames", value: "\(report.totalFrames)")
            MetricRow(label: "Vision errors", value: "\(report.visionErrorCount)")

            if let poseExtractionError = report.poseExtractionError {
                MetricRow(label: "Pose extraction failed", value: poseExtractionError)
            }

            if let diagnostics = report.diagnostics {
                MetricRow(label: "Confidently-tracked frames", value: "\(diagnostics.validFrameCount)")
                if let failureReason = diagnostics.failureReason {
                    Text(failureReason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text("Joint confidence (weakest first)")
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 4)
                ForEach(sortedJointStats(diagnostics.jointStats), id: \.name) { entry in
                    MetricRow(
                        label: entry.name,
                        value: "avg \(String(format: "%.2f", entry.stats.averageConfidence)), "
                            + "confident \(entry.stats.framesConfident)/\(report.totalFrames)"
                    )
                    .font(.footnote)
                }
            }

            if let finalGuardFailure = report.finalGuardFailure {
                Text("Final joint check at trophy/contact frames")
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 4)
                ForEach(finalGuardFailure.sorted(by: { $0.key < $1.key }), id: \.key) { name, value in
                    MetricRow(label: name, value: value)
                        .font(.footnote)
                }
            }

            Button {
                UIPasteboard.general.string = report.reportText
            } label: {
                Label("Copy Debug Info", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .padding(.top, 8)
    }

    private func sortedJointStats(_ stats: [String: JointStats]) -> [(name: String, stats: JointStats)] {
        stats.map { (name: $0.key, stats: $0.value) }
            .sorted { $0.stats.averageConfidence < $1.stats.averageConfidence }
    }
}

private struct MetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
    }
}
