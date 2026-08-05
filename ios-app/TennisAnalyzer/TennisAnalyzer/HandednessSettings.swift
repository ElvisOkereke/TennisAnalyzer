import SwiftUI

enum HittingSide: String, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }
    var displayName: String { self == .right ? "Right-handed" : "Left-handed" }
}

/// One-time handedness setting: which arm is the racket arm, used to pick
/// the correct side's joints out of Vision's pose output for auto-detection.
/// Deliberately a persistent setting rather than per-clip auto-detection —
/// reliable, and a reasonable one-time setup cost (playbook §5).
enum HandednessSettings {
    private static let key = "handednessSide"

    static var current: HittingSide {
        HittingSide(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .right
    }

    static func set(_ side: HittingSide) {
        UserDefaults.standard.set(side.rawValue, forKey: key)
    }

    static var hasBeenSet: Bool {
        UserDefaults.standard.string(forKey: key) != nil
    }
}

/// First-run (or Settings-reachable) prompt for picking hitting side.
struct HandednessPromptView: View {
    var onSet: (HittingSide) -> Void

    @State private var selection: HittingSide = HandednessSettings.current

    var body: some View {
        VStack(spacing: 24) {
            Text("Which arm do you serve with?")
                .font(.title2)
                .fontWeight(.semibold)
            Text("This is a one-time setting — it tells the app which side's joints to track when auto-detecting your serve mechanics.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Picker("Hitting side", selection: $selection) {
                ForEach(HittingSide.allCases) { side in
                    Text(side.displayName).tag(side)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Button("Continue") {
                HandednessSettings.set(selection)
                onSet(selection)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
