# iMessage Exporter

A starter project from hard lessons learned demonstrating how to read and search iMessages from the macOS Messages database.

## Overview

This Swift command-line tool shows how to:

- Connect to the iMessage SQLite database
- Query conversation threads and participants
- Fetch messages with date filtering
- Export conversations to plain text files

## Requirements

- macOS
- Full Disk Access permission for Terminal (or the compiled binary)
- Swift 5.0+

## Usage

```bash
# Build
swift build

# List all conversation threads
imessage-export --list

# Export a specific thread
imessage-export --thread 5 --output ~/Desktop

# Export all threads
imessage-export --all --output ~/Documents/MessageExports

# Export with date range
imessage-export --thread 5 --start 2024-01-01 --end 2024-12-31

# Use a different database path
imessage-export --db /path/to/chat.db --list
```

## Options

| Option | Description |
|--------|-------------|
| `--db <path>` | Path to chat.db (default: ~/Library/Messages/chat.db) |
| `--list` | List all conversation threads |
| `--thread <id>` | Export specific thread by ID |
| `--all` | Export all threads |
| `--start <date>` | Start date filter |
| `--end <date>` | End date filter |
| `--output <dir>` | Output directory (default: current directory) |
| `--include-guid` | Include GUIDs for debugging |
| `--help` | Show help |

## Date Formats

Dates can be specified in these formats (interpreted as local timezone):

- `MM/dd/yyyy h:mma` - 08/22/2025 12:00PM
- `MM/dd/yyyy HH:mm` - 08/22/2025 14:30
- `yyyy-MM-dd HH:mm` - 2025-08-22 14:30
- `yyyy-MM-dd` - 2025-08-22 (assumes 00:00:00)
- `MM/dd/yyyy` - 08/22/2025 (assumes 00:00:00)

## Granting Full Disk Access

To read the Messages database, you need to grant Full Disk Access:

1. Open System Preferences > Security & Privacy > Privacy
2. Select "Full Disk Access" from the left sidebar
3. Click the lock to make changes
4. Add Terminal.app (or your compiled binary)

## Project Structure

```
Messages Recon Sanitized/
  main.swift         - CLI entry point and argument parsing
  ChatDatabase.swift - SQLite database access
  ChatThread.swift   - Data models (ChatThread, ChatMessage)
```

## License

MIT License

Copyright (c) 2025 Charles Miller

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
