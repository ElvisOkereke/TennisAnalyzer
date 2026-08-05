import Foundation

/// Rule-based feedback for manually-marked serve mechanics (Phase 1).
///
/// Mirrors `python/tennis_analyzer/feedback.py`. Thresholds are starting
/// estimates, not validated against real footage yet — see playbook §10.
enum FeedbackEngine {
    static let kneeBendMaxDegrees = 160.0
    static let elbowAngleMinDegrees = 150.0
    static let contactHeightRatioMin = 1.15

    static let maxFeedbackItems = 3

    static let kneeBendMessage = "Bend your knees more for a stronger leg drive."
    static let elbowAngleMessage = "Extend your arm more at contact for full reach."
    static let contactHeightMessage = "Try tossing higher / extending fully at contact."
    static let noIssuesMessage = "Nice mechanics — nothing stood out to flag on this serve."

    /// Applies Phase 1 thresholds to computed metrics.
    ///
    /// Returns at most `maxFeedbackItems` feedback strings, or a single
    /// positive message if nothing trips.
    static func generateFeedback(
        kneeBendDegrees: Double,
        elbowAngleDegrees: Double,
        contactHeightRatio: Double
    ) -> [String] {
        var feedback: [String] = []

        if kneeBendDegrees > kneeBendMaxDegrees {
            feedback.append(kneeBendMessage)
        }

        if elbowAngleDegrees < elbowAngleMinDegrees {
            feedback.append(elbowAngleMessage)
        }

        if contactHeightRatio < contactHeightRatioMin {
            feedback.append(contactHeightMessage)
        }

        feedback = Array(feedback.prefix(maxFeedbackItems))

        return feedback.isEmpty ? [noIssuesMessage] : feedback
    }
}
