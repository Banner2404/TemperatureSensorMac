//
//  ViewController.swift
//  TemperatureSensorMac
//
//  Created by Евгений Соболь on 4/8/20.
//  Copyright © 2020 Esobol. All rights reserved.
//

import Cocoa
import Combine

class ViewController: NSViewController {

    private var cancellableBag = Set<AnyCancellable>()
    @IBOutlet weak var temperatureTextField: NSTextField!
    @IBOutlet weak var connectionTextField: NSTextField!
    lazy var numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        TemperatureManager.shared.$temperature
            .map { self.numberFormatter.string(from: NSNumber(value: $0)) ?? "" }
            .assign(to: \.stringValue, on: temperatureTextField)
            .store(in: &cancellableBag)

        TemperatureManager.shared.$connectionState
            .map { $0.description.capitalized }
            .assign(to: \.stringValue, on: connectionTextField)
            .store(in: &cancellableBag)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

