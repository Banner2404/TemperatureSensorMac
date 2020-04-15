//
//  ViewController.swift
//  TemperatureSensorMac
//
//  Created by Евгений Соболь on 4/8/20.
//  Copyright © 2020 Esobol. All rights reserved.
//

import Cocoa
import Combine
import Charts

class ViewController: NSViewController {

    private let intervals: [HistoryManager.Interval] = [.day, .week]
    private var selectedInterval: HistoryManager.Interval {
        return intervals[segmentedControl.selectedSegment]
    }
    private var cancellableBag = Set<AnyCancellable>()
    @IBOutlet weak var temperatureTextField: NSTextField!
    @IBOutlet weak var connectionTextField: NSTextField!
    @IBOutlet weak var chartView: LineChartView!
    @IBOutlet weak var activityView: NSProgressIndicator!
    @IBOutlet weak var segmentedControl: NSSegmentedControl!

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

        HistoryManager.shared.$historyEntries
            .map { self.chartData(from: $0) }
            .assign(to: \.data, on: chartView)
            .store(in: &cancellableBag)

        HistoryManager.shared.$isLoading
            .map { !$0 }
            .assign(to: \.isHidden, on: activityView)
            .store(in: &cancellableBag)

        chartView.xAxis.drawGridLinesEnabled = false
        chartView.leftAxis.axisMinimum = 0
        chartView.rightAxis.drawGridLinesEnabled = false
        chartView.rightAxis.drawLabelsEnabled = false
        chartView.legend.enabled = false
        activityView.startAnimation(self)
        updateScale()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    func chartData(from entries: [HistoryEntry]) -> LineChartData {
        let chartEntries = entries.map { entry in
            ChartDataEntry(x: Double(entry.timestamp), y: Double(entry.temperature))
        }
        let dataSet = LineChartDataSet(entries: chartEntries)
        dataSet.fillColor = .green
        dataSet.colors = [.green]
        dataSet.mode = .cubicBezier
        dataSet.drawCirclesEnabled = false
        dataSet.drawCircleHoleEnabled = false
        dataSet.drawFilledEnabled = true
        dataSet.highlightEnabled = false
        dataSet.lineWidth = 2
        dataSet.drawValuesEnabled = false

        return LineChartData(dataSet: dataSet)
    }
    @IBAction func segmentedControlChanged(_ sender: Any) {
        HistoryManager.shared.selectedInterval = selectedInterval
        updateScale()
    }

    func updateScale() {
        chartView.xAxis.axisMinimum = selectedInterval.startDate
        chartView.xAxis.valueFormatter = selectedInterval.formatter
    }


}

