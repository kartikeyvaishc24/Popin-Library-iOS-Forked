//
//  VideoCallPresenter.swift
//  Popin
//
//  Created by Ashwin Nath on 16/03/24.
//

import Foundation

#if canImport(UIKit)
class VideoCallPresenter {
    
    private let videoCallInteractor: VideoCallInteractor
    weak private var videoCallView: VideoCallView?
    
    init(videoCallInteractor: VideoCallInteractor) {
        self.videoCallInteractor = videoCallInteractor
    }
    
    func attachView(videoCallView: VideoCallView) {
        self.videoCallView = videoCallView
    }
    
    func detachView() {
        videoCallView = nil
    }
    
    func acceptCall(callId: Int) {
        Task {
            do {
                try await videoCallInteractor.acceptCall(callId: callId)
            } catch {
            }
        }
    }

    func ringCall(callId: Int) {
        Task {
            do {
                try await videoCallInteractor.ringCall(callId: callId)
            } catch {
                PopinLogger.shared.log("VideoCallPresenter: ringCall failed: \(error.localizedDescription)")
            }
        }
    }

    func rejectCall(callId: Int) {
        Task {
            do {
                try await videoCallInteractor.rejectCall(callId: callId)
            } catch {
            }
        }
    }

    func endCall(callId: Int, onSuccess: @escaping () -> Void, onFailure: @escaping (String) -> Void) {
        Task {
            do {
                try await videoCallInteractor.endCall(callId: callId)
                await MainActor.run {
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    onFailure(error.localizedDescription)
                }
            }
        }
    }

    func closeScreen(callQueueId: Int, onSuccess: @escaping () -> Void, onFailure: @escaping (String) -> Void) {
        Task {
            do {
                try await videoCallInteractor.closeScreen(callQueueId: callQueueId)
                await MainActor.run {
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    onFailure(error.localizedDescription)
                }
            }
        }
    }

}
#endif
