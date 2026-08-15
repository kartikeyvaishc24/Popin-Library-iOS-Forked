//
//  PushCallData.swift
//  PopinCall
//

import Foundation

// MARK: - Product

struct Product: Codable {
    let id: String?
    let name: String?
    let image: String?
    let description: String?
    let url: String?
}

// MARK: - PushCallData

struct PushCallData: Codable {
    let callId: Int
    let callComponentId: Int?
    let role: Int?
    let displayName: String
    let primaryProductInfo: String?
    let artifact: String?
    let productId: String?
    let productName: String?
    let productImage: String?
    let product: Product?
    let timeout: Int?
    let start: Int?
    let type: String?

    enum CodingKeys: String, CodingKey {
        case callId = "call_id"
        case callComponentId = "component_id"
        case role
        case displayName = "name"
        case primaryProductInfo = "primary_product_info"
        case artifact
        case productId = "product_id"
        case productName = "product_name"
        case productImage = "product_image"
        case product
        case timeout
        case start
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let intValue = try? container.decode(Int.self, forKey: .callId) {
            callId = intValue
        } else if let strValue = try? container.decode(String.self, forKey: .callId), let intValue = Int(strValue) {
            callId = intValue
        } else {
            callId = try container.decode(Int.self, forKey: .callId)
        }

        callComponentId = try container.decodeIfPresent(Int.self, forKey: .callComponentId)
        role = try container.decodeIfPresent(Int.self, forKey: .role)
        displayName = try container.decode(String.self, forKey: .displayName)
        primaryProductInfo = try container.decodeIfPresent(String.self, forKey: .primaryProductInfo)
        artifact = try container.decodeIfPresent(String.self, forKey: .artifact)
        productId = try container.decodeIfPresent(String.self, forKey: .productId)
        productName = try container.decodeIfPresent(String.self, forKey: .productName)
        productImage = try container.decodeIfPresent(String.self, forKey: .productImage)
        product = try container.decodeIfPresent(Product.self, forKey: .product)
        type = try container.decodeIfPresent(String.self, forKey: .type)

        if let intValue = try? container.decodeIfPresent(Int.self, forKey: .timeout) {
            timeout = intValue
        } else if let strValue = try? container.decodeIfPresent(String.self, forKey: .timeout) {
            timeout = Int(strValue)
        } else {
            timeout = nil
        }

        if let intValue = try? container.decodeIfPresent(Int.self, forKey: .start) {
            start = intValue
        } else if let strValue = try? container.decodeIfPresent(String.self, forKey: .start) {
            start = Int(strValue)
        } else {
            start = nil
        }
    }
}
