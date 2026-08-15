//
//  PopinPresenter.swift
//  PopinCall
//
//  Created by Ashwin Nath on 17/11/22.
//

import Foundation

class PopinPresenter {
    private let popinInteractor: PopinInteractor
    
    init(popinInteractor: PopinInteractor) {
        self.popinInteractor = popinInteractor
    }
    
    
    func isUserRegistered() -> Bool {
        return Utilities.shared.getUserToken().count > 0;
    }
    
    func registerUser(seller_id: Int, name: String, contactInfo: String, campaign: [String: String], identifier: String, device: String, deviceVersion: String, sdkVersion: String, onSucess sucess: @escaping (Int) -> Void, onFailure failure: @escaping (String) -> Void) {

        var campaignString = ""
        if !campaign.isEmpty {
            if let jsonData = try? JSONSerialization.data(withJSONObject: campaign, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                campaignString = jsonString
            }
        }

        Task {
            do {
                let userId = try await popinInteractor.registerUser(seller_id: seller_id, name: name, contactInfo: contactInfo, campaign: campaignString, identifier: identifier, device: device, deviceVersion: deviceVersion, sdkVersion: sdkVersion)
                await MainActor.run {
                    sucess(userId)
                }
            } catch {
                let errorMessage: String
                if case let PopinInteractor.InteractorError.apiError(message) = error, let message = message {
                    errorMessage = message
                } else {
                    errorMessage = error.localizedDescription
                }
                
                await MainActor.run {
                    failure(errorMessage)
                }
            }
        }
    }
    
    func startConnection(seller_id: Int, campaign: [String: String], onSuccess success: @escaping (_ callQueueId: Int, _ callId: Int) -> Void, onFailure failure: @escaping () -> Void) {
        var campaignString = ""
        if !campaign.isEmpty {
            if let jsonData = try? JSONSerialization.data(withJSONObject: campaign, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                campaignString = jsonString
            }
        }

        Task {
            do {
                let result = try await popinInteractor.startConnection(seller_id: seller_id, campaign: campaignString)
                await MainActor.run {
                    success(result.callQueueId, result.callId)
                }
            } catch {
                await MainActor.run {
                    failure()
                }
            }
        }
    }

    func setGroup(identifier: String, onSuccess success: @escaping () -> Void, onFailure failure: @escaping (String) -> Void) {
        Task {
            do {
                try await popinInteractor.setGroup(identifier: identifier)
                await MainActor.run {
                    success()
                }
            } catch {
                let errorMessage: String
                if case let PopinInteractor.InteractorError.apiError(message) = error, let message = message {
                    errorMessage = message
                } else {
                    errorMessage = error.localizedDescription
                }
                await MainActor.run {
                    failure(errorMessage)
                }
            }
        }
    }

    func updateIdentifier(identifier: String, onSuccess: @escaping () -> Void, onFailure: @escaping (String) -> Void) {
        Task {
            do {
                try await popinInteractor.updateIdentifier(identifier: identifier)
                await MainActor.run {
                    onSuccess()
                }
            } catch {
                let errorMessage: String
                if case let PopinInteractor.InteractorError.apiError(message) = error, let message = message {
                    errorMessage = message
                } else {
                    errorMessage = error.localizedDescription
                }
                await MainActor.run {
                    onFailure(errorMessage)
                }
            }
        }
    }

    func updateUser(name: String, contactInfo: String, onSuccess: @escaping () -> Void, onFailure: @escaping (String) -> Void) {
        Task {
            do {
                try await popinInteractor.updateUser(name: name, contactInfo: contactInfo)
                await MainActor.run {
                    onSuccess()
                }
            } catch {
                let errorMessage: String
                if case let PopinInteractor.InteractorError.apiError(message) = error, let message = message {
                    errorMessage = message
                } else {
                    errorMessage = error.localizedDescription
                }
                await MainActor.run {
                    onFailure(errorMessage)
                }
            }
        }
    }

    func logout(url: String) {
        Task {
            try? await popinInteractor.logout(url: url)
            PopinLogger.shared.log("PopinPresenter: logout API complete, clearing local state")
            Utilities.shared.saveUser(user: nil)
            Utilities.shared.clearConnected()
            UserDefaults.standard.removeObject(forKey: "popinSeller")
        }
    }

    func getCallMeta(callId: Int, onSuccess success: @escaping (String) -> Void, onFailure failure: @escaping (String) -> Void) {
        Task {
            do {
                let response = try await popinInteractor.getCallMeta(callId: callId)
                await MainActor.run {
                    success(response)
                }
            } catch {
                await MainActor.run {
                    failure(error.localizedDescription)
                }
            }
        }
    }

    func getCallDetails(callId: Int, onSuccess success: @escaping (TalkModel) -> Void, onFailure failure: @escaping () -> Void) {
        Task {
            do {
                let talkModel = try await popinInteractor.getCallDetails(callId: callId)
                await MainActor.run {
                    success(talkModel)
                }
            } catch {
                await MainActor.run {
                    failure()
                }
            }
        }
    }

    func getWidgetCall(url: String, onSuccess success: @escaping (TalkModel) -> Void, onFailure failure: @escaping () -> Void) {
        Task {
            do {
                let talkModel = try await popinInteractor.getWidgetCall(url: url)
                await MainActor.run {
                    success(talkModel)
                }
            } catch {
                await MainActor.run {
                    failure()
                }
            }
        }
    }

}
