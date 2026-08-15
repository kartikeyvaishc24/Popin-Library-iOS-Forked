//
//  VideoCallInteractor.swift
//  Popin
//
//  Created by Ashwin Nath on 16/03/24.
//

import Foundation

class VideoCallInteractor {

    func acceptCall(callId: Int) async throws {
        let urlString = serverURL + "/user/call/accept"
        let parameters: [String: Any] = ["call_id": callId]
        let _: StatusModel = try await Utilities.shared.request(urlString: urlString, method: "POST", parameters: parameters)
    }

    func rejectCall(callId: Int) async throws {
        let urlString = serverURL + "/user/call/reject"
        let parameters: [String: Any] = ["call_id": callId]
        let _: StatusModel = try await Utilities.shared.request(urlString: urlString, method: "POST", parameters: parameters)
    }

    func endCall(callId: Int) async throws {
        let urlString = serverURL + "/user/call/end"
        let parameters: [String: Any] = ["call_id": callId]
        let value: StatusModel = try await Utilities.shared.request(urlString: urlString, method: "POST", parameters: parameters)

        if value.status != 1 {
            throw NSError(domain: "Popin", code: 0, userInfo: [NSLocalizedDescriptionKey: value.message ?? "Failed to end call"])
        }
    }

    func inviteParticipant(callId: Int) async throws -> String {
        let urlString = serverURL + "/user/call/participant"
        let parameters: [String: Any] = ["call_id": callId]
        let value: InviteParticipantModel = try await Utilities.shared.request(urlString: urlString, method: "POST", parameters: parameters)

        if value.status == 1, let url = value.url {
            return url
        } else {
            throw NSError(domain: "Popin", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to generate invite link"])
        }
    }

    func ringCall(callId: Int) async throws {
        let urlString = serverURL + "/user/call/ring"
        let parameters: [String: Any] = ["call_id": callId]
        let _: StatusModel = try await Utilities.shared.request(urlString: urlString, method: "POST", parameters: parameters)
    }

    func closeScreen(callQueueId: Int) async throws {
        let urlString = serverURL + "/user/screen/close/sdk"
        let parameters: [String: Any] = ["call_queue_id": callQueueId]
        let _: StatusModel = try await Utilities.shared.request(urlString: urlString, method: "POST", parameters: parameters)
    }

}
