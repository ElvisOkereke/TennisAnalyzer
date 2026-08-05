import SwiftData
import SwiftUI

/// Local analysis history, backed by SwiftData — every analyzed serve (manual
/// or auto-detected) is saved so it survives past a single session.
struct HistoryListView: View {
    @Query(sort: \ServeRecord.date, order: .reverse) private var records: [ServeRecord]

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView(
                    "No serves analyzed yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Analyzed serves will show up here.")
                )
            } else {
                List(records) { record in
                    NavigationLink {
                        HistoryDetailView(record: record)
                    } label: {
                        HistoryRow(record: record)
                    }
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HistoryRow: View {
    let record: ServeRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.date, style: .date)
                .font(.subheadline)
            HStack {
                Text(record.wasAutoDetected ? "Auto" : "Manual")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Knee \(Int(record.kneeBendDegrees.rounded()))°")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Read-only drill-down into a saved record, reusing `ServeResultsView`'s
/// display logic — `skipPersistence` avoids writing a duplicate `ServeRecord`
/// each time a history entry is reopened.
struct HistoryDetailView: View {
    let record: ServeRecord

    private var provenance: ServeAnalysisProvenance {
        record.wasAutoDetected ? .auto(confidence: record.detectionConfidence ?? 0) : .manual
    }

    var body: some View {
        ServeResultsView(
            metrics: ServeMetrics(
                kneeBendDegrees: record.kneeBendDegrees,
                elbowAngleDegrees: record.elbowAngleDegrees,
                contactHeightRatio: record.contactHeightRatio
            ),
            feedback: record.feedback,
            clipURL: record.clipURL,
            provenance: provenance,
            skipPersistence: true
        )
    }
}
