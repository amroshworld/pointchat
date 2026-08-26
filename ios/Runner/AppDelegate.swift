import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let keyboardChannelName = "com.amrosh.Pointchat/keyboard_bridge"
  private let appGroupId = "group.com.amrosh.Pointchat"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as? FlutterViewController
    if let messenger = controller?.binaryMessenger {
      setupKeyboardBridgeChannel(messenger: messenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func setupKeyboardBridgeChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: keyboardChannelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      let defaults = UserDefaults(suiteName: self.appGroupId) ?? UserDefaults.standard

      switch call.method {
      case "syncSession":
        if let args = call.arguments as? [String: Any] {
          defaults.set(args["userId"] as? String ?? "", forKey: "pointchat_kb_userId")
          defaults.set(args["userName"] as? String ?? "", forKey: "pointchat_kb_userName")
          defaults.set(args["userEmail"] as? String ?? "", forKey: "pointchat_kb_userEmail")
          defaults.set(args["userPhotoUrl"] as? String ?? "", forKey: "pointchat_kb_userPhoto")
          defaults.set(args["endpoint"] as? String ?? "", forKey: "pointchat_kb_endpoint")
          defaults.set(args["projectId"] as? String ?? "", forKey: "pointchat_kb_project")
          defaults.set(args["databaseId"] as? String ?? "", forKey: "pointchat_kb_database")
          if let jwt = args["jwt"] as? String {
            defaults.set(jwt, forKey: "pointchat_kb_jwt")
          }
          defaults.synchronize()
        }
        result(true)

      case "clearSession":
        defaults.removeObject(forKey: "pointchat_kb_userId")
        defaults.removeObject(forKey: "pointchat_kb_userName")
        defaults.removeObject(forKey: "pointchat_kb_userEmail")
        defaults.removeObject(forKey: "pointchat_kb_userPhoto")
        defaults.removeObject(forKey: "pointchat_kb_recent_chats")
        defaults.removeObject(forKey: "pointchat_kb_jwt")
        defaults.synchronize()
        result(true)

      case "syncQuickReplies":
        if let args = call.arguments as? [String: Any],
           let jsonStr = args["quickRepliesJson"] as? String {
          defaults.set(jsonStr, forKey: "pointchat_kb_quick_replies")
          defaults.synchronize()
        }
        result(true)

      case "syncRecentChats":
        if let args = call.arguments as? [String: Any],
           let jsonStr = args["recentChatsJson"] as? String {
          defaults.set(jsonStr, forKey: "pointchat_kb_recent_chats")
          defaults.synchronize()
        }
        result(true)

      case "openKeyboardSettings":
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url, options: [:], completionHandler: { success in
            result(success)
          })
        } else {
          result(false)
        }

      case "isKeyboardEnabled":
        // UITextInputMode check is unreliable for extensions; return whether we have synced chats
        let hasChats = defaults.string(forKey: "pointchat_kb_recent_chats") != nil
        let hasUser = (defaults.string(forKey: "pointchat_kb_userId") ?? "").isEmpty == false
        // Also try input modes as secondary signal
        let modes = UITextInputMode.activeInputModes
        let reported = modes.contains { mode in
          let lang = mode.primaryLanguage ?? ""
          return lang.contains("Pointchat") || lang.contains("PointChat")
        }
        result(reported || (hasChats && hasUser))

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
