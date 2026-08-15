//
//  LocalCameraPreview.swift
//  PopinCall
//

import SwiftUI
import AVFoundation
import AVKit

#if canImport(UIKit)
import UIKit

// MARK: - PiP-capable Local Camera Preview

/// A local camera preview that supports Picture-in-Picture.
/// Uses AVCaptureVideoPreviewLayer for the in-app view and feeds frames
/// to a PiPVideoCallViewController for the PiP floating window.
struct PiPLocalCameraPreview: UIViewControllerRepresentable {
    let pipHandler: PiPHandler
    let isCameraEnabled: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        // Force view loading so PiP content source has valid views
        let _ = context.coordinator.previewController.view
        let _ = context.coordinator.videoCallController.view
        context.coordinator.startCapture()
        return context.coordinator.previewController
    }

    func updateUIViewController(_: UIViewController, context: Context) {
        if pipHandler.controller == nil {
            pipHandler.controller = context.coordinator.pipController
        }
        context.coordinator.updateMuted(!isCameraEnabled)
    }

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        coordinator.cleanup()
    }

    func makeCoordinator() -> Coordinator {
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high

        // Allow capture to continue running in background (required for PiP)
        if #available(iOS 16.0, *) {
            if captureSession.isMultitaskingCameraAccessSupported {
                captureSession.isMultitaskingCameraAccessEnabled = true
            }
        }

        if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let input = try? AVCaptureDeviceInput(device: camera),
           captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        let previewController = CameraPreviewViewController(captureSession: captureSession)
        let videoCallController = PiPVideoCallViewController()

        // Video data output to feed frames into the PiP window
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

        let coordinator = Coordinator(
            captureSession: captureSession,
            previewController: previewController,
            videoCallController: videoCallController
        )

        videoOutput.setSampleBufferDelegate(coordinator, queue: DispatchQueue(label: "com.popin.pip.camera"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            // Rotate the video data output to portrait so PiP shows upright
            if let connection = videoOutput.connection(with: .video) {
                if #available(iOS 17.0, *) {
                    connection.videoRotationAngle = 90
                } else {
                    connection.videoOrientation = .portrait
                }
                // Mirror front camera so PiP matches the in-app preview
                connection.isVideoMirrored = true
            }
        }

        // Set up PiP controller
        let contentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: previewController.view,
            contentViewController: videoCallController
        )
        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.setValue(2, forKey: "controlsStyle")
        controller.delegate = coordinator
        coordinator.pipController = controller
        coordinator.pipHandler = pipHandler
        pipHandler.controller = controller

        return coordinator
    }

    final class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVPictureInPictureControllerDelegate {
        let captureSession: AVCaptureSession
        let previewController: CameraPreviewViewController
        let videoCallController: PiPVideoCallViewController
        var pipController: AVPictureInPictureController?
        /// Reference to the owning PiPHandler so we can retain ourselves during stop.
        weak var pipHandler: PiPHandler?
        private var isRestoringFromPiP = false

        init(captureSession: AVCaptureSession,
             previewController: CameraPreviewViewController,
             videoCallController: PiPVideoCallViewController) {
            self.captureSession = captureSession
            self.previewController = previewController
            self.videoCallController = videoCallController
            super.init()
            // Listen for call connection so we can mark PiP as "restoring" before
            // LiveKit's new CameraCapturer conflicts with our capture session and
            // the PiP system forcefully stops PiP.
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleCallWillConnect),
                name: .callWillConnect,
                object: nil
            )
        }

        @objc private func handleCallWillConnect() {
            let isActive = pipController?.isPictureInPictureActive == true
            PopinLogger.shared.log("WaitingPiP: handleCallWillConnect — isPiPActive=\(isActive)")
            guard isActive, let controller = pipController else { return }
            isRestoringFromPiP = true
            // Disable auto-start BEFORE stopping — otherwise the system
            // immediately re-starts PiP because the source view is off-screen.
            controller.canStartPictureInPictureAutomaticallyFromInline = false
            // Stop the capture session first so PiP has no frame feed.
            captureSession.stopRunning()
            controller.stopPictureInPicture()
            // Retain self + controller so the stop request survives
            // the SwiftUI representable teardown.
            pipHandler?.retainForStop([self, controller])
            PopinLogger.shared.log("WaitingPiP: disabled autoStart, stopped capture, called stopPiP, retained")
        }

        func startCapture() {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }

        func updateMuted(_ muted: Bool) {
            previewController.setMuted(muted)
            videoCallController.setMuted(muted)
        }

        func cleanup() {
            NotificationCenter.default.removeObserver(self, name: .callWillConnect, object: nil)
            let isActive = pipController?.isPictureInPictureActive == true
            PopinLogger.shared.log("WaitingPiP: cleanup — isPiPActive=\(isActive), isRestoring=\(isRestoringFromPiP)")
            if isActive, let controller = pipController {
                // Treat dismantling as a restore (not a close) so that
                // the VC view is re-shown and PopinConnectedView doesn't
                // receive .pipDidClose which would disconnect the call.
                isRestoringFromPiP = true
                controller.canStartPictureInPictureAutomaticallyFromInline = false
                controller.stopPictureInPicture()
                // Retain self + controller via the PiPHandler so the stop
                // request can complete after SwiftUI releases the coordinator.
                pipHandler?.retainForStop([self, controller])
                // Post restore notification directly as a safety net.
                NotificationCenter.default.post(name: .pipDidStop, object: nil)
                PopinCallManager.shared.exitPiPMode()
            }
            captureSession.stopRunning()
        }

        // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            videoCallController.enqueueSampleBuffer(sampleBuffer)
        }

        // MARK: - AVPictureInPictureControllerDelegate

        func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {}

        func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            PopinLogger.shared.log("WaitingPiP: didStartPiP")
            previewController.view.isHidden = true
            NotificationCenter.default.post(name: .pipDidStart, object: nil)
            PopinCallManager.shared.enterPiPMode()
        }

        func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {}

        func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            PopinLogger.shared.log("WaitingPiP: didStopPiP — isRestoring=\(isRestoringFromPiP)")
            previewController.view.isHidden = false
            if isRestoringFromPiP {
                isRestoringFromPiP = false
                NotificationCenter.default.post(name: .pipDidStop, object: nil)
                PopinCallManager.shared.exitPiPMode()
            } else {
                NotificationCenter.default.post(name: .pipDidClose, object: nil)
                PopinCallManager.shared.exitPiPMode()
            }
        }

        func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                       restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
            isRestoringFromPiP = true
            completionHandler(true)
        }

        func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                       failedToStartPictureInPictureWithError error: Error) {}
    }
}

// MARK: - Camera Preview View Controller

/// UIViewController that uses AVCaptureVideoPreviewLayer for the in-app camera preview.
/// Also supports a muted overlay (black + icon) when camera is off.
final class CameraPreviewViewController: UIViewController {
    let captureSession: AVCaptureSession
    private var previewLayer: AVCaptureVideoPreviewLayer?

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

    init(captureSession: AVCaptureSession) {
        self.captureSession = captureSession
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer

        mutedOverlay.frame = view.bounds
        mutedOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mutedOverlay)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    func setMuted(_ muted: Bool) {
        mutedOverlay.isHidden = !muted
    }
}

// MARK: - Simple fallback preview (no PiP)

/// Basic camera preview for devices that don't support PiP.
struct CameraPreviewFallback: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        let session = AVCaptureSession()
        session.sessionPreset = .high

        if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let input = try? AVCaptureDeviceInput(device: camera),
           session.canAddInput(input) {
            session.addInput(input)
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        context.coordinator.session = session
        context.coordinator.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.session?.stopRunning()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var session: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

#endif
