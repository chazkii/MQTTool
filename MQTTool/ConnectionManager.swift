//
//  ConnectionManager.swift
//  MQTTool
//
//  Singleton holding shared connection state, extracted from module-level globals.
//

import Foundation

class ConnectionManager {
    static let shared = ConnectionManager()

    var mqttConnection: MQTToolConnection?
    var connectionState = ConnectionState.Disconnected
    let userSettings = UserSettings()

    static let networkNotify = Notification.Name("com.brentpetit.MQTTool.networkNotify")
    static let updateSubscriptionTopic = Notification.Name("updateSubscriptionTopic")

    let queue = DispatchQueue(label: "com.brentpetit.MQTTool.queue.connect")

    private init() {}
}
