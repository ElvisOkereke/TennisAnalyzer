import SwiftData
import SwiftUI

/// Where a result's metrics came from — surfaced in the UI per the
/// playbook's "show confidence, don't hide it" principle, which applies to
/// provenance (manual vs. auto) as much as to numeric confidence itself.
enum ServeAnalysisProvenance {
    case manual
    case auto(confidence: Double)
}

/// Shows the metrics and feedback for an analyzed serve, whether the points
/// came from manual marking (Phase 1) or auto-detection (Phase 2).
struct ServeResultsView: View {
    let metrics: ServeMetrics
    let feedback: [String]
    let clipURL: URL
    var provenance: ServeAnalysisProvenance = .manual
    /// True when displaying an already-saved `ServeRecord` from History —
    /// skips writing a duplicate record on appear.
    var skipPersistence: Bool = false

    @Environment(\.modelContext) private var modelContext
    @State private var hasSaved = false

    private var provenanceText: String {
        switch provenance {
        case .manual:
            return "Based on the points you marked"
        case .auto:
            return "Automatically detected"
        }
    }

    private var confidenceText: String? {
        guard case .auto(let confidence) = provenance else { return nil }
        return "\(Int((confidence * 100).rounded()))% detection confidence"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(provenanceText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let confidenceText {
                    Text(confidenceText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    MetricRow(label: "Knee bend at trophy", value: "\(Int(metrics.kneeBendDegrees.rounded()))°")
                    MetricRow(label: "Elbow angle at contact", value: "\(Int(metrics.elbowAngleDegrees.rounded()))°")
                    MetricRow(label: "Contact-height ratio", value: String(format: "%.2f", metrics.contactHeightRatio))
                }
                .padding()
                .background(.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Feedback")
                        .font(.headline)

                    ForEach(feedback, id: \.self) { item in
                        Label(item, systemImage: "circle.fill")
                            .labelStyle(.titleOnly)
                            .padding(.leading, 4)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: saveRecordIfNeeded)
    }

    private func saveRecordIfNeeded() {
        guard !skipPersistence, !hasSaved else { return }
        hasSaved = true

        let isAuto: Bool
        let confidence: Double?
        switch provenance {
        case .manual:
            isAuto = false
            confidence = nil
        case .auto(let value):
            isAuto = true
            confidence = value
        }

        let record = ServeRecord(
            date: Date(),
            clipURL: clipURL,
            kneeBendDegrees: metrics.kneeBendDegrees,
            elbowAngleDegrees: metrics.elbowAngleDegrees,
            contactHeightRatio: metrics.contactHeightRatio,
            feedback: feedback,
            wasAutoDetected: isAuto,
            detectionConfidence: confidence
        )
        modelContext.insert(record)
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
        }
    }
}
