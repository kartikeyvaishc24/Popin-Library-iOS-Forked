//
//  PiPSupport.swift
//  Popin
//
//  Created for PiP functionality
//

import AVKit
import LiveKit
import SwiftUI

#if canImport(UIKit)
// MARK: - PiP Notifications

extension Notification.Name {
    static let pipDidStart = Notification.Name("pipDidStart")
    static let pipDidStop = Notification.Name("pipDidStop")
    static let pipDidClose = Notification.Name("pipDidClose")
    /// Posted by loadCall() BEFORE state changes, so waiting-PiP coordinators
    /// can set isRestoringFromPiP = true before the camera conflict kills PiP.
    static let callWillConnect = Notification.Name("callWillConnect")
}

// MARK: - PiP View Controllers

final class PiPPreviewViewController: UIViewController, VideoRenderer {
    private lazy var renderingView = PiPSampleRenderingView()
    private var frameCount = 0
    var shouldMirror = false
    private var isMuted = false

    private lazy var mutedOverlay: UIView = {
        let overlay = UIView()
        overlay.backgroundColor = .black
        overlay.isHidden = true
        let config = UIImage.SymbolConfiguration(pointSize: 64, weight: .regular)
        let imageView = UIImageView(image: UIImage(systemName: "video.slash.fill", withConfiguration: config))
        imageView.tintColor = UIColor.white.withAlphaComponent(0.6)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
        ])
        return overlay
    }()

    override func loadView() {
        renderingView.sampleBufferDisplayLayer.videoGravity = .resizeAspectFill
        view = renderingView
        view.backgroundColor = .black
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        mutedOverlay.frame = view.bounds
        mutedOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mutedOverlay)
    }

    var isAdaptiveStreamEnabled: Bool { true }
    var adaptiveStreamSize: CGSize { view.bounds.size }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        mutedOverlay.isHidden = !muted
        if muted {
            renderingView.sampleBufferDisplayLayer.flushAndRemoveImage()
        }
    }

    func render(frame: LiveKit.VideoFrame) {
        guard !isMuted, let sampleBuffer = frame.toCMSampleBuffer() else {
            return
        }

        frameCount += 1

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

            // Combine rotation and mirroring transforms
            // Apply mirroring BEFORE rotation for correct coordinate system
            var transform = CGAffineTransform.identity
            if shouldMirror {
                transform = transform.scaledBy(x: -1, y: 1)
            }
            transform = transform.rotated(by: frame.rotation.rotationAngle)
            layer.setAffineTransform(transform)
        }
    }
}

final class PiPVideoCallViewController: AVPictureInPictureVideoCallViewController, VideoRenderer {
    private lazy var renderingView = PiPSampleRenderingView()
    private var frameCount = 0
    var shouldMirror = false
    private var isMuted = false

