//
//  MQTToolConnections.swift
//  MQTTool
//
//  Created by Brent Petit on 2/17/16.
//  Copyright © 2016-2019 Brent Petit. All rights reserved.
//

import Foundation
import CocoaMQTT

enum ConnectionState { case Disconnected, Connected, Connecting }

struct MyMQTTMessage {
    let topic: String
    let payloadString: String?
    let payload: Data?
    let messageId: UInt16
    let qos: Int
    let timestamp: Date
}

class MQTToolConnection: NSObject, CocoaMQTTDelegate {

    var mqttClient: CocoaMQTT?

    var messageList: [MyMQTTMessage]

    // List of recent messages from MQTT message callback

    var maxMessageList = 50
    var newMessage = false
    let messageQueue = DispatchQueue(label: "com.brentpetit.MQTTool.messageQueue")

    var subscriptionTopic: String = ""
    var subscriptionQos: Int32 = 0
    var hostName = ""
    var hostPort = ""

    // Counters
    var messagesSent = 0
    var messagesReceived = 0
    var connectTime: Date?

    let maxDisconnectsInMinute = 10 // If we see more than 10 disconnects in a minute, disconnect hard
    var disconnectsInMinute = 0
    var disconnectTimestamp: Date?

    // Callbacks
    var connectCallback: ((Int, String) -> Void)?
    var disconnectCallback: ((Int, String) -> Void)?

    //
    // Init takes clientId, host and port
    // user and password can be nil, meaning anonymous connection
    //
    init?(hostname: String, port: String, username: String?, password: String?, clientId: String) {
        guard let portNumber = UInt16(port) else {
            print("bad port\n")
            return nil
        }

        print("port = \(portNumber)\n")

        hostName = hostname
        hostPort = port
        connectTime = nil
        messageList = [MyMQTTMessage]()

        super.init()

        let client = CocoaMQTT(clientID: clientId, host: hostname, port: portNumber)
        client.keepAlive = 60
        client.delegate = self
        client.autoReconnect = true

        if let user = username, let pass = password {
            client.username = user
            client.password = pass
        }

        mqttClient = client
    }

    deinit {
        disconnect()
        hostName = ""
        hostPort = ""
    }

    // Set the durability of the session
    func setCleanSession(option: Bool) {
        mqttClient?.cleanSession = option
    }

    func connect() -> Bool {
        // Clean Session, subscribed topic is reset
        if mqttClient?.cleanSession == true {
            subscriptionTopic = ""
        }

        disconnectTimestamp = nil
        disconnectsInMinute = 0

        return mqttClient?.connect() ?? false
    }

    func disconnect() {
        if mqttClient != nil {
            mqttClient?.disconnect()
            mqttClient = nil
            connectTime = nil
            subscriptionTopic = ""
            subscriptionQos = 0
            disconnectTimestamp = nil
            disconnectsInMinute = 0
        }
    }

    // Insert new message into the message list
    func handleNewMessage(topic: String, message: CocoaMQTTMessage, id: UInt16) {
        messageQueue.async {
            let payloadData = Data(message.payload)
            let payloadString = String(data: payloadData, encoding: .utf8)
            let myMessage = MyMQTTMessage(
                topic: message.topic,
                payloadString: payloadString,
                payload: payloadData,
                messageId: id,
                qos: Int(message.qos.rawValue),
                timestamp: Date()
            )
            self.messagesReceived += 1
            self.messageList.insert(myMessage, at: 0)
            // If we've exceeded our max list size, prune the end of the list
            while self.messageList.count > self.maxMessageList {
                self.messageList.removeLast()
            }
            self.newMessage = true
        }
    }

    // Given a particular topic
    func getMessageListForTopic(topic: String) -> [MyMQTTMessage] {
        var messageListForTopic = [MyMQTTMessage]()
        for messageItem in messageList {
            if messageItem.topic == topic {
                messageListForTopic.append(messageItem)
            }
        }
        return messageListForTopic
    }

    func setConnectCallback(callback: ((Int, String) -> Void)?) {
        connectCallback = callback
    }

    func setDisconnectCallback(callback: ((Int, String) -> Void)?) {
        disconnectCallback = callback
    }

    func subscribe(topic: String, qos: Int32) {
        subscriptionTopic = topic
        subscriptionQos = qos
        let mqttQos = CocoaMQTTQoS(rawValue: UInt8(qos)) ?? .qos0
        mqttClient?.subscribe(topic, qos: mqttQos)
    }

    func unsubscribe() {
        mqttClient?.unsubscribe(subscriptionTopic)
        subscriptionTopic = ""
        subscriptionQos = 0
    }

    @discardableResult
    func publish(topic: String, message: Data, qos: Int32, retain: Bool) -> UInt16 {
        let payload = [UInt8](message)
        let mqttQos = CocoaMQTTQoS(rawValue: UInt8(qos)) ?? .qos0
        let mqttMessage = CocoaMQTTMessage(topic: topic, payload: payload, qos: mqttQos, retained: retain)
        let msgId = mqttClient?.publish(mqttMessage) ?? -1
        print("mosqRet = 0, msgeId = \(msgId)")
        return UInt16(msgId)
    }

    // MARK: - CocoaMQTTDelegate

    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        print("Handling connect... \(ack)")
        if ack == .accept {
            connectTime = Date()
            connectCallback?(0, "Connection Accepted")
            // Re-subscribe
            if !subscriptionTopic.isEmpty {
                subscribe(topic: subscriptionTopic, qos: subscriptionQos)
            }
        } else {
            connectCallback?(Int(ack.rawValue), "Connection refused: \(ack)")
        }
    }

    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        messagesSent += 1
        print("Published \(id)")
    }

    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        print("Published ack \(id)")
    }

    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        handleNewMessage(topic: message.topic, message: message, id: id)
    }

    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        print("Subscribed to topics: \(success), failed: \(failed)")
    }

    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {
        print("Unsubscribed from topics: \(topics)")
    }

    func mqttDidPing(_ mqtt: CocoaMQTT) {
    }

    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
    }

    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        let description = err?.localizedDescription ?? "Clean disconnect"
        print("Handling disconnect... \(description)")

        // Throttle reconnect storms...
        if disconnectTimestamp == nil {
            disconnectTimestamp = Date()
            disconnectsInMinute = 1
        } else {
            if disconnectTimestamp! < Date(timeIntervalSinceNow: -60) {
                disconnectTimestamp = nil
                disconnectsInMinute = 0
            } else {
                disconnectsInMinute += 1
                if disconnectsInMinute > maxDisconnectsInMinute {
                    disconnect()
                }
            }
        }
        disconnectCallback?(err != nil ? -1 : 0, description)
    }
}
