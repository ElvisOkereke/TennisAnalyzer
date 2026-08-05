import AVFoundation
import SwiftUI

/// Orchestrates the Phase 1 manual-marking flow for a single clip:
/// scrub to the trophy frame -> mark 3 points -> scrub to the contact
/// frame -> mark 5 points -> compute metrics -> show feedback.
struct ServeMarkingFlowView: View {
    let clipURL: URL

    private enum Step {
        case scrubTrophy
        case markTrophy(UIImage)
        case scrubContact
        case markContact(UIImage)
        case results(ServeMetrics, [String])
    }

    private static let trophyLabels = ["Hip", "Knee", "Ankle"]
    private static let contactLabels = ["Shoulder", "Elbow", "Wrist", "Head", "Foot"]

    @State private var step: Step = .scrubTrophy
    @State private var trophyPoints: [String: CGPoint] = [:]

    var body: some View {
        Group {
            switch step {
            case .scrubTrophy:
                FrameScrubberView(
                    clipURL: clipURL,
                    instructions: "Find the trophy position: racket up, tossing arm extended, hitting-side knee and elbow bent the most, just before the upward swing into the ball. Drag the slider to get close, then use the ◀︎ ▶︎ buttons to step one frame at a time to the exact spot."
                ) { image in
                    step = .markTrophy(image)
                }
            case .markTrophy(let image):
                JointMarkingView(
                    image: image,
                    labels: Self.trophyLabels,
                    labelGuidance: [
                        "Hip": "Tap your hitting-side hip joint.",
                        "Knee": "Tap your hitting-side knee joint.",
                        "Ankle": "Tap your hitting-side ankle."
                    ]
                ) { points in
                    trophyPoints = points
                    step = .scrubContact
                }
            case .scrubContact:
                FrameScrubberView(
                    clipURL: clipURL,
                    instructions: "Find the contact frame: the exact instant the racket strings touch the ball. If no single frame looks perfectly right, pick the closest one — use the ◀︎ ▶︎ buttons for frame-accurate control."
                ) { image in
                    step = .markContact(image)
                }
            case .markContact(let image):
                JointMarkingView(
                    image: image,
                    labels: Self.contactLabels,
                    labelGuidance: [
                        "Shoulder": "Tap your hitting-arm shoulder.",
                        "Elbow": "Tap your hitting-arm elbow.",
                        "Wrist": "Tap your hitting-arm wrist, at the racket hand.",
                        "Head": "Tap the top of your head.",
                        "Foot": "Tap whichever foot is touching (or closest to) the ground."
                    ]
                ) { points in
                    finish(contactPoints: points)
                }
            case .results(let metrics, let feedback):
                ServeResultsView(metrics: metrics, feedback: feedback)
            }
        }
        .navigationTitle("Analyze Serve")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func finish(contactPoints: [String: CGPoint]) {
        guard
            let hip = trophyPoints["Hip"],
            let knee = trophyPoints["Knee"],
            let ankle = trophyPoints["Ankle"],
            let shoulder = contactPoints["Shoulder"],
            let elbow = contactPoints["Elbow"],
            let wrist = contactPoints["Wrist"],
            let head = contactPoints["Head"],
            let foot = contactPoints["Foot"]
        else { return }

        let kneeBendDegrees = GeometryEngine.angleAtVertex(hip, knee, ankle)
        let elbowAngleDegrees = GeometryEngine.angleAtVertex(shoulder, elbow, wrist)
        let contactHeightRatio = GeometryEngine.heightRatio(contact: wrist, head: head, foot: foot)

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

        step = .results(metrics, feedback)
    }
}

struct ServeMetrics {
    let kneeBendDegrees: Double
    let elbowAngleDegrees: Double
    let contactHeightRatio: Double
}

/// Slider-based scrubber that shows a live preview frame and lets the
/// user lock in the currently-shown frame.
private struct FrameScrubberView: View {
    let clipURL: URL
    let instructions: String
    var onConfirm: (UIImage) -> Void

    @State private var duration: Double = 0
    @State private var frameDuration: Double = 1.0 / 30.0
    @State private var currentTime: Double = 0
    @State private var previewImage: UIImage?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 16) {
            Text(instructions)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            ZStack {
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 20) {
                Button {
                    step(by: -frameDuration)
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title)
                }
                .disabled(previewImage == nil || currentTime <= 0)

                Slider(value: $currentTime, in: 0...max(duration, 0.01)) { editing in
                    if !editing { loadPreview() }
                }

                Button {
                    step(by: frameDuration)
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title)
                }
                .disabled(previewImage == nil || currentTime >= duration)
            }
            .padding(.horizontal)

            Text("Use ◀︎ ▶︎ to move one video frame at a time for pinpoint accuracy.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Use This Frame") {
                if let previewImage {
                    onConfirm(previewImage)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(previewImage == nil)
        }
        .padding(.vertical)
        .task {
            let assetDuration = await FrameExtractor.duration(of: clipURL)
            duration = assetDuration.seconds.isFinite ? assetDuration.seconds : 0
            frameDuration = await FrameExtractor.frameDuration(of: clipURL)
            await loadPreviewAsync()
            isLoading = false
        }
    }

    private func step(by delta: Double) {
        currentTime = min(max(currentTime + delta, 0), duration)
        loadPreview()
    }

    private func loadPreview() {
        Task { await loadPreviewAsync() }
    }

    private func loadPreviewAsync() async {
        let time = CMTime(seconds: currentTime, preferredTimescale: 600)
        previewImage = await FrameExtractor.image(from: clipURL, at: time)
    }
}
