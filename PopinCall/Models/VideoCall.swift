//
//  VideoCall.swift
//  Popin
//
//  Created by Ashwin Nath on 16/03/24.
//

import Foundation

/*
 @SerializedName("id")
    public int id;
    @SerializedName("access_token")
    public String access_token;
    @SerializedName("user_id")
    public int user_id;
    @SerializedName("user_name")
    public String user_name;
    @SerializedName("room")
    public String room;
    @SerializedName("artifact")
    public String artifact;
    @SerializedName("agents")
    public List<CallAgentModel> agents;
    @SerializedName("status")
    public int status;
    @SerializedName("created_at")
    public long created_at;
 */
struct VideoCall : Codable {
    let status: Int
    let id: Int?
    let user_id: Int?
    let connect_request_id: Int?
    let access_token: String?
    let room: String?
    let websocket: String?
    let agent: Agent?
    let seller_id: Int?
    let agent_id: Int?
    let user_name: String?
    let user_mobile: String?
    let agents: [Agent]?
    let created_at: Double?
}
