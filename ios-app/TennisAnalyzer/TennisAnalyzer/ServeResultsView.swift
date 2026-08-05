import SwiftUI

/// Shows the manually-derived metrics and feedback for a marked serve.
///
/// Metrics are explicitly labeled as user-marked, not automatic — per the
/// playbook's "show confidence, don't hide it" UX principle, this applies
/// to provenance too, not just numeric confidence.
struct ServeResultsView: View {
    let metrics: ServeMetrics
    let feedback: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Based on the points you marked")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
