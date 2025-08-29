import UserNotifications
import Intents
import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var notificationTapEventListener: NotificationTapEventListener?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Use `DesignVariables.mainBackground` color as the background color
    // of the default UIView.
    window?.backgroundColor = UIColor(named: "LaunchBackground");

    let controller = window?.rootViewController as! FlutterViewController

    // Retrieve the remote notification payload from launch options;
    // this will be null if the launch wasn't triggered by a notification.
    let notificationPayload = launchOptions?[.remoteNotification] as? [AnyHashable : Any]
    let api = NotificationHostApiImpl(notificationPayload.map { NotificationDataFromLaunch(payload: $0) })
    NotificationHostApiSetup.setUp(binaryMessenger: controller.binaryMessenger, api: api)

    notificationTapEventListener = NotificationTapEventListener()
    NotificationTapEventsStreamHandler.register(with: controller.binaryMessenger, streamHandler: notificationTapEventListener!)

    UNUserNotificationCenter.current().delegate = self

    // Register notification category with text input action for reply
    let replyAction = UNTextInputNotificationAction(
      identifier: "REPLY_ACTION",
      title: "Reply",
      options: [],
      textInputButtonTitle: "Send",
      textInputPlaceholder: "Type your reply..."
    )
    let messageCategory = UNNotificationCategory(
      identifier: "MESSAGE_CATEGORY",
      actions: [replyAction],
      intentIdentifiers: [],
      options: []
    )
    UNUserNotificationCenter.current().setNotificationCategories([messageCategory])

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
  let userInfo = response.notification.request.content.userInfo
  if response.actionIdentifier == "REPLY_ACTION" {
    if let textResponse = response as? UNTextInputNotificationResponse {
      let replyText = textResponse.userText
      // Handle the reply text, e.g., send to server or Flutter
      // You may want to pass this to Flutter via eventSink or method channel
      notificationTapEventListener?.onNotificationTapEvent(payload: ["reply": replyText, "userInfo": userInfo])
    }
  } else if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
    notificationTapEventListener?.onNotificationTapEvent(payload: userInfo)
  }
  completionHandler()

  // Example: Show sender's profile image using INSendMessageIntent (for rich notifications)
  // This is typically done when creating the notification content, e.g., in a notification service extension.
  // Here is a sample for reference:
  /*
  let intent = INSendMessageIntent(
    recipients: [INPerson(personHandle: INPersonHandle(value: "sender@example.com", type: .emailAddress), nameComponents: nil, displayName: "Sender Name", image: INImage(url: URL(string: "https://example.com/profile.png")), contactIdentifier: nil, customIdentifier: nil, isMe: false, suggestionType: .none)],
    outgoingMessageType: .outgoing,
    content: "Message content",
    speakableGroupName: nil,
    conversationIdentifier: "conversation_id",
    serviceName: nil,
    sender: nil
  )
  let interaction = INInteraction(intent: intent, response: nil)
  interaction.donate(completion: nil)
  */
  }
}

private class NotificationHostApiImpl: NotificationHostApi {
  private let maybeDataFromLaunch: NotificationDataFromLaunch?

  init(_ maybeDataFromLaunch: NotificationDataFromLaunch?) {
    self.maybeDataFromLaunch = maybeDataFromLaunch
  }

  func getNotificationDataFromLaunch() -> NotificationDataFromLaunch? {
    maybeDataFromLaunch
  }
}

// Adapted from Pigeon's Swift example for @EventChannelApi:
//   https://github.com/flutter/packages/blob/2dff6213a/packages/pigeon/example/app/ios/Runner/AppDelegate.swift#L49-L74
class NotificationTapEventListener: NotificationTapEventsStreamHandler {
  var eventSink: PigeonEventSink<NotificationTapEvent>?

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<NotificationTapEvent>) {
    eventSink = sink
  }

  func onNotificationTapEvent(payload: [AnyHashable : Any]) {
    eventSink?.success(NotificationTapEvent(payload: payload))
  }
}
