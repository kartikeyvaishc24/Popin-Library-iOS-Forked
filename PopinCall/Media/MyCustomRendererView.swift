//
//  MyCustomRendererView.swift
//  Popin
//
//  Created by Ashwin Nath on 08/10/24.
//

import AVFoundation
import AVKit
import LiveKit
import SwiftUI

#if canImport(UIKit)
class MyCustomRendererView: NativeView {
    let sampleBufferDisplayLayer: AVSampleBufferDisplayLayer
    lazy var pipController: AVPictureInPictureController = {
        let contentSource = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: sampleBufferDisplayLayer,
                                                                       playbackDelegate: self)
        return AVPictureInPictureController(contentSource: contentSource)
    }()

    private var pipPossibleObservation: NSKeyValueObservation?

    override init(frame: CGRect) {
        sampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
        super.init(frame: frame)
        sampleBufferDisplayLayer.videoGravity = .resizeAspectFill
        #if os(macOS)
        // this is required for macOS
        wantsLayer = true
        layer?.insertSublayer(sampleBufferDisplayLayer, at: 0)
        #elseif os(iOS)
        layer.insertSublayer(sampleBufferDisplayLayer, at: 0)
        #else
        fatalError("Unimplemented")
        #endif

        #if os(iOS)
        if #available(iOS 14.2, *) {
            pipController.canStartPictureInPictureAutomaticallyFromInline = true
        }
        #endif

        // Watch isPictureInPicturePossible changes
        pipPossibleObservation = pipController.observe(\AVPictureInPictureController.isPictureInPicturePossible,
                                                       options: [.initial, .new])
        { _, change in
            guard let newValue = change.newValue else { return }
        }
    }

    deinit {
        pipPossibleObservation?.invalidate()
    }

    override func performLayout() {
        super.performLayout()
        sampleBufferDisplayLayer.frame = bounds
        sampleBufferDisplayLayer.removeAllAnimations()
    }
}

// Conform to VideoRenderer
extension MyCustomRendererView: VideoRenderer {
    var isAdaptiveStreamEnabled: Bool { true }
    var adaptiveStreamSize: CGSize { bounds.size }
    func set(size _: CGSize) {}

    func render(frame: LiveKit.VideoFrame) {
        guard let sampleBuffer = frame.toCMSampleBuffer() else { return }
        if #available(iOS 17.0, *) {
            sampleBufferDisplayLayer.sampleBufferRenderer.enqueue(sampleBuffer)
        } else {
            // SDK requires iOS 17+ at runtime, this is just for buildability
            sampleBufferDisplayLayer.enqueue(sampleBuffer)
        }
    }
}

// Conform to AVPictureInPictureSampleBufferPlaybackDelegate
extension MyCustomRendererView: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(_: AVPictureInPictureController, setPlaying _: Bool) {}

    func pictureInPictureControllerTimeRangeForPlayback(_: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }

    func pictureInPictureControllerIsPlaybackPaused(_: AVPictureInPictureController) -> Bool {
        false
    }

    func pictureInPictureController(_: AVPictureInPictureController, didTransitionToRenderSize _: CMVideoDimensions) {}

    func pictureInPictureController(_: AVPictureInPictureController, skipByInterval _: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
#endif