    private lazy var mutedOverlay: UIView = {
        let overlay = UIView()
        overlay.backgroundColor = .black
        overlay.isHidden = true
        let config = UIImage.SymbolConfiguration(pointSize: 32, weight: .regular)
        let imageView = UIImageView(image: UIImage(systemName: "video.slash.fill", withConfiguration: config))
        imageView.tintColor = UIColor.white.withAlphaComponent(0.6)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
        ])
        return overlay
    }()

    override func loadView() {
        renderingView.sampleBufferDisplayLayer.videoGravity = .resizeAspectFill
        view = renderingView
        view.backgroundColor = .black
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        mutedOverlay.frame = view.bounds
        mutedOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mutedOverlay)
    }

    var isAdaptiveStreamEnabled: Bool { true }
    var adaptiveStreamSize: CGSize { view.bounds.size }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        mutedOverlay.isHidden = !muted
        if muted {
            renderingView.sampleBufferDisplayLayer.flushAndRemoveImage()
        }
    }

    /// Enqueue a raw CMSampleBuffer (used by local camera preview PiP)
    func enqueueSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard !isMuted else { return }
        Task { @MainActor in
            let layer = renderingView.sampleBufferDisplayLayer
            if layer.status == .failed { layer.flush() }
            if #available(iOS 17.0, *) {
                layer.sampleBufferRenderer.enqueue(sampleBuffer)
            } else {
                layer.enqueue(sampleBuffer)
            }
            if let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) {
                let dims = CMVideoFormatDescriptionGetDimensions(formatDesc)
                let w = Int(dims.width)
                let h = Int(dims.height)
                // Raw buffer dimensions don't reflect the 90° rotation applied
                // on the capture connection — always use portrait (narrow × tall).
                preferredContentSize = CGSize(width: min(w, h), height: max(w, h))
                // On newer devices the capture connection rotation is metadata-only;
                // the pixel data arrives landscape. Rotate the display layer so the
                // video appears upright in the PiP window.
                if w > h {
                    layer.setAffineTransform(CGAffineTransform(rotationAngle: .pi / 2))
                }
            }
        }
    }

    func render(frame: LiveKit.VideoFrame) {
        guard !isMuted, let sampleBuffer = frame.toCMSampleBuffer() else {
            return
        }

        frameCount += 1

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

            // Combine rotation and mirroring transforms
            // Apply mirroring BEFORE rotation for correct coordinate system
            var transform = CGAffineTransform.identity
            if shouldMirror {
                transform = transform.scaledBy(x: -1, y: 1)
            }
            transform = transform.rotated(by: frame.rotation.rotationAngle)
            layer.setAffineTransform(transform)
            preferredContentSize = frame.rotatedSize
        }
    }
}

final class PiPSampleRenderingView: UIView {
    override class var layerClass: AnyClass {
        AVSampleBufferDisplayLayer.self
    }

    var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer {
        layer as! AVSampleBufferDisplayLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }
}

// MARK: - LiveKit Extensions

extension LiveKit.VideoRotation {
    var rotationAngle: CGFloat {
        switch self {
        case ._0: return 0
        case ._90: return .pi / 2
        case ._180: return .pi
        case ._270: return 3 * .pi / 2
        @unknown default: return 0
        }
    }
}

extension LiveKit.VideoFrame {
    var rotatedSize: CGSize {
        switch rotation {
        case ._90, ._270: CGSize(width: Int(dimensions.height), height: Int(dimensions.width))
        default: CGSize(width: Int(dimensions.width), height: Int(dimensions.height))
        }
    }
}

// MARK: - PiP View Wrapper

class PiPHandler: ObservableObject {
    weak var controller: AVPictureInPictureController?

    /// Temporarily retains the PiP controller + coordinator so that a pending
    /// stopPictureInPicture() request can complete after the SwiftUI
    /// representable is dismantled (which would otherwise deallocate both).
    private var retainedObjects: [AnyObject] = []

    func startPictureInPicture() {
        controller?.startPictureInPicture()
    }

    func stopPictureInPicture() {
        controller?.stopPictureInPicture()
    }

    /// Retains the given objects for `duration` seconds so the PiP system has
    /// time to process a stop request before they are deallocated.
    func retainForStop(_ objects: [AnyObject], duration: TimeInterval = 3) {
        retainedObjects = objects
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.retainedObjects = []
        }
    }
}

struct PiPView: UIViewControllerRepresentable {
    let track: VideoTrack
    let pipHandler: PiPHandler
    let shouldMirror: Bool
    let isCameraEnabled: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        // Make sure view controllers are loaded before adding renderers
        let _ = context.coordinator.previewController.view
        let _ = context.coordinator.videoCallController.view

        track.add(videoRenderer: context.coordinator.previewController)
        track.add(videoRenderer: context.coordinator.videoCallController)

