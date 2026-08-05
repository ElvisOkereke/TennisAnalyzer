import SwiftUI

/// Guides the user through tapping a sequence of points onto a paused
/// frame (e.g. Hip -> Knee -> Ankle), one label at a time.
///
/// Points are emitted in the source image's pixel space (not view space),
/// so they can feed straight into `GeometryEngine` regardless of how the
/// image is scaled/letterboxed on screen.
struct JointMarkingView: View {
    let image: UIImage
    let labels: [String]
    var onComplete: ([String: CGPoint]) -> Void

    @State private var placedPoints: [CGPoint] = []

    private var currentLabel: String? {
        placedPoints.count < labels.count ? labels[placedPoints.count] : nil
    }

    var body: some View {
        VStack(spacing: 16) {
            if let currentLabel {
                Text("Tap the \(currentLabel)")
                    .font(.headline)
            } else {
                Text("All points placed")
                    .font(.headline)
            }

            GeometryReader { proxy in
                let displayRect = Self.displayRect(for: image, in: proxy.size)

                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            guard currentLabel != nil else { return }
                            guard let imagePoint = Self.imagePoint(
                                fromViewPoint: location,
                                displayRect: displayRect,
                                imageSize: image.size
                            ) else { return }
                            placedPoints.append(imagePoint)
                        }

                    ForEach(Array(placedPoints.enumerated()), id: \.offset) { index, point in
                        let viewPoint = Self.viewPoint(
                            fromImagePoint: point,
                            displayRect: displayRect,
                            imageSize: image.size
                        )
                        MarkerView(label: labels[index])
                            .position(viewPoint)
                    }
                }
            }
            .aspectRatio(image.size, contentMode: .fit)

            HStack {
                Button("Back") {
                    guard !placedPoints.isEmpty else { return }
                    placedPoints.removeLast()
                }
                .disabled(placedPoints.isEmpty)

                Spacer()

                Button("Confirm") {
                    var result: [String: CGPoint] = [:]
                    for (index, point) in placedPoints.enumerated() {
                        result[labels[index]] = point
                    }
                    onComplete(result)
                }
                .buttonStyle(.borderedProminent)
                .disabled(placedPoints.count != labels.count)
            }
            .padding(.horizontal)
        }
        .padding()
    }

    /// The rect (within a container of `containerSize`) that an
    /// aspect-fit `image` actually occupies.
    static func displayRect(for image: UIImage, in containerSize: CGSize) -> CGRect {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0,
              containerSize.width > 0, containerSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }

        let scale = min(
            containerSize.width / imageSize.width,
            containerSize.height / imageSize.height
        )
        let displaySize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: (containerSize.width - displaySize.width) / 2,
            y: (containerSize.height - displaySize.height) / 2
        )
        return CGRect(origin: origin, size: displaySize)
    }

    static func imagePoint(fromViewPoint viewPoint: CGPoint, displayRect: CGRect, imageSize: CGSize) -> CGPoint? {
        guard displayRect.contains(viewPoint), displayRect.width > 0, displayRect.height > 0 else { return nil }
        let relativeX = (viewPoint.x - displayRect.minX) / displayRect.width
        let relativeY = (viewPoint.y - displayRect.minY) / displayRect.height
        return CGPoint(x: relativeX * imageSize.width, y: relativeY * imageSize.height)
    }

    static func viewPoint(fromImagePoint imagePoint: CGPoint, displayRect: CGRect, imageSize: CGSize) -> CGPoint {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let relativeX = imagePoint.x / imageSize.width
        let relativeY = imagePoint.y / imageSize.height
        return CGPoint(
            x: displayRect.minX + relativeX * displayRect.width,
            y: displayRect.minY + relativeY * displayRect.height
        )
    }
}

private struct MarkerView: View {
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(Color.yellow)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.caption2)
                .padding(.horizontal, 4)
                .background(.black.opacity(0.6))
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
    }
}
