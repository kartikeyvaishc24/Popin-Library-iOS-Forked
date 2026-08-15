//
//  PopinCallInteractor.swift
//  PopinCall
//
//  Created by Ashwin Nath on 15/11/22.
//

import Foundation

struct Agent: Codable {
    let id: Int?
    let name: String?
    let image: String?
}

struct TalkModel : Codable {
    let id: Int?
    let user_id: Int?
    let room: String?
    let websocket: String? // LiveKit websocket URL
    let status: Int

    let agent: Agent?
    let seller_id: Int?
    let agent_id: Int?
    let user_name: String?
    let user_mobile: String?
    let agents: [Agent]?
    let created_at: Double?

    private let token: String?
    private let server_access_token: String?

    var access_token: String? {
        return server_access_token ?? token
    }
    
    enum CodingKeys: String, CodingKey {
        case id, user_id, token, room, websocket, status
        case agent, seller_id, agent_id, user_name, user_mobile, agents, created_at
        case server_access_token = "access_token"
        case agent_name, agent_image
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        user_id = try container.decodeIfPresent(Int.self, forKey: .user_id)
        room = try container.decodeIfPresent(String.self, forKey: .room)
        websocket = try container.decodeIfPresent(String.self, forKey: .websocket)
        status = try container.decode(Int.self, forKey: .status)
        
        seller_id = try container.decodeIfPresent(Int.self, forKey: .seller_id)
        agent_id = try container.decodeIfPresent(Int.self, forKey: .agent_id)
        user_name = try container.decodeIfPresent(String.self, forKey: .user_name)
        user_mobile = try container.decodeIfPresent(String.self, forKey: .user_mobile)
        agents = try container.decodeIfPresent([Agent].self, forKey: .agents)
        created_at = try container.decodeIfPresent(Double.self, forKey: .created_at)
        
        token = try container.decodeIfPresent(String.self, forKey: .token)
        server_access_token = try container.decodeIfPresent(String.self, forKey: .server_access_token)
        
        // Custom logic for agent
        let decodedAgent = try container.decodeIfPresent(Agent.self, forKey: .agent)
        let agentName = try container.decodeIfPresent(String.self, forKey: .agent_name)
        let agentImage = try container.decodeIfPresent(String.self, forKey: .agent_image)
        
        if let decodedAgent = decodedAgent {
            self.agent = decodedAgent
        } else if let name = agentName {
            // Fallback: Construct agent from top-level fields
            // Try to find ID in agents list
            let foundId = agents?.first(where: { $0.name == name })?.id
            self.agent = Agent(id: foundId, name: name, image: agentImage)
        } else {
            self.agent = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(user_id, forKey: .user_id)
        try container.encodeIfPresent(room, forKey: .room)
        try container.encodeIfPresent(websocket, forKey: .websocket)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(agent, forKey: .agent)
        try container.encodeIfPresent(seller_id, forKey: .seller_id)
        try container.encodeIfPresent(agent_id, forKey: .agent_id)
        try container.encodeIfPresent(user_name, forKey: .user_name)
        try container.encodeIfPresent(user_mobile, forKey: .user_mobile)
        try container.encodeIfPresent(agents, forKey: .agents)
        try container.encodeIfPresent(created_at, forKey: .created_at)
        try container.encodeIfPresent(token, forKey: .token)
        try container.encodeIfPresent(server_access_token, forKey: .server_access_token)
        
        if let agent = agent {
            try container.encodeIfPresent(agent.name, forKey: .agent_name)
            try container.encodeIfPresent(agent.image, forKey: .agent_image)
        }
    }
}

class PopinCallInteractor {
    
    func getAccessToken(seller_id: Int) async throws -> TalkModel {
        let parameters: [String: Any] = ["seller_id":seller_id];
        let urlString = serverURL + "/user/call";
        // Headers are handled by Utilities automatically if we don't pass them, 
        // but the original code passed headers explicitly.
        // Utilities.shared.getHeaders() is used by default in request() if headers is nil.
        // Original code:
        // "Authorization": "Bearer " + Utilities.shared.getUserToken(),
        // "Accept": "application/json"
        // This is exactly what Utilities.shared.getHeaders() does.
        
        return try await Utilities.shared.request(urlString: urlString, method: "POST", parameters: parameters)
    }
    
    
    
    func endOngoingCall(call_id: Int) async throws {
        let parameters: [String: Any] = ["call_id":call_id];
        let urlString = serverURL + "/user/call/end";
        
        let _: StatusModel = try await Utilities.shared.request(urlString: urlString, method: "POST", parameters: parameters)
    }
    
}