        return context.coordinator.previewController
    }

    func updateUIViewController(_: UIViewController, context: Context) {
        // context.coordinator.toggle(enabled: pip)
        // ensure controller is set?
        if pipHandler.controller == nil {
            pipHandler.controller = context.coordinator.controller
        }

        context.coordinator.updateTrack(track)
        context.coordinator.updateMirroring(shouldMirror)
        context.coordinator.updateMuted(!isCameraEnabled)
    }

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        coordinator.cleanup()
    }

    func makeCoordinator() -> Coordinator {
        let previewController = PiPPreviewViewController()
        let videoCallController = PiPVideoCallViewController()

        let contentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: previewController.view,
            contentViewController: videoCallController
        )
        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.setValue(2, forKey: "controlsStyle") // Hide all buttons; tapping PiP restores full view

        let coordinator = Coordinator(
            controller: controller,
            previewController: previewController,
            videoCallController: videoCallController,
            track: track,
            shouldMirror: shouldMirror
        )
        controller.delegate = coordinator

        // Assign controller to handler
        pipHandler.controller = controller

        return coordinator
    }

    final class Coordinator: NSObject, AVPictureInPictureControllerDelegate {
        let controller: AVPictureInPictureController
        let previewController: PiPPreviewViewController
        let videoCallController: PiPVideoCallViewController
        private var track: VideoTrack
        private var isRestoringFromPiP = false
        private var shouldMirror: Bool

        init(controller: AVPictureInPictureController,
             previewController: PiPPreviewViewController,
             videoCallController: PiPVideoCallViewController,
             track: VideoTrack,
             shouldMirror: Bool) {
            self.controller = controller
            self.previewController = previewController
            self.videoCallController = videoCallController
            self.track = track
            self.shouldMirror = shouldMirror
            super.init()
        }

        func updateTrack(_ newTrack: VideoTrack) {
            guard newTrack.sid != track.sid else { return }

            // Remove renderers from old track
            track.remove(videoRenderer: previewController)
            track.remove(videoRenderer: videoCallController)

            // Update track
            track = newTrack

            // Add renderers to new track
            track.add(videoRenderer: previewController)
            track.add(videoRenderer: videoCallController)
        }

        func updateMirroring(_ mirror: Bool) {
            shouldMirror = mirror
            previewController.shouldMirror = mirror
            videoCallController.shouldMirror = mirror
        }

        func updateMuted(_ muted: Bool) {
            previewController.setMuted(muted)
            videoCallController.setMuted(muted)
        }

        func cleanup() {
            if controller.isPictureInPictureActive {
                controller.stopPictureInPicture()
            }
            track.remove(videoRenderer: previewController)
            track.remove(videoRenderer: videoCallController)
        }

        // MARK: - AVPictureInPictureControllerDelegate

        func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        }

        func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            PopinLogger.shared.log("ConnectedPiP: didStartPiP")
            // Hide the main view's video to avoid showing two videos
            previewController.view.isHidden = true
            // Notify to hide the call view controller
            NotificationCenter.default.post(name: .pipDidStart, object: nil)
            PopinCallManager.shared.enterPiPMode()
        }

        func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        }

        func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            PopinLogger.shared.log("ConnectedPiP: didStopPiP — isRestoring=\(isRestoringFromPiP)")
            // Show the main view's video again when PiP stops
            previewController.view.isHidden = false

            if isRestoringFromPiP {
                // User tapped fullscreen/restore button — go back to full screen call
                isRestoringFromPiP = false
                NotificationCenter.default.post(name: .pipDidStop, object: nil)
                PopinCallManager.shared.exitPiPMode()
            } else {
                // User tapped close (X) button — disconnect the call
                NotificationCenter.default.post(name: .pipDidClose, object: nil)
                PopinCallManager.shared.exitPiPMode()
            }
        }

        func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                       restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
            // Called when user taps the fullscreen/restore button (not the close button)
            isRestoringFromPiP = true
            completionHandler(true)
        }

        func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                       failedToStartPictureInPictureWithError error: Error) {
            PopinLogger.shared.log("ConnectedPiP: failedToStartPiP — \(error.localizedDescription)")
        }
    }
}
#endif

