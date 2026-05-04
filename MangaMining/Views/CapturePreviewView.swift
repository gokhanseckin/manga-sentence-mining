import SwiftUI
import UIKit

struct CapturePreviewView: View {
    let image: UIImage
    let onMine: () -> Void
    let onRetake: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                ZoomableImageView(image: image)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 12) {
                    Button(action: onMine) {
                        Label("Mine sentences", systemImage: "text.viewfinder")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(action: onRetake) {
                        Label("Retake", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.white)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
                .padding(.top, 16)
                .background(Color.black)
            }
        }
    }
}

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    var minScale: CGFloat = 1.0
    var maxScale: CGFloat = 5.0
    var doubleTapScale: CGFloat = 2.5

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.backgroundColor = .black
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = minScale
        scroll.maximumZoomScale = maxScale
        scroll.bouncesZoom = true
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scroll.addSubview(imageView)
        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scroll
        context.coordinator.doubleTapScale = doubleTapScale

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)

        return scroll
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
        DispatchQueue.main.async {
            context.coordinator.layoutForFit()
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        var doubleTapScale: CGFloat = 2.5

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent()
        }

        func layoutForFit() {
            guard let scrollView, let imageView, let image = imageView.image else { return }
            let bounds = scrollView.bounds
            guard bounds.width > 0, bounds.height > 0 else { return }
            imageView.frame = CGRect(origin: .zero, size: image.size)
            scrollView.contentSize = image.size
            let scaleX = bounds.width / image.size.width
            let scaleY = bounds.height / image.size.height
            let fit = min(scaleX, scaleY)
            scrollView.minimumZoomScale = fit
            scrollView.maximumZoomScale = max(fit * 5, fit + 0.1)
            scrollView.zoomScale = fit
            centerContent()
        }

        func centerContent() {
            guard let scrollView, let imageView else { return }
            let boundsSize = scrollView.bounds.size
            var frame = imageView.frame
            frame.origin.x = frame.size.width < boundsSize.width
                ? (boundsSize.width - frame.size.width) / 2
                : 0
            frame.origin.y = frame.size.height < boundsSize.height
                ? (boundsSize.height - frame.size.height) / 2
                : 0
            imageView.frame = frame
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let target = min(scrollView.minimumZoomScale * doubleTapScale, scrollView.maximumZoomScale)
                let point = gesture.location(in: imageView)
                let size = scrollView.bounds.size
                let zoomRect = CGRect(
                    x: point.x - (size.width / target) / 2,
                    y: point.y - (size.height / target) / 2,
                    width: size.width / target,
                    height: size.height / target
                )
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }
    }
}
