//
//  TemperatureManager.swift
//  TemperatureSensorMac
//
//  Created by Евгений Соболь on 4/8/20.
//  Copyright © 2020 Esobol. All rights reserved.
//

import Foundation
import CocoaMQTT
import Combine

class TemperatureManager {

    static let shared = TemperatureManager()

    @Published var connectionState = CocoaMQTTConnState.initial
    @Published var temperature: Double = 0.0
    private var mqttClient: CocoaMQTT!

    func connect() {
        let host = "a3tbb06100h7yp-ats.iot.us-east-1.amazonaws.com"
        mqttClient = CocoaMQTT(clientID: UUID().uuidString, host: host, port: 8883)
        mqttClient.delegate = self
        mqttClient.logLevel = .info
        mqttClient.username = ""
        mqttClient.password = ""
        mqttClient.enableSSL = true
        let certificate = getClientCertFromP12File()
        var sslSettings: [String: NSObject] = [:]
        sslSettings[kCFStreamSSLCertificates as String] = certificate
        mqttClient.allowUntrustCACertificate = true
        mqttClient.sslSettings = sslSettings
        let success = mqttClient.connect(timeout: 20)
        if !success {
            print("Connect failed")
        }
    }

    func getClientCertFromP12File() -> CFArray? {
        // get p12 file path
        let resourcePath = Bundle.main.path(forResource: "certificate", ofType: "p12")

        guard let filePath = resourcePath, let p12Data = NSData(contentsOfFile: filePath) else {
            print("Failed to open the certificate file: certificate.p12")
            return nil
        }

        // create key dictionary for reading p12 file
        let key = kSecImportExportPassphrase as String
        let options : NSDictionary = [key: "test"]

        var items : CFArray?
        let securityError = SecPKCS12Import(p12Data, options, &items)

        guard securityError == errSecSuccess else {
            if securityError == errSecAuthFailed {
                print("ERROR: SecPKCS12Import returned errSecAuthFailed. Incorrect password?")
            } else {
                print("Failed to open the certificate file: certificate.p12")
            }
            return nil
        }

        guard let theArray = items, CFArrayGetCount(theArray) > 0 else {
            return nil
        }

        let dictionary = (theArray as NSArray).object(at: 0)
        guard let identity = (dictionary as AnyObject).value(forKey: kSecImportItemIdentity as String) else {
            return nil
        }
        let certArray = [identity] as CFArray

        return certArray
    }

    private func resubscribeTopics() {
        mqttClient.subscribe(Topic.get.accepted)
        mqttClient.subscribe(Topic.update.documents)
    }

    private func getShadow() {
        mqttClient.publish(Topic.get.send, withString: "")
    }

    private func shadowUpdated(_ document: Shadow) {
        DispatchQueue.main.async {
            print("New temperature \(document.temperature)")
            self.temperature = document.temperature
        }
    }
}

// MARK: - CocoaMQTTDelegate
extension TemperatureManager: CocoaMQTTDelegate {

    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        resubscribeTopics()
    }

    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
    }

    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
    }

    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        switch message.topic {
        case Topic.get.accepted:
            guard let data = message.string?.data(using: .utf8) else { return }
            guard let document = try? JSONDecoder().decode(AWSShadowDocument.self, from: data) else { return }
            self.shadowUpdated(document.state.reported)
        case Topic.update.documents:
            guard let data = message.string?.data(using: .utf8) else { return }
            guard let document = try? JSONDecoder().decode(AWSShadowUpdate.self, from: data) else { return }
            self.shadowUpdated(document.current.state.reported)
        default:
            break
        }
    }

    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopic topics: [String]) {
        print("Subscribed \(topics)")
        if topics.contains(Topic.get.accepted) {
            getShadow()
        }
    }

    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopic topic: String) {
    }

    func mqttDidPing(_ mqtt: CocoaMQTT) {
    }

    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
    }

    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
    }

    func mqtt(_ mqtt: CocoaMQTT, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }

    func mqtt(_ mqtt: CocoaMQTT, didStateChangeTo state: CocoaMQTTConnState) {
        connectionState = state
    }
}

struct Topic {

    static let thingName = "TempSensor"
    static let get = Subtopic(path: "$aws/things/" + thingName + "/shadow/get")
    static let update = Subtopic(path: "$aws/things/" + thingName + "/shadow/update")

    let path: String

    struct Subtopic {
        let path: String

        var send: String { path }
        var accepted: String { path + "/accepted" }
        var documents: String { path + "/documents" }
    }
}
