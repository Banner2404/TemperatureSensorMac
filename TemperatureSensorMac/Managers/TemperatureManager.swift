//
//  TemperatureManager.swift
//  TemperatureSensorMac
//
//  Created by Евгений Соболь on 4/8/20.
//  Copyright © 2020 Esobol. All rights reserved.
//

import Foundation
import CocoaMQTT

class TemperatureManager {

    var mqttClient: CocoaMQTT!
    static let shared = TemperatureManager()

    func connect() {
        let host = "a3tbb06100h7yp-ats.iot.us-east-1.amazonaws.com"
        mqttClient = CocoaMQTT(clientID: UUID().uuidString, host: host, port: 8883)
        mqttClient.logLevel = .debug
        mqttClient.username = ""
        mqttClient.password = ""
        mqttClient.enableSSL = true
        let certificate = getClientCertFromP12File()
        var sslSettings: [String: NSObject] = [:]
        sslSettings[kCFStreamSSLCertificates as String] = certificate
        mqttClient.allowUntrustCACertificate = true
        mqttClient.sslSettings = sslSettings
        mqttClient.didConnectAck = { mqtt, ack in
            print(ack)
        }
        mqttClient.didChangeState = { mqtt, state in
            print(state)
        }
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
}
