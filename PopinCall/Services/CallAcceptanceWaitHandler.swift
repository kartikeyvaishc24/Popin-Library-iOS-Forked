//
//  CallAcceptanceWaitHandler.swift
//  PopinCall
//
//  Created on 27/01/26.
//

import Foundation

protocol CallAcceptanceListener: AnyObject {
    func onQueuePositionChange(position: Int)
    func onCallAccepted(callId: Int)
    func onCallMissed()
}

class CallAcceptanceWaitHandler {
    private static let interval: UInt64 = 3_000_000_000 // 3 seconds
    private static let maxDuration: TimeInterval = 300.0 // 5 minutes

    private let callQueueId: Int
    private weak var listener: CallAcceptanceListener?
    private var task: Task<Void, Never>?
    private var startTime: Date?
    private var queuePosition: Int = -1
    private var isRunning = false

    init(callQueueId: Int, listener: CallAcceptanceListener) {
        self.callQueueId = callQueueId
        self.listener = listener
    }

    func startWaitingForAcceptance() {
        guard !isRunning else { return }
        isRunning = true
        startTime = Date()
        
        task = Task {
            while isRunning {
                // Check timeout
                if let startTime = startTime, Date().timeIntervalSince(startTime) >= CallAcceptanceWaitHandler.maxDuration {
                    await MainActor.run {
                        self.stopWaitingForAcceptance()
                        self.listener?.onCallMissed()
                    }
                    return
                }
                
                await pollCallUpdate()
                
                if !isRunning { break }
                
                do {
                    try await Task.sleep(nanoseconds: CallAcceptanceWaitHandler.interval)
                } catch {
                    // Task cancelled
                    break
                }
            }
        }
    }

    func stopWaitingForAcceptance() {
        isRunning = false
        task?.cancel()
        task = nil
    }

    private func pollCallUpdate() async {
        let urlString = serverURL + "/user/connect/update"
        let parameters: [String: Any] = ["call_queue_id": callQueueId]

        do {
            let model: UpdateConnectionModel = try await Utilities.shared.request(urlString: urlString, method: "POST", parameters: parameters)
            await handleUpdate(model)
        } catch {
        }
    }
    
    @MainActor
    private func handleUpdate(_ model: UpdateConnectionModel) {
        // Double check isRunning in case it was stopped while request was in flight
        guard isRunning else { return }
        
        if model.status == 1 {
            if let position = model.position, position != self.queuePosition {
                self.queuePosition = position
                self.listener?.onQueuePositionChange(position: position)
            }
        } else if model.status == 2 {
            self.stopWaitingForAcceptance()
            if let callId = model.call_id {
                self.listener?.onCallAccepted(callId: callId)
            }
        } else if model.status == 3 {
            self.stopWaitingForAcceptance()
            self.listener?.onCallMissed()
        }
    }
}

struct UpdateConnectionModel: Codable {
    let status: Int
    let position: Int?
    let call_id: Int?
    let message: String?
}