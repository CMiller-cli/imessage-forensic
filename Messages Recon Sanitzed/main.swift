// MARK: - main.swift (Command Line Interface)

import Foundation

func printUsage() {
    print("""
    iMessage Exporter

    Usage: imessage-export [options]

    Options:
      --db <path>           Path to chat.db (default: ~/Library/Messages/chat.db)
      --list                List all conversation threads
      --thread <id>         Export specific thread by ID
      --all                 Export all threads
      --start <datetime>    Start date/time (see formats below)
      --end <datetime>      End date/time (see formats below)
      --output <dir>        Output directory (default: current directory)
      --include-guid        Include GUIDs for threads and messages (for debugging)
      --help                Show this help

    Date/Time Formats (interpreted as local timezone):
      MM/dd/yyyy h:mma      08/22/2025 12:00PM
      MM/dd/yyyy HH:mm      08/22/2025 14:30
      yyyy-MM-dd HH:mm      2025-08-22 14:30
      yyyy-MM-dd h:mma      2025-08-22 2:30PM
      yyyy-MM-dd            2025-08-22 (assumes 00:00:00)
      MM/dd/yyyy            08/22/2025 (assumes 00:00:00)

    Examples:
      imessage-export --list
      imessage-export --thread 5 --start 2024-01-01 --end 2024-12-31 --output ~/Desktop
      imessage-export --thread 5 --start "08/22/2025 12:00PM" --end "08/25/2025 2:00PM"
      imessage-export --all --output ~/Documents/MessageExports

    Note: Times are interpreted in your local timezone (\(TimeZone.current.identifier)).
          iMessage stores dates in UTC internally, so conversions are handled automatically.
    """)
}

func parseDate(_ string: String) -> Date? {
    let formatter = DateFormatter()
    // Use local timezone - user inputs are interpreted as local time
    formatter.timeZone = TimeZone.current

    // Try datetime format first: MM/dd/yyyy hh:mma (e.g., 08/22/2025 12:00PM)
    formatter.dateFormat = "MM/dd/yyyy hh:mma"
    if let date = formatter.date(from: string.replacingOccurrences(of: " ", with: " ").trimmingCharacters(in: .whitespaces)) {
        return date
    }

    // Try without space before AM/PM: MM/dd/yyyy hh:mmaa
    formatter.dateFormat = "MM/dd/yyyy h:mma"
    if let date = formatter.date(from: string) {
        return date
    }

    // Try 24-hour format: MM/dd/yyyy HH:mm
    formatter.dateFormat = "MM/dd/yyyy HH:mm"
    if let date = formatter.date(from: string) {
        return date
    }

    // Try ISO-style datetime: yyyy-MM-dd HH:mm
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    if let date = formatter.date(from: string) {
        return date
    }

    // Try ISO-style with time and AM/PM: yyyy-MM-dd hh:mma
    formatter.dateFormat = "yyyy-MM-dd h:mma"
    if let date = formatter.date(from: string) {
        return date
    }

    // Fall back to date-only format: yyyy-MM-dd (assumes start of day)
    formatter.dateFormat = "yyyy-MM-dd"
    if let date = formatter.date(from: string) {
        return date
    }

    // Try US date format without time: MM/dd/yyyy (assumes start of day)
    formatter.dateFormat = "MM/dd/yyyy"
    if let date = formatter.date(from: string) {
        return date
    }

    return nil
}

func main() {
    let args = CommandLine.arguments

    // Default values - use standard macOS paths
    var dbPath = NSString(string: "~/Library/Messages/chat.db").expandingTildeInPath
    var shouldList = false
    var threadId: Int? = nil
    var exportAll = false
    var startDate: Date? = nil
    var endDate: Date? = nil
    var outputDir = FileManager.default.currentDirectoryPath
    var includeGuid = false

    // Parse arguments
    var i = 1
    while i < args.count {
        switch args[i] {
        case "--db":
            i += 1
            if i < args.count { dbPath = NSString(string: args[i]).expandingTildeInPath }
        case "--list":
            shouldList = true
        case "--include-guid":
            includeGuid = true
        case "--thread":
            i += 1
            if i < args.count { threadId = Int(args[i]) }
        case "--all":
            exportAll = true
        case "--start":
            i += 1
            if i < args.count { startDate = parseDate(args[i]) }
        case "--end":
            i += 1
            if i < args.count { endDate = parseDate(args[i]) }
        case "--output":
            i += 1
            if i < args.count { outputDir = NSString(string: args[i]).expandingTildeInPath }
        case "--help":
            printUsage()
            exit(0)
        default:
            print("Unknown option: \(args[i])")
            printUsage()
            exit(1)
        }
        i += 1
    }

    // Check for Full Disk Access
    let fileManager = FileManager.default
    if !fileManager.isReadableFile(atPath: dbPath) {
        print("ERROR: Cannot read \(dbPath)")
        print("Make sure you have granted Full Disk Access to Terminal (or this app)")
        print("System Preferences > Security & Privacy > Privacy > Full Disk Access")
        exit(1)
    }

    do {
        let db = try ChatDatabase(path: dbPath)
        let threads = try db.fetchAllThreads()

        if shouldList {
            print("\n=== Conversation Threads ===\n")
            for thread in threads {
                print("ID: \(thread.id)")
                print("Title: \(thread.title)")
                if includeGuid {
                    print("GUID: \(thread.guid)")
                }
                print("---")
            }
            print("\nTotal: \(threads.count) threads")
            exit(0)
        }

        // Create output directory if needed
        try fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        let threadsToExport: [ChatThread]
        if let id = threadId {
            guard let thread = threads.first(where: { $0.id == id }) else {
                print("Thread with ID \(id) not found")
                exit(1)
            }
            threadsToExport = [thread]
        } else if exportAll {
            threadsToExport = threads
        } else {
            printUsage()
            exit(1)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        for thread in threadsToExport {
            print("Exporting: \(thread.title)...")

            let messages = try db.fetchMessages(
                forThreadId: thread.id,
                startDate: startDate,
                endDate: endDate
            )

            if messages.isEmpty {
                print("  No messages found in date range")
                continue
            }

            // Sanitize filename
            let safeTitle = thread.title
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
                .prefix(50)

            let filename = "Messages_\(safeTitle)_\(thread.id).txt"
            let outputPath = URL(fileURLWithPath: outputDir).appendingPathComponent(String(filename))

            // Export as plain text
            var output = "=== \(thread.title) ===\n"
            if includeGuid {
                output += "Thread GUID: \(thread.guid)\n"
            }
            output += "Messages: \(messages.count)\n"
            output += String(repeating: "=", count: 40) + "\n\n"

            for message in messages {
                let sender = message.isFromMe ? "Me" : (message.senderIdentifier ?? "Unknown")
                let dateStr = dateFormatter.string(from: message.date)
                output += "[\(dateStr)] \(sender):\n"
                output += "\(message.displayText)\n"
                if includeGuid {
                    output += "  (GUID: \(message.guid))\n"
                }
                output += "\n"
            }

            try output.write(to: outputPath, atomically: true, encoding: .utf8)
            print("  Exported \(messages.count) messages to \(outputPath.path)")
        }

        print("\nExport complete!")

    } catch {
        print("Error: \(error.localizedDescription)")
        exit(1)
    }
}

main()
