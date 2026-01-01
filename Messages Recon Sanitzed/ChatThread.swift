//
//  ChatThread.swift
//  Chatwork2
//


// MARK: - Models.swift

import Foundation

struct ChatThread: Identifiable {
    let id: Int
    let guid: String
    let displayName: String?
    let participants: [String]

    var title: String {
        if let name = displayName, !name.isEmpty {
            return name
        }
        return participants.joined(separator: ", ")
    }
}

struct ChatMessage: Identifiable {
    let id: Int
    let guid: String
    let text: String?
    let date: Date
    let isFromMe: Bool
    let senderIdentifier: String?

    var displayText: String {
        return text ?? ""
    }

    var senderDisplay: String {
        if isFromMe {
            return "Me"
        }
        return senderIdentifier ?? "Unknown"
    }
}
