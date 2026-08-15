//
//  PopinProduct.swift
//  PopinCall
//
//  Created by Ashwin Nath.
//

import Foundation

public struct PopinProduct {
    public let id: String?
    public let name: String?
    public let image: String?
    public let url: String?
    public let description: String?
    public let extra: String?

    public init(
        id: String? = nil,
        name: String? = nil,
        image: String? = nil,
        url: String? = nil,
        description: String? = nil,
        extra: String? = nil
    ) {
        self.id = id
        self.name = name
        self.image = image
        self.url = url
        self.description = description
        self.extra = extra
    }
}
