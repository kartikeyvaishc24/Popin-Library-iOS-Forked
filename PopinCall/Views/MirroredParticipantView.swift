//
//  MirroredParticipantView.swift
//  PopinCall
//
//  Created for front camera mirroring support
//

import SwiftUI
import LiveKit
import AVFoundation

#if canImport(UIKit)
/// A custom video view that supports mirroring at the layer level
struct MirroredParticipantView: UIViewControllerRepresentable {
    @ObservedObject var participant: Participant
    let shouldMirror: Bool

    func makeUIViewController(context: Context) -> MirroredVideoViewController {
        let controller = MirroredVideoViewController()
        controller.shouldMirror = shouldMirror

        // Add video renderer for the participant's camera track
        if let videoTrack = participant.firstCameraVideoTrack {
            videoTrack.add(videoRenderer: controller)
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: MirroredVideoViewController, context: Context) {
        // Update mirroring state
        uiViewController.shouldMirror = shouldMirror

        // Update video track if changed
        context.coordinator.updateTrack(for: participant, in: uiViewController)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    static func dismantleUIViewController(_ uiViewController: MirroredVideoViewController, coordinator: Coordinator) {
        coordinator.cleanup(uiViewController)
    }

    class Coordinator {
        private weak var currentTrack: VideoTrack?

        func updateTrack(for participant: Participant, in controller: MirroredVideoViewController) {
            let newTrack = participant.firstCameraVideoTrack

            // If track changed, update renderers
            if newTrack?.sid != currentTrack?.sid {
                // Remove old renderer
                currentTrack?.remove(videoRenderer: controller)

                // Add new renderer
                if let track = newTrack {
                    track.add(videoRenderer: controller)
                }

                currentTrack = newTrack
            }
        }

        func cleanup(_ controller: MirroredVideoViewController) {
            currentTrack?.remove(videoRenderer: controller)
            currentTrack = nil
        }
    }
}

/// UIViewController that renders video with optional mirroring
class MirroredVideoViewController: UIViewController, VideoRenderer {
    private lazy var renderingView = MirroredRenderingView()
    var shouldMirror = false {
        didSet {
            renderingView.shouldMirror = shouldMirror
        }
    }

    override func loadView() {
        renderingView.sampleBufferDisplayLayer.videoGravity = .resizeAspectFill
        view = renderingView
        view.backgroundColor = .black
    }

    var isAdaptiveStreamEnabled: Bool { true }
    var adaptiveStreamSize: CGSize { view.bounds.size }

    func render(frame: LiveKit.VideoFrame) {
        guard let sampleBuffer = frame.toCMSampleBuffer() else {
            return
        }

        Task { @MainActor in
            let layer = renderingView.sampleBufferDisplayLayer
            if layer.status == .failed {
                layer.flush()
            }
            if #available(iOS 17.0, *) {
                layer.sampleBufferRenderer.enqueue(sampleBuffer)
            } else {
                layer.enqueue(sampleBuffer)
            }

            // Apply mirroring before rotation
            var transform = CGAffineTransform.identity
            if shouldMirror {
                transform = transform.scaledBy(x: -1, y: 1)
            }
            transform = transform.rotated(by: frame.rotation.rotationAngle)
            layer.setAffineTransform(transform)
        }
    }
}

/// Custom rendering view with mirroring support
class MirroredRenderingView: UIView {
    var shouldMirror = false

    override class var layerClass: AnyClass {
        AVSampleBufferDisplayLayer.self
    }

    var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer {
        layer as! AVSampleBufferDisplayLayer
    }
}
#endif
