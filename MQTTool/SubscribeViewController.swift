//
//  SubscribeViewController.swift
//  MQTTool
//
//  Created by Brent Petit on 2/16/16.
//  Copyright © 2016-2019 Brent Petit. All rights reserved.
//

import UIKit

class SubscribeViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {

    var timer: Timer!
    var sleepDelayTimeout: Date?
    var stateSubscribed = false

    @IBOutlet weak var subscribeButton: UIButton!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var topicStatusLabel: UILabel!
    @IBOutlet weak var topicTextField: UITextField!
    @IBOutlet weak var messageTable: UITableView!
    @IBOutlet weak var subscribeQosSelector: UISegmentedControl!
    @IBOutlet weak var historyButton: UIButton!

    var tableArray: [MyMQTTMessage]?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        // Initialize Tab Bar Item
        tabBarItem = UITabBarItem(title: "Subscribe", image: UIImage(named: "Subscribe.png"), tag: 1)
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let gradientView = GradientView(frame: self.view.bounds)
        self.view.insertSubview(gradientView, at: 0)


        topicTextField.delegate = self

        // Load up initial values
        loadDefaults()

        messageTable.estimatedRowHeight = 16.0
        messageTable.rowHeight = UITableView.automaticDimension

        messageTable.reloadData()


