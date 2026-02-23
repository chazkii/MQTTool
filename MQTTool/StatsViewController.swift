//
//  StatsViewController.swift
//  MQTTool
//
//  Created by Brent Petit on 3/13/16.
//  Copyright © 2016-2019 Brent Petit. All rights reserved.
//

import Foundation

import UIKit

class StatsViewController: UIViewController {

    var timer: Timer!

    let statThrottleSetting = 2
    var statThrottle = 0

    @IBOutlet weak var statusTextLabel: UILabel!
    @IBOutlet weak var connectionUptimeLabel: UILabel!
    @IBOutlet weak var connectedToLabel: UILabel!
    @IBOutlet weak var messagesReceivedLabel: UILabel!
    @IBOutlet weak var messagesPublishedLabel: UILabel!

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        // Initialize Tab Bar Item
        tabBarItem = UITabBarItem(title: "Stats", image: UIImage(named: "Linechart.png"), tag: 1)
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        let gradientView = GradientView(frame: self.view.bounds)
        self.view.insertSubview(gradientView, at: 0)

        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(StatsViewController.updateStats), userInfo: nil, repeats: true)
    }

    override func loadView() {
        super.loadView()

        // Get the stats set up before the view is loaded
        updateStats()
    }

    @objc func updateStats() {
        let mgr = ConnectionManager.shared
        var update_stats = false
        var view_visible = false

        if self.isViewLoaded && (self.view.window != nil) {
            view_visible = true
        }
        if view_visible || statThrottle == 0 {
            statThrottle = 0
            update_stats = true
        }

        if view_visible == false {
            print("Stat Throttle: \(statThrottle)")
            statThrottle = (statThrottle + 1) % statThrottleSetting
        }

        // Only worry about this if the view is active
        if update_stats == true {
            switch mgr.connectionState {
            case .Connected:
                var uptime: Double
                statusTextLabel.text = "Status: Connected"
                connectedToLabel.text = "Connected To: \(mgr.mqttConnection!.hostName):\(mgr.mqttConnection!.hostPort)"
                if let connectTime = mgr.mqttConnection?.connectTime {
                    uptime = Date().timeIntervalSince(connectTime)
                } else {
                    uptime = 0
                }
                let hours = Int(uptime / 3600)
                uptime -= Double(hours * 3600)
                let minutes = Int(uptime / 60)
                uptime -= Double(minutes * 60)
                let seconds = Int(uptime)

                connectionUptimeLabel.text = "Connection Uptime: \(hours)h:\(minutes)m:\(seconds)s"

            case .Disconnected:
                statusTextLabel.text = "Status: Disconnected"
                connectedToLabel.text = "Connected To: Disconnected"
                connectionUptimeLabel.text = "Connection Uptime: Disconnected"

            case .Connecting:
                statusTextLabel.text = "Status: Connecting"
                connectedToLabel.text = "Connected To: Connecting"
                connectionUptimeLabel.text = "Connection Uptime: Connecting"
            }

            if let messageCount = mgr.mqttConnection?.messagesReceived {
                messagesReceivedLabel.text = "Messages Received: \(messageCount)"
            } else {
                messagesReceivedLabel.text = "Messages Received: None"
            }

            if let messageCount = mgr.mqttConnection?.messagesSent {
                messagesPublishedLabel.text = "Messages Published: \(messageCount)"
            } else {
                messagesPublishedLabel.text = "Messages Published: None"
            }
        }

    }

}
