//
//  ChatMessage.swift
//  PopinCall
//
//  Created by Assistant on 04/02/26.
//

import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let text: String?
    let imageUrl: String?
    let isMe: Bool
    let timestamp: String
    let senderId: Int?
    let senderName: String?

    init(id: String, text: String? = nil, imageUrl: String? = nil, isMe: Bool, timestamp: String, senderId: Int? = nil, senderName: String? = nil) {
        self.id = id
        self.text = text
        self.imageUrl = imageUrl
        self.isMe = isMe
        self.timestamp = timestamp
        self.senderId = senderId
        self.senderName = senderName
    }
}

struct SendMessageResponse: Codable {
    let success: Bool?
    let status: Int?
    let message: String?
}