        NotificationCenter.default.addObserver(self, selector: #selector(SubscribeViewController.actOnNetworkNotify), name: ConnectionManager.networkNotify, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SubscribeViewController.updateSubscriptionTopic(_:)), name: ConnectionManager.updateSubscriptionTopic, object: nil)

        timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(SubscribeViewController.setTextArea), userInfo: nil, repeats: true)

    }


    override func viewWillAppear(_ animated: Bool) {
        // Set the state of the buttons
        updateUIState()
        // If we move to the subscribe view hold off
        // idle sleep a bit because user may be watching
        // for messages
        if stateSubscribed == true {
            setIdleSleepDelay()
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            // Dismiss the keyboard
        DispatchQueue.main.async {
                textField.resignFirstResponder()
            }
        return true
    }

    // Just update the state of the UI. No code here to connect/subscribe/etc.
    //  Those should be done by the caller if necessary
    func updateUIState() {
        let mgr = ConnectionManager.shared
        DispatchQueue.main.async() {
            if mgr.connectionState == .Connected {
                self.subscribeButton.isEnabled = true
                if self.stateSubscribed {
                    if (mgr.mqttConnection?.subscriptionTopic.isEmpty) ?? true {
                        if let topic = self.topicTextField.text {
                            mgr.mqttConnection?.subscriptionTopic = topic
                        } else {
                            // Bogus input
                            return
                        }
                        // Load setting, or 0 if no saved value
                        mgr.mqttConnection?.subscriptionQos = Int32(self.subscribeQosSelector.selectedSegmentIndex)
                    }
                    self.subscribeButton.setTitle("Unsubscribe", for: .normal)
                    self.topicStatusLabel.text = "Status: Subscribed to: " + (mgr.mqttConnection?.subscriptionTopic ?? "")
                    self.subscribeQosSelector.selectedSegmentIndex = Int(mgr.mqttConnection?.subscriptionQos ?? 0)
                    self.subscribeQosSelector.isEnabled = false
                    self.topicTextField.isEnabled = false
                    self.clearButton.isEnabled = false
                } else {
                    self.subscribeButton.setTitle("Subscribe", for: .normal)
                    self.topicStatusLabel.text = "Status: Unsubscribed"
                    self.subscribeQosSelector.isEnabled = true
                    self.topicTextField.isEnabled = true
                    self.clearButton.isEnabled = true
                }
            } else {
                self.subscribeButton.isEnabled = false
                self.subscribeQosSelector.isEnabled = false
                self.topicTextField.isEnabled = false
                self.subscribeButton.setTitle("Disconnected", for: .normal)
                self.topicStatusLabel.text = "Status: Disconnected"
                self.clearButton.isEnabled = true
            }
        }

    }

    // When the view is first loaded, load the last saved values
    func loadDefaults() {
        let mgr = ConnectionManager.shared
        if mgr.userSettings.retrieveSubscriptionList() &&
             mgr.userSettings.subscription_list != nil {
            print("loadDefaults... item count = \(mgr.userSettings.subscription_list!.count)")

            if let latest = mgr.userSettings.subscription_list!.first {
                self.topicTextField.text = latest.topic
                self.subscribeQosSelector.selectedSegmentIndex = Int(latest.qos)
            }
        }
    }

    func saveDefaults() {
        let mgr = ConnectionManager.shared
        // Save off the settings
        print("in saveDefaults... ")
        if mgr.mqttConnection != nil {
            if mgr.mqttConnection!.subscriptionTopic.isEmpty {
                print("saveDefaults... connectionSetting not set")
                return
            }
        }

        mgr.userSettings.updateSubscription(topic: mgr.mqttConnection!.subscriptionTopic,
                                        qos: Int(mgr.mqttConnection!.subscriptionQos))
        print("done\n")

    }

    @objc func actOnNetworkNotify() {
        let mgr = ConnectionManager.shared
        if mgr.connectionState == .Disconnected {
            stateSubscribed = false
            self.disableIdleSleepDelay()
        } else {
            // We're connected and subscribed...
            if stateSubscribed == false &&
                mgr.mqttConnection?.subscriptionTopic.isEmpty == false {
                    self.setIdleSleepDelay()
                    stateSubscribed = true
            }
        }
        updateUIState()
    }

    @objc func updateSubscriptionTopic(_ notification: Notification) {
        let mgr = ConnectionManager.shared
        if let topic = notification.userInfo?["topic"] as? String {
            self.topicTextField.text = topic

            if stateSubscribed == true {
                DispatchQueue.global(qos: .userInitiated).sync {
                    if mgr.mqttConnection != nil {
                        mgr.mqttConnection!.unsubscribe()
                    }
                    self.stateSubscribed = false
                }
            }
            subscribeButtonClicked()
        }
    }

    @IBAction func subscribeButtonClicked() {
        let mgr = ConnectionManager.shared
        let myTopic = self.topicTextField.text
        let myQos = self.subscribeQosSelector.selectedSegmentIndex
        // First do the subscribe/unsubscribe
        if mgr.connectionState == .Connected {
            if stateSubscribed == false {
                if myTopic != nil && myTopic!.isEmpty == false {
                    DispatchQueue.global(qos: .userInitiated).async {
                        if mgr.mqttConnection != nil {
                            mgr.mqttConnection!.subscribe(topic: myTopic!, qos: Int32(myQos))
                        }

                        self.stateSubscribed = true
                        self.setIdleSleepDelay()
                        self.updateUIState()
                        self.saveDefaults()
                    }
                }
            } else {
                DispatchQueue.global(qos: .userInitiated).async {
                    if mgr.mqttConnection != nil {
                        mgr.mqttConnection?.unsubscribe()
                    }
                    self.stateSubscribed = false
                    self.disableIdleSleepDelay()
                    self.updateUIState()
                }
            }
        }
    }

    @IBAction func clearButtonClicked() {
        let mgr = ConnectionManager.shared
        if tableArray != nil {
            tableArray?.removeAll()
        }
        if mgr.mqttConnection != nil {
            mgr.mqttConnection?.messageList.removeAll()
        }
        messageTable.reloadData()
    }

    // UITableView stuff
    private func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }


    func tableView(_ messageTable: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let count = ConnectionManager.shared.mqttConnection?.messageList.count {
            return count
        } else {
            return 0
        }
    }


    func tableView(_ messageTable: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        // This is the preferable dequeue call as it doesn't return an optional
        let cell = messageTable.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        cell.textLabel?.numberOfLines = 2
        cell.textLabel?.lineBreakMode = .byWordWrapping

        cell.textLabel?.font = UIFont(name: "Helvetica Neue", size: 12.0)
        cell.textLabel?.textColor = UIColor(red: (23/255), green: (85/255), blue: (141/255), alpha: 1.0)
        if tableArray != nil && indexPath.row < tableArray!.count {
            if let messageText = tableArray![(indexPath.row)].payloadString {
                cell.textLabel!.text = "\(tableArray![(indexPath.row)].topic)\n\(messageText)"
            } else if let messageData = tableArray![(indexPath.row)].payload {
                cell.textLabel!.text = "\(tableArray![(indexPath.row)].topic)\n\(messageData.base64EncodedString())"
            } else {
                cell.textLabel!.text = "\(tableArray![(indexPath.row)].topic)\nEmpty Message"
            }
        }
        cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator

        return cell
    }

    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowDetailsSegue" {
            if let destination = segue.destination as? DetailViewController {
                if let detailIndex =  messageTable.indexPathForSelectedRow?.row {
                    destination.messageData = tableArray![detailIndex].payload
                    destination.messageText = tableArray![detailIndex].payloadString
                    destination.messageTopic = tableArray![detailIndex].topic
                    destination.messageID = Int(tableArray![detailIndex].messageId)
                    destination.messageQOS = Int32(tableArray![detailIndex].qos)
                    destination.messageTimestamp = tableArray![detailIndex].timestamp

                }
            }
        }
    }


    // Helpers

    // Callback for updating message area when new message comes in
    @objc func setTextArea() {
        let mgr = ConnectionManager.shared
        // Only worry about this if the view is active
        if view.window != nil && view.isHidden == false {
            if let newMessage = mgr.mqttConnection?.newMessage {
                // If there is something new to show...
                if newMessage == true {
                    if mgr.mqttConnection != nil {
                        mgr.mqttConnection!.newMessage = false
                        tableArray = mgr.mqttConnection!.messageList
                        DispatchQueue.main.async() {
                            self.messageTable.reloadData()
                        }
                    }
                }
            }
        }
        // Clean up idle timeout button
        if (sleepDelayTimeout != nil) &&
            (sleepDelayTimeout! < Date()) {
            // Hit our timeout
            print("idleSleepDelay timeout... turning off")
            disableIdleSleepDelay()
        }
    }


    @IBAction func historyButtonPressed(_ sender: UIButton) {
        let mgr = ConnectionManager.shared
        let alertController: UIAlertController

        if mgr.userSettings.retrieveSubscriptionList() == false ||
            mgr.userSettings.subscription_list == nil ||
            mgr.userSettings.subscription_list!.count == 0 {

            alertController = UIAlertController(title: "Alert", message: "No history available", preferredStyle: .alert)

            alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
                NSLog("The \"OK\" alert occured.")
            }))
        } else {

            alertController = UIAlertController(title: "Subscribe History", message: "Select a topic", preferredStyle: .actionSheet)

            for setting in mgr.userSettings.subscription_list! {
                alertController.addAction(UIAlertAction(title: "\(setting.topic!)", style: .default, handler: { (action) in
                    //execute some code when this option is selected
                    print("\(setting.topic!) selected")
                    self.topicTextField.text = setting.topic!
                    self.subscribeQosSelector.selectedSegmentIndex = Int(setting.qos)
                }))
            }
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
                //execute some cancel stuff
                print("Cancelled")
            }))
        }
        alertController.modalPresentationStyle = UIModalPresentationStyle.popover
        alertController.popoverPresentationController?.sourceView = sender // works for both iPhone & iPad
        alertController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: sender.frame.size.width, height: sender.frame.size.height)
        present(alertController, animated: true)
    }

    func setIdleSleepDelay() {
        if SettingsBundleHelper.idleSleepDelayEnabled() {
            print("setIdleSleepDelay - Enabled by user")
            sleepDelayTimeout = Date(timeIntervalSinceNow: 300)
            DispatchQueue.main.async() {
                UIApplication.shared.isIdleTimerDisabled = true
            }
        } else {
            print("setIdleSleepDelay - Disabled by user")
        }
    }

    func disableIdleSleepDelay() {
        print("disableIdleSleepDelay")
        sleepDelayTimeout = nil
        DispatchQueue.main.async() {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
