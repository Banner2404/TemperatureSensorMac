//
//  HistoryEntry.swift
//  TemperatureSensorMac
//
//  Created by Евгений Соболь on 4/15/20.
//  Copyright © 2020 Esobol. All rights reserved.
//

import Foundation

struct HistoryEntry: Decodable {

    let timestamp: Int
    let temperature: Float

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let timestampContainer = try container.nestedContainer(keyedBy: ValueKeys.self, forKey: .timestamp)
        let timestampString = try timestampContainer.decode(String.self, forKey: .number)
        guard let timestamp = Int(timestampString) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [CodingKeys.timestamp], debugDescription: "Unable to get int value"))
        }
        self.timestamp = timestamp

        let temperatureContainer = try container.nestedContainer(keyedBy: ValueKeys.self, forKey: .temperature)
        let temperatureString = try temperatureContainer.decode(String.self, forKey: .number)
        guard let temperature = Float(temperatureString) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [CodingKeys.temperature], debugDescription: "Unable to get float value"))
        }
        self.temperature = temperature
    }

    enum CodingKeys: String, CodingKey {
        case timestamp
        case temperature
    }

    enum ValueKeys: String, CodingKey {
        case number = "N"
    }

    struct AWSResponse: Decodable {
        let items: [HistoryEntry]

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            items = try container.decodeSafeArray(of: HistoryEntry.self, forKey: .items)
        }

        enum CodingKeys: String, CodingKey {
            case items = "Items"
        }
    }
}
