//
//  PopinPusher.swift
//  PopinCall
//
//  Created by Ashwin Nath on 17/11/22.
//

import Foundation
import PusherSwift

class AuthRequestBuilder: AuthRequestBuilderProtocol {
    func requestFor(socketID: String, channelName: String) -> URLRequest? {
        var request = URLRequest(url: URL(string: serverURL + "/user/channel/authenticate")!)
        request.httpMethod = "POST"
        request.addValue("Bearer " + Utilities.shared.getUserToken(), forHTTPHeaderField: "Authorization")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("PopinSDK/iOS/\(Popin.sdkVersion)", forHTTPHeaderField: "User-Agent")
        request.httpBody = "socket_id=\(socketID)&channel_name=\(channelName)".data(using: String.Encoding.utf8)
        return request
    }
}

class PopinPusher : PusherDelegate{
    
    private let pusher: Pusher
    var delegate : PopinPusherDelegate?
    
    init() {
        let options = PusherClientOptions(
            authMethod: AuthMethod.authRequestBuilder(authRequestBuilder: AuthRequestBuilder()),
            host: .cluster("ap2"),
            activityTimeout: 10
            
        )
        pusher = Pusher(key: "8a0f629156d27cb26728", options: options)
        pusher.delegate = self;
    }
    
    func connect() {
        pusher.connect()
       
        let pusherChannel = pusher.subscribe(Utilities.shared.getChannel())
        pusherChannel.bind(eventName: "user.message", eventCallback: { (event: PusherEvent) -> Void in
            if let dataString = event.data {
                 if let data = dataString.data(using: .utf8) {
                     do {
                         if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                            let message = json["message"] as? [String: Any],
                            let type = message["type"] as? Int {

                             PopinLogger.shared.log("PopinPusher: user.message received, type=\(type)")
                             if (type == 1) {
                                 // Chat message - forward to ChatManager
                                 ChatManager.shared.handlePusherMessage(dataString)
                             } else if (type == 3) {
                                 Utilities.shared.saveConnected()
                                 self.delegate?.onAgentConnected()
                             } else if (type == 15) {
                                 self.delegate?.onAllExpertsBusy()
                             }
                         }
                     } catch {
                     }
                 }
            }
        });
        pusherChannel.bind(eventName: "user.call_cancel", eventCallback: { (event: PusherEvent) -> Void in
            PopinLogger.shared.log("PopinPusher: user.call_cancel received")
            self.delegate?.onCallDisconnected();
        });
        pusherChannel.bind(eventName: "user.incoming_call_cancelled", eventCallback: { (event: PusherEvent) -> Void in
            PopinLogger.shared.log("PopinPusher: user.incoming_call_cancelled received")
            if let dataString = event.data,
               let data = dataString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let callId = json["id"] as? Int {
                self.delegate?.onIncomingCallCancelled(callId: callId)
            }
        });

    }
    
    func changedConnectionState(from old: ConnectionState, to new: ConnectionState) {
        if (new.stringValue() == "connected") {
            self.delegate?.onPusherConnected()
            // Notify that customer network is back online
            NotificationCenter.default.post(name: .pusherConnectionStateChanged, object: nil, userInfo: ["isConnected": true])
        } else if (new.stringValue() == "disconnected" || new.stringValue() == "disconnecting") {
            // Notify that customer network is lost
            NotificationCenter.default.post(name: .pusherConnectionStateChanged, object: nil, userInfo: ["isConnected": false])
        }
    }
}

extension Notification.Name {
    static let pusherConnectionStateChanged = Notification.Name("PopinPusherConnectionStateChanged")
}
