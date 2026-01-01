//
//  ChatDatabase.swift
//  Chatwork2
//


// MARK: - ChatDatabase.swift

import Foundation
import SQLite3

class ChatDatabase {
    private var db: OpaquePointer?
    private let dbPath: String

    init(path: String) throws {
        self.dbPath = path
        let immutablePath = "file:\(path)?immutable=1"

        guard sqlite3_open_v2(immutablePath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))
            throw ChatDatabaseError.openFailed(error)
        }

//        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
//            let error = String(cString: sqlite3_errmsg(db))
//            throw ChatDatabaseError.openFailed(error)
//        }
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Fetch All Threads

    func fetchAllThreads() throws -> [ChatThread] {
        let query = """
            SELECT
                c.ROWID,
                c.guid,
                c.display_name,
                GROUP_CONCAT(h.id, ', ') as participants
            FROM chat c
            LEFT JOIN chat_handle_join chj ON c.ROWID = chj.chat_id
            LEFT JOIN handle h ON chj.handle_id = h.ROWID
            GROUP BY c.ROWID
            ORDER BY c.ROWID DESC
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw ChatDatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }

        var threads: [ChatThread] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let rowId = Int(sqlite3_column_int64(statement, 0))
            let guid = String(cString: sqlite3_column_text(statement, 1))
            let displayName = sqlite3_column_text(statement, 2).map { String(cString: $0) }
            let participantsString = sqlite3_column_text(statement, 3).map { String(cString: $0) } ?? ""
            let participants = participantsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

            threads.append(ChatThread(
                id: rowId,
                guid: guid,
                displayName: displayName,
                participants: participants
            ))
        }

        return threads
    }

    // MARK: - Fetch Messages for Thread

    func fetchMessages(forThreadId threadId: Int, startDate: Date? = nil, endDate: Date? = nil) throws -> [ChatMessage] {
        var query = """
            SELECT
                m.ROWID,
                m.guid,
                m.text,
                m.date,
                m.is_from_me,
                h.id as sender
            FROM message m
            JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
            LEFT JOIN handle h ON m.handle_id = h.ROWID
            WHERE cmj.chat_id = ?
            """

        var params: [Any] = [threadId]

        // Apple's date format: nanoseconds since 2001-01-01
        if let start = startDate {
            query += " AND m.date >= ?"
            params.append(dateToAppleTimestamp(start))
        }

        if let end = endDate {
            query += " AND m.date <= ?"
            params.append(dateToAppleTimestamp(end))
        }

        query += " ORDER BY m.date ASC"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw ChatDatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }

        // Bind parameters
        sqlite3_bind_int64(statement, 1, Int64(threadId))

        var paramIndex: Int32 = 2
        if startDate != nil {
            sqlite3_bind_int64(statement, paramIndex, params[1] as! Int64)
            paramIndex += 1
        }
        if endDate != nil {
            sqlite3_bind_int64(statement, paramIndex, params[params.count - 1] as! Int64)
        }

        var messages: [ChatMessage] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let rowId = Int(sqlite3_column_int64(statement, 0))
            let guid = String(cString: sqlite3_column_text(statement, 1))
            let text = sqlite3_column_text(statement, 2).map { String(cString: $0) }
            let dateValue = sqlite3_column_int64(statement, 3)
            let date = appleTimestampToDate(dateValue)
            let isFromMe = sqlite3_column_int(statement, 4) == 1
            let sender = sqlite3_column_text(statement, 5).map { String(cString: $0) }

            messages.append(ChatMessage(
                id: rowId,
                guid: guid,
                text: text,
                date: date,
                isFromMe: isFromMe,
                senderIdentifier: sender
            ))
        }

        return messages
    }

    // MARK: - Date Conversion

    // Apple stores dates as nanoseconds since 2001-01-01 (in newer iOS/macOS versions)
    // Older versions used seconds. We need to detect which format.

    private func appleTimestampToDate(_ timestamp: Int64) -> Date {
        let appleEpoch = Date(timeIntervalSinceReferenceDate: 0) // 2001-01-01

        // If timestamp is very large, it's nanoseconds
        if timestamp > 1_000_000_000_000 {
            let seconds = Double(timestamp) / 1_000_000_000.0
            return appleEpoch.addingTimeInterval(seconds)
        } else {
            // Seconds since 2001
            return appleEpoch.addingTimeInterval(Double(timestamp))
        }
    }

    private func dateToAppleTimestamp(_ date: Date) -> Int64 {
        // Convert to nanoseconds since 2001-01-01
        let secondsSince2001 = date.timeIntervalSinceReferenceDate
        return Int64(secondsSince2001 * 1_000_000_000)
    }
}

// MARK: - Errors

enum ChatDatabaseError: Error, LocalizedError {
    case openFailed(String)
    case queryFailed(String)
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let msg): return "Failed to open database: \(msg)"
        case .queryFailed(let msg): return "Query failed: \(msg)"
        case .exportFailed(let msg): return "Export failed: \(msg)"
        }
    }
}
