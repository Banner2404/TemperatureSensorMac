//
//  HistoryManager.swift
//  TemperatureSensorMac
//
//  Created by Евгений Соболь on 4/12/20.
//  Copyright © 2020 Esobol. All rights reserved.
//

import Foundation
import CryptoKit

class HistoryManager {

    static let shared = HistoryManager()
    var secretKey: String!
    var accessKey: String!
    let algorithm = "AWS4-HMAC-SHA256"
    lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        formatter.dateFormat = "YYYYMMdd'T'HHmmss'Z'"
        return formatter
    }()

    lazy var signFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        formatter.dateFormat = "YYYYMMdd"
        return formatter
    }()

    func loadCredentials() {
        guard let credentialsUrl = Bundle.main.url(forResource: "credentials", withExtension: "json") else { return }
        guard let credentialsData = try? Data(contentsOf: credentialsUrl), let json = try? JSONSerialization.jsonObject(with: credentialsData, options: []) as? [String: String] else { return }
        guard let accessKey = json["access_key"], let secretKey = json["secret_key"] else { return }
        self.secretKey = secretKey
        self.accessKey = accessKey
    }

    func loadData() {
        loadCredentials()
        let url = URL(string: "https://dynamodb.us-east-1.amazonaws.com/")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("dynamodb.us-east-1.amazonaws.com", forHTTPHeaderField: "Host")
        urlRequest.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        urlRequest.setValue("application/x-amz-json-1.0", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("DynamoDB_20120810.Query", forHTTPHeaderField: "X-Amz-Target")
        urlRequest.setValue(dateFormatter.string(from: Date()), forHTTPHeaderField: "X-Amz-Date")
        let data: [String: Any] = [
            "TableName": "temperature_data",
            "KeyConditionExpression": "#id = :id and #timestamp > :timestamp",
            "ExpressionAttributeNames": [
                "#id": "id",
                "#timestamp": "timestamp"
            ],
            "ExpressionAttributeValues": [
                ":id": ["N": "1"],
                ":timestamp": ["N": String(Date().addingTimeInterval(-60*60*24*7).timeIntervalSince1970)]
            ]
        ]
        urlRequest.httpBody = try! JSONSerialization.data(withJSONObject: data, options: [])

        let auth = authHeader(for: urlRequest)
        urlRequest.setValue(auth, forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                print(error)
                return
            }
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else { return }
            guard let data = data, let items = (try? JSONDecoder().decode(HistoryEntry.AWSResponse.self, from: data))?.items else { return }
            print(items)
        }.resume()
    }

    func authHeader(for request: URLRequest) -> String {
        let signature = sign(urlRequest: request)
        let scope = getScope()
        let headers = signedHeaders(for: request)
        return "\(algorithm) Credential=\(accessKey!)/\(scope), SignedHeaders=\(headers), Signature=\(signature)"
    }

    func sign(urlRequest: URLRequest) -> String {
        var string = ""
        string.append(algorithm)
        string.append("\n")
        string.append(dateFormatter.string(from: Date()))
        string.append("\n")
        string.append(getScope())
        string.append("\n")
        string.append(hash(urlRequest: urlRequest))
        let signingKey = getSigningKey()
        let signedString = hmac(key: signingKey, data: string.data(using: .utf8)!)
        return signedString.hexString
    }

    func hash(urlRequest: URLRequest) -> String {
        var string = ""
        let urlComponents = URLComponents(url: urlRequest.url!, resolvingAgainstBaseURL: false)!
        string.append(urlRequest.httpMethod!)
        string.append("\n")
        string.append(urlComponents.path)
        string.append("\n")
        string.append(urlComponents.query ?? "")
        string.append("\n")
        string.append(urlRequest.allHTTPHeaderFields!
            .map { key, value in "\(key.lowercased()):\(value)"}
            .sorted()
            .joined(separator: "\n")
        )
        string.append("\n")
        string.append("\n")
        string.append(signedHeaders(for: urlRequest))
        string.append("\n")
        let hash = SHA256.hash(data: urlRequest.httpBody ?? Data())
            .map { String(format: "%02hhx", $0) }.joined()
        string.append(hash)

        let totalHash = SHA256.hash(data: string.data(using: .utf8)!)
            .map { String(format: "%02hhx", $0) }.joined()
        return totalHash
    }

    func getSigningKey() -> Data {
        let secretKey = ("AWS4" + self.secretKey).data(using: .utf8)!
        let scope = getScope().split(separator: "/")
        let date = scope[0].data(using: .utf8)!
        let region = scope[1].data(using: .utf8)!
        let service = scope[2].data(using: .utf8)!
        let suffix = scope[3].data(using: .utf8)!
        let dateHash = hmac(key: secretKey, data: date)
        let regionHash = hmac(key: dateHash, data: region)
        let serviceHash = hmac(key: regionHash, data: service)
        let suffixHash = hmac(key: serviceHash, data: suffix)
        return suffixHash
    }

    func signedHeaders(for request: URLRequest) -> String {
        request.allHTTPHeaderFields!
            .map { key, _ in "\(key.lowercased())"}
            .sorted()
            .joined(separator: ";")
    }

    func hmac(key: Data, data: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        return Data(HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey))
    }

    func getScope() -> String {
        return [signFormatter.string(from: Date()), "us-east-1", "dynamodb", "aws4_request"].joined(separator: "/")
    }
}

extension Data {

    var hexString: String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}
