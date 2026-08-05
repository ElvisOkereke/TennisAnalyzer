import SwiftUI

/// Guides the user through tapping a sequence of points onto a paused
/// frame (e.g. Hip -> Knee -> Ankle), one label at a time.
///
/// Points are emitted in the source image's pixel space (not view space),
/// so they can feed straight into `GeometryEngine` regardless of how the
/// image is scaled/letterboxed or zoomed/panned on screen.
struct JointMarkingView: View {
    let image: UIImage
    let labels: [String]
    var labelGuidance: [String: String] = [:]
    var onComplete: ([String: CGPoint]) -> Void

    @State private var placedPoints: [CGPoint] = []

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isZooming = false

    private static let minScale: CGFloat = 1.0
    private static let maxScale: CGFloat = 5.0
    private static let tapMovementTolerance: CGFloat = 6

    private var currentLabel: String? {
        placedPoints.count < labels.count ? labels[placedPoints.count] : nil
    }

    var body: some View {
        VStack(spacing: 12) {
            if let currentLabel {
                Text("Tap the \(currentLabel)")
                    .font(.headline)
                if let guidance = labelGuidance[currentLabel] {
                    Text(guidance)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Text("Pinch to zoom in for more precise placement, drag to pan.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("All points placed")
                    .font(.headline)
            }

            GeometryReader { proxy in
                let containerSize = proxy.size
                let containerCenter = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
                let displayRect = Self.displayRect(for: image, in: containerSize)

                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: containerSize.width, height: containerSize.height)

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
                .scaleEffect(scale, anchor: .center)
                .offset(offset)
                .frame(width: containerSize.width, height: containerSize.height)
                .contentShape(Rectangle())
                .clipped()
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                isZooming = true
                                scale = min(max(lastScale * value, Self.minScale), Self.maxScale)
                            }
                            .onEnded { _ in
                                isZooming = false
                                lastScale = scale
                                if scale <= Self.minScale {
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    offset = Self.clampedOffset(offset, scale: scale, containerSize: containerSize)
                                    lastOffset = offset
                                }
                            },
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard scale > Self.minScale, !isZooming else { return }
                                offset = Self.clampedOffset(
                                    CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    ),
                                    scale: scale,
                                    containerSize: containerSize
                                )
                            }
                            .onEnded { value in
                                guard !isZooming else { return }
                                let dragDistance = hypot(value.translation.width, value.translation.height)
                                if dragDistance < Self.tapMovementTolerance {
                                    handleTap(
                                        at: value.location,
                                        containerCenter: containerCenter,
                                        displayRect: displayRect
                                    )
                                } else if scale > Self.minScale {
                                    lastOffset = offset
                                }
                            }
                    )
                )
            }
            .aspectRatio(image.size, contentMode: .fit)

            HStack {
                Button {
                    withAnimation { resetZoom() }
                } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                }
                .disabled(scale <= Self.minScale)

                Spacer()

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

    private func resetZoom() {
        scale = Self.minScale
        lastScale = Self.minScale
        offset = .zero
        lastOffset = .zero
    }

    private func handleTap(at screenPoint: CGPoint, containerCenter: CGPoint, displayRect: CGRect) {
        guard currentLabel != nil else { return }

        // Invert the scaleEffect(anchor: .center) + offset transform applied
        // to the content, to recover the tap location in the content's own
        // (unscaled) coordinate space.
        let contentPoint = CGPoint(
            x: containerCenter.x + (screenPoint.x - containerCenter.x - offset.width) / scale,
            y: containerCenter.y + (screenPoint.y - containerCenter.y - offset.height) / scale
        )

        guard let imagePoint = Self.imagePoint(
            fromViewPoint: contentPoint,
            displayRect: displayRect,
            imageSize: image.size
        ) else { return }

        placedPoints.append(imagePoint)
    }

    /// Keeps the zoomed content from panning further than its edges.
    private static func clampedOffset(_ proposed: CGSize, scale: CGFloat, containerSize: CGSize) -> CGSize {
        let maxOffsetX = containerSize.width * (scale - 1) / 2
        let maxOffsetY = containerSize.height * (scale - 1) / 2
        return CGSize(
            width: min(max(proposed.width, -maxOffsetX), maxOffsetX),
            height: min(max(proposed.height, -maxOffsetY), maxOffsetY)
        )
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
