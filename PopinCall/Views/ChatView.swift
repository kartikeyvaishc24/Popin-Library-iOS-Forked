//
//  ChatView.swift
//  PopinCall
//
//  Created by Assistant on 04/02/26.
//

import SwiftUI

#if canImport(UIKit)

struct ChatView: View {
    let callId: Int
    let onClose: () -> Void

    @ObservedObject private var chatManager = ChatManager.shared
    @State private var messageText: String = ""
    @State private var isSending: Bool = false

    private var messages: [ChatMessage] {
        chatManager.getMessages(for: callId)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            ChatTopBar(onClose: onClose)

            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .onChange(of: messages.count) { _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }

            // Input Bar
            MessageInputBar(
                messageText: $messageText,
                isSending: isSending,
                onSend: sendMessage
            )
        }
        .background(Color.white)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onAppear {
            chatManager.isChatOpen = true
            chatManager.resetUnreadCount()
        }
        .onDisappear {
            chatManager.isChatOpen = false
        }
    }

    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        isSending = true
        let textToSend = trimmedText
        messageText = ""

        chatManager.sendMessage(
            text: textToSend,
            image: nil,
            onSuccess: {
                self.isSending = false
            },
            onFailure: { _ in
                self.isSending = false
            }
        )
    }
}

// MARK: - Chat Top Bar

struct ChatTopBar: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Chat with expert")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .padding(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
        }
        .background(Color.white)
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage

    private static func linkifiedText(_ text: String) -> AttributedString {
        var attributedString = AttributedString(text)

        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return attributedString
        }

        let matches = detector.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))

        for match in matches {
            guard let range = Range(match.range, in: text),
                  let url = match.url,
                  let attrRange = Range(range, in: attributedString) else { continue }

            attributedString[attrRange].link = url
            attributedString[attrRange].underlineStyle = .single
        }

        return attributedString
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isMe {
                Spacer(minLength: 40)
            }

            VStack(alignment: message.isMe ? .trailing : .leading, spacing: 4) {
                // Sender name for agent messages
                if !message.isMe, let senderName = message.senderName {
                    Text(senderName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }

                // Message content
                VStack(alignment: .leading, spacing: 4) {
                    // Image if present
                    if let imageUrl = message.imageUrl, let url = URL(string: imageUrl) {
                        ZStack(alignment: .topTrailing) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 240, height: 180)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 240, height: 180)
                                        .clipped()
                                        .cornerRadius(12)
                                case .failure:
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                        .frame(width: 240, height: 180)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(12)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            
                            // Expand icon as seen in Figma
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                                .padding(8)
                        }
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }

                    // Text if present
                    if let text = message.text, !text.isEmpty {
                        Text(Self.linkifiedText(text))
                            .font(.system(size: 15))
                            .foregroundColor(message.isMe ? .white : .black)
                            .tint(message.isMe ? .white : Color(hex: "3B82F6"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(message.isMe ? Color(hex: "3B82F6") : Color(hex: "F3F4F6"))
                            .cornerRadius(18)
                    }
                }
                
                // Timestamp
                if !message.timestamp.isEmpty {
                    Text(message.timestamp)
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 4)
                }
            }

            if !message.isMe {
                Spacer(minLength: 40)
            }
        }
    }
}

// MARK: - Message Input Bar

struct MessageInputBar: View {
    @Binding var messageText: String
    let isSending: Bool
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                ZStack(alignment: .leading) {
                    if messageText.isEmpty {
                        Text("Write your message here")
                            .foregroundColor(Color(hex: "6B7280"))
                            .padding(.horizontal, 16)
                    }
                    TextField("", text: $messageText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 16)
                        .foregroundColor(.black)
                }
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                )

                Button(action: onSend) {
                    if isSending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(width: 40, height: 40)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color(hex: "3B82F6"))
                            .clipShape(Circle())
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                .opacity(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
        }
    }
}

#endif
