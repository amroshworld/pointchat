import Foundation

public struct KeyboardQuickReply: Codable {
    public let id: String
    public let title: String
    public let text: String
    public let category: String?
    public let order: Int?
}

public struct KeyboardRecentChat: Codable {
    public let chatId: String
    public let title: String
    public let avatar: String?
    public let otherUserId: String?
    public let lastMessage: String?
    public let lastMessageTime: String?
    public let lastMessageSenderId: String?
    public let unreadCount: Int?
    public let isGroup: Bool?
    public let isOnline: Bool?
    public let participants: [String]?
}

public class SharedStorage {
    public static let shared = SharedStorage()
    public static let appGroupId = "group.com.amrosh.Pointchat"

    private var defaults: UserDefaults? {
        return UserDefaults(suiteName: SharedStorage.appGroupId) ?? UserDefaults.standard
    }

    public var userId: String {
        return defaults?.string(forKey: "pointchat_kb_userId") ?? ""
    }

    public var userName: String {
        return defaults?.string(forKey: "pointchat_kb_userName") ?? "User"
    }

    public var userPhotoUrl: String {
        return defaults?.string(forKey: "pointchat_kb_userPhoto") ?? ""
    }

    public var endpoint: String {
        return defaults?.string(forKey: "pointchat_kb_endpoint") ?? "https://fra.cloud.appwrite.io/v1"
    }

    public var projectId: String {
        return defaults?.string(forKey: "pointchat_kb_project") ?? "69a6d89d0007909f06f7"
    }

    public var databaseId: String {
        return defaults?.string(forKey: "pointchat_kb_database") ?? "pointchat_db"
    }

    public var jwt: String {
        return defaults?.string(forKey: "pointchat_kb_jwt") ?? ""
    }

    public func getQuickReplies() -> [KeyboardQuickReply] {
        guard let jsonStr = defaults?.string(forKey: "pointchat_kb_quick_replies"),
              let data = jsonStr.data(using: .utf8) else {
            return [
                KeyboardQuickReply(id: "1", title: "I'm on my way!", text: "I'm on my way! Will be there shortly.", category: "Status", order: 1),
                KeyboardQuickReply(id: "2", title: "Call you soon", text: "In a meeting right now. Can I call you in a bit?", category: "Status", order: 2),
                KeyboardQuickReply(id: "3", title: "Sounds great!", text: "Sounds great! Looking forward to it.", category: "Quick", order: 3),
                KeyboardQuickReply(id: "4", title: "Got it, thanks!", text: "Got it, thanks for letting me know!", category: "Quick", order: 4),
            ]
        }
        return (try? JSONDecoder().decode([KeyboardQuickReply].self, from: data)) ?? []
    }

    public func getRecentChats() -> [KeyboardRecentChat] {
        guard let jsonStr = defaults?.string(forKey: "pointchat_kb_recent_chats"),
              let data = jsonStr.data(using: .utf8) else {
            return []
        }
        return (try? JSONDecoder().decode([KeyboardRecentChat].self, from: data)) ?? []
    }
}
