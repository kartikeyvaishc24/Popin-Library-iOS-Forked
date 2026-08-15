//
//  ChatManager.swift
//  PopinCall
//
//  Created by Assistant on 04/02/26.
//

import Foundation
import Combine

protocol ChatMessageListener: AnyObject {
    func onMessageReceived(_ message: ChatMessage)
}

class ChatManager: ObservableObject {
    static let shared = ChatManager()

    @Published private(set) var messages: [Int: [ChatMessage]] = [:]
    @Published var unreadCount: Int = 0
    @Published private(set) var latestIncomingMessage: ChatMessage? = nil

    weak var listener: ChatMessageListener?
    private var currentCallId: Int?
    private var currentSellerId: Int?
    var isChatOpen: Bool = false

    private init() {}

    func configure(callId: Int, sellerId: Int) {
        self.currentCallId = callId
        self.currentSellerId = sellerId
        if messages[callId] == nil {
            messages[callId] = []
        }
    }

    func getMessages(for callId: Int) -> [ChatMessage] {
        return messages[callId] ?? []
    }

    func clearMessages(for callId: Int) {
        messages[callId] = nil
        unreadCount = 0
    }

    func resetUnreadCount() {
        unreadCount = 0
    }

    func sendMessage(text: String?, image: String? = nil, onSuccess: @escaping () -> Void, onFailure: @escaping (String) -> Void) {
        guard let sellerId = currentSellerId else {
            onFailure("Seller ID not configured")
            return
        }

        guard let callId = currentCallId else {
            onFailure("Call ID not configured")
            return
        }

        let urlString = serverURL + "/user/message"
        let timezone = TimeZone.current.identifier

        var parameters: [String: Any] = [
            "seller_id": sellerId,
            "tz": timezone
        ]

        if let text = text, !text.isEmpty {
            parameters["text"] = text
        }

        if let image = image, !image.isEmpty {
            parameters["image"] = image
        }

        Task {
            do {
                let rawResponse: String = try await Utilities.shared.request(
                    urlString: urlString,
                    method: "POST",
                    parameters: parameters
                )

                var isSuccess = true
                if let data = rawResponse.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let status = json["status"] as? Int {
                        isSuccess = (status == 1)
                    } else if let success = json["success"] as? Bool {
                        isSuccess = success
                    }
                }

                if isSuccess {
                    let messageId = UUID().uuidString
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm"
                    let timestamp = formatter.string(from: Date())

                    let chatMessage = ChatMessage(
                        id: messageId,
                        text: text,
                        imageUrl: image,
                        isMe: true,
                        timestamp: timestamp,
                        senderId: nil,
                        senderName: nil
                    )

                    await MainActor.run {
                        var updatedMessages = self.messages
                        if updatedMessages[callId] == nil {
                            updatedMessages[callId] = []
                        }
                        updatedMessages[callId]?.append(chatMessage)
                        self.messages = updatedMessages
                        onSuccess()
                    }
                } else {
                    await MainActor.run {
                        onFailure("Failed to send message")
                    }
                }
            } catch {
                await MainActor.run {
                    onFailure(error.localizedDescription)
                }
            }
        }
    }

    func handlePusherMessage(_ jsonString: String) {
        guard let callId = currentCallId else { return }

        guard let data = jsonString.data(using: .utf8) else { return }

        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let messageObj = json["message"] as? [String: Any] {

                let messageId = messageObj["message_id"] as? String
                    ?? (messageObj["id"] as? Int).map { String($0) }
                    ?? UUID().uuidString
                var text: String?
                var imageUrl: String?

                if let dataObj = messageObj["data"] as? [String: Any] {
                    text = dataObj["text"] as? String
                    imageUrl = dataObj["image"] as? String
                }

                let timestamp = messageObj["created_at_formatted"] as? String ?? ""
                let sellerId = messageObj["seller_id"] as? Int
                // Prefer agent_name over seller_name for incoming messages
                let agentName = messageObj["agent_name"] as? String ?? messageObj["seller_name"] as? String

                // Use direction to determine if message is from user (0) or agent (1)
                // direction = 0 means sent by user, direction = 1 means from agent
                let direction = messageObj["direction"] as? Int ?? 1
                let isMe = (direction == 0)

                // Only process if it has text or image content
                if text != nil || imageUrl != nil {
                    let chatMessage = ChatMessage(
                        id: messageId,
                        text: text,
                        imageUrl: imageUrl,
                        isMe: isMe,
                        timestamp: timestamp,
                        senderId: sellerId,
                        senderName: agentName
                    )

                    DispatchQueue.main.async {
                        var updatedMessages = self.messages
                        if updatedMessages[callId] == nil {
                            updatedMessages[callId] = []
                        }
                        // Avoid duplicates
                        if !updatedMessages[callId]!.contains(where: { $0.id == chatMessage.id }) {
                            updatedMessages[callId]?.append(chatMessage)
                            self.messages = updatedMessages
                            // Only increment unread for received messages when chat is not open
                            if !isMe && !self.isChatOpen {
                                self.unreadCount += 1
                                // Set latest incoming message for toast display
                                self.latestIncomingMessage = chatMessage
                            }
                            self.listener?.onMessageReceived(chatMessage)
                        }
                    }
                }
            }
        } catch {
        }
    }
}
