import Foundation

public class AppwriteLightClient {
    public static let shared = AppwriteLightClient()

    /// Sends a message via TablesDB. Uses JWT if available (shared from host app).
    /// Correct endpoint: /v1/tablesdb/{databaseId}/tables/{tableId}/rows  with {rowId, data}
    public func sendMessage(
        chatId: String,
        text: String,
        isGroup: Bool = false,
        completion: @escaping (Bool, String?) -> Void
    ) {
        let storage = SharedStorage.shared
        let userId = storage.userId
        let userName = storage.userName
        let userPhoto = storage.userPhotoUrl
        let endpoint = storage.endpoint
        let projectId = storage.projectId
        let databaseId = storage.databaseId
        let jwt = storage.jwt

        guard !userId.isEmpty else {
            completion(false, "User not authenticated — open PointChat to sync")
            return
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(false, "Empty message")
            return
        }

        // TablesDB path
        let tableId = "messages"
        let urlString = "\(endpoint)/tablesdb/\(databaseId)/tables/\(tableId)/rows"
        guard let url = URL(string: urlString) else {
            completion(false, "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(projectId, forHTTPHeaderField: "X-Appwrite-Project")
        if !jwt.isEmpty {
            request.setValue(jwt, forHTTPHeaderField: "X-Appwrite-JWT")
        }
        request.setValue("1.6.0", forHTTPHeaderField: "X-Appwrite-Response-Format")

        let rowId = "msg_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(20))"
        var data: [String: Any] = [
            "senderId": userId,
            "senderName": userName,
            "senderPhotoUrl": userPhoto,
            "text": trimmed,
            "type": "text",
            "isRead": false,
            "readBy": "{\"\(userId)\": true}"
        ]
        if isGroup {
            data["groupId"] = chatId
        } else {
            data["chatId"] = chatId
        }

        let payload: [String: Any] = [
            "rowId": rowId,
            "data": data
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            completion(false, error.localizedDescription)
            return
        }

        let session = URLSession(configuration: .ephemeral)
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    completion(true, nil)
                } else {
                    var detail = "status \(httpResponse.statusCode)"
                    if let data = data, let body = String(data: data, encoding: .utf8) {
                        // Trim large bodies
                        detail += " — \(String(body.prefix(400)))"
                        print("[PointChatKB] send failed \(httpResponse.statusCode): \(body)")
                    }
                    completion(false, "Server \(detail)")
                }
            } else {
                completion(false, "No response")
            }
        }
        task.resume()
    }
}
