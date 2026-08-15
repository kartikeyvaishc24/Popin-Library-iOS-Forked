//
//  PopinInteractor.swift
//  PopinCall
//
//  Created by Ashwin Nath on 17/11/22.
//

import Foundation

class PopinInteractor {
    
    enum InteractorError: LocalizedError {
        case validationFailed
        case apiError(String?)
        case invalidResponse(statusCode: Int)

        var errorDescription: String? {
            switch self {
            case .validationFailed:
                return "Validation failed: please check the provided contact info."
            case .apiError(let message):
                return message ?? "An unknown API error occurred."
            case .invalidResponse(let statusCode):
                return "Invalid response from server (HTTP \(statusCode))."
            }
        }
    }

    func registerUser(seller_id: Int, name: String, contactInfo: String, campaign: String, identifier: String, device: String, deviceVersion: String, sdkVersion: String) async throws -> Int {
        var parameters: [String: Any] = [
            "seller_id": seller_id,
            "is_mobile": 3, //3 for iosSDK
            "device": device,
            "device_version": deviceVersion,
            "sdk_version": sdkVersion,
            "name": name
        ]

        if !identifier.isEmpty {
            parameters["identifier"] = identifier
        }

        if !contactInfo.isEmpty {
            let isEmail = contactInfo.contains("@")
            if isEmail {
                if !contactInfo.contains(".") || contactInfo.count < 5 {
                    throw InteractorError.validationFailed
                }
                parameters["email"] = contactInfo
            } else {
                if contactInfo.count < 8 {
                    throw InteractorError.validationFailed
                }
                parameters["mobile"] = contactInfo
            }
        }
        if !campaign.isEmpty {
            parameters["campaign"] = campaign
        }
        let mobileToken = Utilities.shared.getPushToken()
        if !mobileToken.isEmpty {
            parameters["mobile_token"] = mobileToken
        }

        let urlString = serverURL + "/sdk/user/login"
        
        let userModel: UserModel = try await Utilities.shared.request(urlString: urlString, method: "POST", parameters: parameters)
        
        if (userModel.status == 1) {
            Utilities.shared.saveUser(user: userModel)
            return userModel.user_id ?? 0
        } else {
            throw InteractorError.apiError(userModel.message)
        }
    }
    
    func startConnection(seller_id: Int, campaign: String) async throws -> (callQueueId: Int, callId: Int) {
        var parameters: [String: Any] = ["seller_id":seller_id];
        if !campaign.isEmpty {
            parameters["campaign"] = campaign
        }
        let urlString = serverURL + "/user/call/start";

        let statusModel: StatusModel = try await Utilities.shared.request(urlString: urlString, method: "POST", parameters: parameters)

        if statusModel.status == 1, let callQueueId = statusModel.call_queue_id {
            return (callQueueId, statusModel.call_id ?? 0)
        } else {
             throw InteractorError.apiError(statusModel.message)
        }
    }
    
    func setGroup(identifier: String) async throws {
        let parameters: [String: Any] = ["groupId": identifier]
        let urlString = serverURL + "/user/group"
        let response: StatusModel = try await Utilities.shared.request(urlString: urlString, method: "POST", parameters: parameters)
        if response.status != 1 {
            throw InteractorError.apiError(response.message)
        }
    }

    func updateIdentifier(identifier: String) async throws {
        let parameters: [String: Any] = ["identifier": identifier]
        let urlString = serverURL + "/user"
        let response: StatusModel = try await Utilities.shared.request(urlString: urlString, method: "POST", parameters: parameters)
        if response.status != 1 {
            throw InteractorError.apiError(response.message)
        }
    }

    func updateUser(name: String, contactInfo: String) async throws {
        var parameters: [String: Any] = ["name": name]

        if !contactInfo.isEmpty {
            let isEmail = contactInfo.contains("@")
            if isEmail {
                if !contactInfo.contains(".") || contactInfo.count < 5 {
                    throw InteractorError.validationFailed
                }
                parameters["email"] = contactInfo
            } else {
                if contactInfo.count < 8 {
                    throw InteractorError.validationFailed
                }
                parameters["mobile"] = contactInfo
            }
        }

        let urlString = serverURL + "/user"
        let response: StatusModel = try await Utilities.shared.request(urlString: urlString, method: "POST", parameters: parameters)
        if response.status != 1 {
            throw InteractorError.apiError(response.message)
        }
    }

    func logout(url: String) async throws {
        let response: StatusModel = try await Utilities.shared.request(urlString: url, method: "POST")
        if response.status != 1 {
            throw InteractorError.apiError(response.message)
        }
    }

    func getCallMeta(callId: Int) async throws -> String {
        let parameters: [String: Any] = ["call_id": callId]
        let urlString = serverURL + "/user/call/meta"
        let response: String = try await Utilities.shared.request(urlString: urlString, method: "POST", parameters: parameters)
        return response
    }

    func getCallDetails(callId: Int) async throws -> TalkModel {
        let urlString = serverURL + "/user/call/\(callId)"

        let talkModel: TalkModel = try await Utilities.shared.request(urlString: urlString, method: "GET")

        if talkModel.status == 1 {
            return talkModel
        } else {
            throw InteractorError.apiError(nil)
        }
    }

    func getWidgetCall(url: String) async throws -> TalkModel {
        let urlString = serverURL + "/user/seller-widget/call"
        let parameters: [String: Any] = ["url": url]

        let talkModel: TalkModel = try await Utilities.shared.request(urlString: urlString, method: "POST", parameters: parameters)

        if talkModel.status == 1 {
            return talkModel
        } else {
            throw InteractorError.apiError(nil)
        }
    }
}

struct UserModel : Codable{
    let status: Int;
    let user_id: Int?;
    let token: String?;
    let channel: String?;
    let message: String?;
}
struct StatusModel : Codable{
    let status: Int;
    let call_id: Int?;
    let call_queue_id: Int?;
    let position: Int?;
    let message: String?;
}

struct InviteParticipantModel: Codable {
    let status: Int
    let url: String?
}
