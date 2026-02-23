# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MQTTool is an iOS app (Swift, UIKit) for testing MQTT broker connections. It connects to MQTT brokers, subscribes to topics, and publishes messages. Published on the App Store.

## Build

Open `MQTTool.xcworkspace` in Xcode (not the .xcodeproj). Build with Xcode or:

```
xcodebuild -workspace MQTTool.xcworkspace -scheme MQTTool -sdk iphonesimulator build
```

### Dependency

The project depends on [Moscapsule](https://github.com/flightonary/Moscapsule), a Swift wrapper around libmosquitto. It must be manually checked out and its project file included in the workspace per Moscapsule's "Manual Installation" instructions. The Moscapsule module is imported in `MQTToolConnection.swift` and `SubscribeViewController.swift`.

## Architecture

**UI pattern**: UIKit with Storyboards (`Main.storyboard`). Tab bar controller with four tabs: Connect, Subscribe, Publish, and Stats/About.

**Global state**: Connection state is managed through module-level globals in `LoginViewController.swift`:
- `mqttConnection: MQTToolConnection?` — the active MQTT connection
- `connectionState: ConnectionState` — enum tracking Disconnected/Connected/Connecting
- `userSettings: UserSettings` — shared Core Data-backed settings manager

View controllers observe connection changes via `NotificationCenter` (notification name: `networkNotify`). The subscribe view also listens for `updateSubscriptionTopic` notifications from the detail view.

**Key classes**:
- `MQTToolConnection` — wraps Moscapsule's `MQTTClient`/`MQTTConfig`. Manages message list (capped at 50), publish/subscribe operations, and reconnect storm throttling (max 10 disconnects/minute).
- `UserSettings` — Core Data persistence layer using a manual `NSPersistentStoreCoordinator` stack (not `NSPersistentContainer`). Stores connection, subscription, and publish history (max 10 items each) in `UserSettings.sqlite`. Three Core Data entities: `ConnectSetting`, `SubscribeSetting`, `PublishSetting`.
- `LoginViewController` — handles connect/disconnect lifecycle on a background queue
- `SubscribeViewController` — polls for new messages on a 0.5s timer, displays them in a UITableView, manages idle sleep delay
- `PublishViewController` — publishes messages synchronously via `DispatchSemaphore`
- `DetailViewController` — modal detail view for individual messages; allows changing subscription topic via notification

**Core Data model**: `UserSettings.xcdatamodeld` — entities use `timestamp` for sort ordering (most recent first).
