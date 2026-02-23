//
//  LoginViewController.swift
//  MQTTool
//
//  Created by Brent Petit on 2/18/16.
//  Copyright © 2016-2019 Brent Petit. All rights reserved.
//

import UIKit
import CoreData
import Security

class LoginViewController: UIViewController, UITextFieldDelegate {

    var timer: Timer!

    var gradientView = GradientView()

    var defaultClientId = "MQTTool"

    @IBOutlet weak var clientIdTextField: UITextField!
    @IBOutlet weak var hostnameTextField: UITextField!
    @IBOutlet weak var hostPortTextField: UITextField!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var savePasswordSwitch: UISwitch!
    @IBOutlet weak var historyButton: UIButton!

    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var cleanSessionSwitch: UISwitch!


    @IBOutlet weak var connectionStatusLabel: UILabel!

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        // Initialize Tab Bar Item
        tabBarItem = UITabBarItem(title: "Connect", image: UIImage(named: "Connect.png"), tag: 1)

    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.defaultClientId = "MQTTool-\(UUID().uuidString.prefix(8))"
        clientIdTextField.placeholder = self.defaultClientId

        let gradientView = GradientView(frame: self.view.bounds)
        self.view.insertSubview(gradientView, at: 0)

        clientIdTextField.delegate = self
        hostnameTextField.delegate = self
        hostPortTextField.delegate = self
        usernameTextField.delegate = self
        passwordTextField.delegate = self

