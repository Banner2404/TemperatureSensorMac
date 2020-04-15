//
//  AppDelegate.swift
//  TemperatureSensorMac
//
//  Created by Евгений Соболь on 4/8/20.
//  Copyright © 2020 Esobol. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {



    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        //TemperatureManager.shared.connect()
        HistoryManager.shared.test()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

