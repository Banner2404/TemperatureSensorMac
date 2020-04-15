//
//  Decoder.swift
//  TemperatureSensorMac
//
//  Created by Евгений Соболь on 4/15/20.
//  Copyright © 2020 Esobol. All rights reserved.
//

import Foundation

extension JSONDecoder {

    func decodeSafeArray<T>(of type: T.Type, from data: Data) throws -> [T] where T: Decodable {
        let array = try decode([Safe<T>].self, from: data)
        return array.compactMap { $0.value }
    }
}

extension KeyedDecodingContainer {

    func decodeSafeArray<T>(of type: T.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> [T] where T: Decodable {
        let array = try decode([Safe<T>].self, forKey: key)
        return array.compactMap { $0.value }
    }
}

struct Safe<T: Decodable>: Decodable {

    let value: T?

    init(from decoder: Decoder) throws {
        do {
            let container = try decoder.singleValueContainer()
            self.value = try container.decode(T.self)
        } catch {
            print("Corrupted data: \(error)")
            self.value = nil
        }
    }
}