        loadDefaults()
    }

    // Just call the function to update the UI
    override func viewWillAppear(_ animated: Bool) {
        updateUI()
    }

    // General purpose function to update UI fields based on
    // the state of the connection
    func updateUI() {
        let mgr = ConnectionManager.shared
        DispatchQueue.main.async() {
            if mgr.connectionState == .Connected {
                if let conn = mgr.mqttConnection {
                    if conn.hostName.isEmpty {
                        if let hostname = self.hostnameTextField.text {
                            conn.hostName = hostname
                        } else {
                            return
                        }
                        if let port_string = self.hostPortTextField.text {
                            if Int64(port_string) != nil {
                                conn.hostPort = port_string
                            } else {
                                return
                            }
                        } else {
                            return
                        }
                    }
                    self.hostnameTextField.text = conn.hostName
                    self.hostPortTextField.text = conn.hostPort
                    self.connectionStatusLabel.text = "Status: Connected to " + conn.hostName + ":" +
                        conn.hostPort
                    self.connectButton.setTitle("Disconnect", for: .normal)
                } else {
                    self.connectionStatusLabel.text = "Status: Error - connect failed"
                }
            } else if mgr.connectionState == .Connecting {
                if mgr.mqttConnection != nil {
                    self.connectionStatusLabel.text = "Status: Connecting to " +
                                self.hostnameTextField.text! + ":" +
                                self.hostPortTextField.text!
                } else {
                    self.connectionStatusLabel.text = "Status: Connecting..."
                }
                self.connectButton.setTitle("Cancel", for: .normal)
            } else {

                self.connectionStatusLabel.text = "Status: Disconnected"
                self.connectButton.setTitle("Connect", for: .normal)
            }
        }
    }

    // When the view is first loaded, load the last saved settings for the connect tab
    func loadDefaults() {
        let mgr = ConnectionManager.shared
        if mgr.userSettings.retrieveConnections() &&
             mgr.userSettings.connection_list != nil {

            print("loadDefaults... item count = \(mgr.userSettings.connection_list!.count)")
            if let latest = mgr.userSettings.connection_list!.first {
            print("in loadDefaults... found\n")

                self.hostnameTextField.text = latest.hostname
                self.hostPortTextField.text = "\(latest.port)"
                self.clientIdTextField.text = latest.sessionID
                self.usernameTextField.text = latest.username
                self.passwordTextField.text = latest.password
                self.savePasswordSwitch.isOn = latest.savepassword
            }
        } else {
            print("in loadDefaults... not found\n")
        }
    }

    // Save the current settings on the connect tab
    func saveDefaults() {
        let mgr = ConnectionManager.shared
        var port: Int64?
        var password: String?
        // Save off the settings
        print("in saveDefaults... ")
        port = Int64(self.hostPortTextField.text!)

        if self.hostnameTextField.text == nil ||
            port == nil {
            print("saveDefaults... hostname or port not set")
            return
        }

        // Pass nil into save function if savePassword is off
        if self.savePasswordSwitch!.isOn {
            password = self.passwordTextField.text
        }

        mgr.userSettings.updateConnection(hostname: self.hostnameTextField.text!,
                                      port: port!,
                                      sessionID: self.clientIdTextField.text!,
                                      clean: self.cleanSessionSwitch.isOn,
                                      username: self.usernameTextField.text,
                                      password: password)

        print("done\n")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            // Dismiss the keyboard
            DispatchQueue.main.async() {
                textField.resignFirstResponder()
            }
        return true
    }

    @IBAction func connectButtonPressed() {
        let mgr = ConnectionManager.shared
        print("Your pressed the " + (connectButton.titleLabel?.text)! + " button")
        // Check that we didn't automatically reconnect and the UI is out of sync
        if let client = mgr.mqttConnection?.mqttClient {
            if client.connState == .connected && mgr.connectionState != .Connected {
                print("Oops, I'm already connected")
                handleConnect(returnString: "Automatically Connected")
                return
            }
        }

        // Fall out early if the host or port is empty
        if self.hostnameTextField.text!.isEmpty {
            DispatchQueue.main.async() {
                self.connectionStatusLabel.text = "Status: Error - Bad host value"
            }
            return
        }
        if self.hostPortTextField.text!.isEmpty {
            DispatchQueue.main.async() {
                self.connectionStatusLabel.text = "Status: Error - Bad port value"
            }
            return
        }

        if mgr.connectionState == .Disconnected {
            var clientId: String

            mgr.mqttConnection = nil

            print("Connecting...")

            DispatchQueue.main.async() {
                if self.clientIdTextField.text!.isEmpty {
                    self.clientIdTextField.text = self.clientIdTextField.placeholder
                }
            }

            self.handleConnecting()

            if self.clientIdTextField.text!.isEmpty {
                clientId = self.clientIdTextField.placeholder!
            } else {
                clientId = self.clientIdTextField.text!
            }

            // Was a clean or durable session requested?
            let cleanSession = self.cleanSessionSwitch.isOn
            let username = self.usernameTextField.text
            let password = self.passwordTextField.text
            let hostname = self.hostnameTextField.text
            let port = self.hostPortTextField.text

            // If there is an object, dereference it here before the next connection.
            // This prevents the disconnect handler from ripping the object out from
            //  under other views...
            DispatchQueue.global(qos: .userInitiated).async {
                // Make sure there isn't a lingering connection attempt out there
                if mgr.mqttConnection != nil {
                    mgr.mqttConnection!.disconnect()
                    mgr.mqttConnection = nil
                }
                if username != "" && password != "" {
                    mgr.mqttConnection = MQTToolConnection(hostname: hostname!,
                                                       port: port!,
                                                       username: username!,
                                                       password: password!,
                                                       clientId: clientId)

                } else {
                    // We're not using the login info, don't save anything
                    DispatchQueue.main.async() {
                        self.savePasswordSwitch.isOn = false
                    }
                    mgr.mqttConnection = MQTToolConnection(hostname: hostname!,
                                                       port: port!,
                                                       username: nil,
                                                       password: nil,
                                                       clientId: clientId)
                }

                // Verify that the Connection object was successfully created
                if mgr.mqttConnection != nil {
                    mgr.mqttConnection!.setCleanSession(option: cleanSession)
                    mgr.mqttConnection!.setDisconnectCallback(callback: self.setDisconnected)
                    mgr.mqttConnection!.setConnectCallback(callback: self.setConnected)

                    // We are connecting, save off the current settings
                    DispatchQueue.main.async() {
                        self.saveDefaults()
                    }

                    print("Going into connect()")
                    if mgr.mqttConnection!.connect() == false {
                        self.handleDisconnect(disconnectString: "Failed to create connection")
                    }

                    self.handleConnecting()

                } else {
                    print("Failed to create mqttConnection")
                    self.handleDisconnect(disconnectString: "Failed to create connection")
                }
            }
        } else if mgr.connectionState == .Connected {
            print("Disconnecting...")
            handleDisconnect(disconnectString: "User Request")
            if mgr.mqttConnection != nil {
                DispatchQueue.global(qos: .userInitiated).async {
                    mgr.mqttConnection!.disconnect()
                }
            }
            mgr.connectionState = .Disconnected
        } else if mgr.connectionState == .Connecting {
            print("Cancelling connection")
            if mgr.mqttConnection != nil {
                DispatchQueue.global(qos: .userInitiated).async {
                    mgr.mqttConnection!.disconnect()
                }
            }
            handleDisconnect(disconnectString: "Connect Cancelled")
        }

        saveDefaults()

    }


    // Callbacks for handling a connect or disconnect event
    func setConnected(returnValue: Int, returnString: String) {
        let mgr = ConnectionManager.shared
        print("In setConnected returnValue=\(returnValue) returnString=\(returnString)")

        mgr.queue.sync() {
            if returnValue == 0 {
                self.handleConnect(returnString: returnString)
            } else {
                // Error
                self.handleConnectError(errorString: returnString)
            }

            NotificationCenter.default.post(name: ConnectionManager.networkNotify, object: self)
        }
    }

    func setDisconnected(returnValue: Int, returnString: String) {
        let mgr = ConnectionManager.shared
        print("In setDisconnected returnValue=\(returnValue) returnString=\(returnString)")

        mgr.queue.sync() {
            DispatchQueue.main.async() {
                self.connectionStatusLabel.text = "Status Disconnected: \(returnString)"
            }
            self.handleDisconnect(disconnectString: returnString)
            NotificationCenter.default.post(name: ConnectionManager.networkNotify, object: self)
        }
    }

    // Update state in UI to reflect that we are connected
    //
    func handleConnecting() {
        ConnectionManager.shared.connectionState = .Connecting
        updateUI()
    }

    // Update state in UI to reflect that we are connected
    //
    func handleConnect(returnString: String) {
        ConnectionManager.shared.connectionState = .Connected
        updateUI()
    }

    // Update state in UI to reflect that we are disconnected
    //
    func handleDisconnect(disconnectString: String) {
        ConnectionManager.shared.connectionState = .Disconnected
        updateUI()
        DispatchQueue.main.async() {
            self.connectionStatusLabel.text = "Status: Disconnected " + disconnectString
        }
    }

    func handleConnectError(errorString: String) {
        let mgr = ConnectionManager.shared
        DispatchQueue.main.async() {
            self.connectionStatusLabel.text = "Status: Error connecting " + errorString
        }
        if mgr.mqttConnection != nil {
            mgr.mqttConnection!.disconnect()
        }
    }

    @IBAction func historyButtonPressed(_ sender: UIButton) {
        let mgr = ConnectionManager.shared
        let alertController: UIAlertController

        if mgr.userSettings.retrieveConnections() == false ||
            mgr.userSettings.connection_list == nil ||
            mgr.userSettings.connection_list!.count == 0 {

            alertController = UIAlertController(title: "Alert", message: "No history available", preferredStyle: .alert)

            alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
                NSLog("The \"OK\" alert occured.")
            }))
        } else {

            alertController = UIAlertController(title: "Connect History", message: "Select a host", preferredStyle: .actionSheet)

            for setting in mgr.userSettings.connection_list! {
                alertController.addAction(UIAlertAction(title: "\(setting.hostname!):\(setting.port)", style: .default, handler: { (action) in
                    //execute some code when this option is selected
                    print("\(setting.hostname!) selected")
                    self.hostnameTextField.text = setting.hostname
                    self.hostPortTextField.text = "\(setting.port)"
                    self.clientIdTextField.text = setting.sessionID
                    self.usernameTextField.text = setting.username
                    self.passwordTextField.text = setting.password
                    self.savePasswordSwitch.isOn = setting.savepassword
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
}
