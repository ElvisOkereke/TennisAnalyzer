import Foundation
import SwiftData

/// A saved analysis result — from either the manual or auto-detected flow —
/// so past serves show up in History across app launches.
@Model
final class ServeRecord {
    var date: Date
    var clipURL: URL
    var kneeBendDegrees: Double
    var elbowAngleDegrees: Double
    var contactHeightRatio: Double
    var feedback: [String]
    var wasAutoDetected: Bool
    var detectionConfidence: Double?

    init(
        date: Date,
        clipURL: URL,
        kneeBendDegrees: Double,
        elbowAngleDegrees: Double,
        contactHeightRatio: Double,
        feedback: [String],
        wasAutoDetected: Bool,
        detectionConfidence: Double? = nil
    ) {
        self.date = date
        self.clipURL = clipURL
        self.kneeBendDegrees = kneeBendDegrees
        self.elbowAngleDegrees = elbowAngleDegrees
        self.contactHeightRatio = contactHeightRatio
        self.feedback = feedback
        self.wasAutoDetected = wasAutoDetected
        self.detectionConfidence = detectionConfidence
    }
}
