# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PointChat is a Flutter chat application backed by **Appwrite Tables DB** (not the legacy Databases document API). It supports 1:1 messaging, group chats, AI bots, voice messages, file sharing, location sharing, and read receipts.

## Common Commands

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Analyze for errors
flutter analyze

# Build for Android
flutter build apk --release

# Build for iOS (requires macOS)
flutter build ios --release

# Run a single test file
flutter test test/path/to/file_test.dart
```

## Architecture

### State Management
Uses **Riverpod** (`flutter_riverpod`). See `providers/` for auth and theme providers.

### Data Layer (Critical)
- **All app data uses Tables DB**: `appwriteTablesDB.listRows/getRow/updateRow/createRow`
- **Never use** the legacy `Databases` document API for app tables
- `AppwriteConstants` (`usersCollection`, `chatsCollection`, etc.) hold **table IDs**, not collection names

### Appwrite Realtime (Critical)
Use `AppwriteRealtimeChannels.tableRows(tableId)` or `tableRow(tableId, rowId)` from `appwrite_client.dart`.
- **Do not** subscribe with `databases.*.collections.*.documents*` — those channels do not fire for Tables DB row changes and the UI will appear "stuck"

### Models
- `UserModel`, `ChatModel`, `MessageModel`, `GroupModel`, `BotModel` in `lib/models/`
- `UserModel.onlineFlag` is the raw DB field; `isOnline` getter applies a 5-minute TTL using `lastSeen`

### Services
- `ChatService`, `GroupService`, `UserService`, `AuthService` in `lib/services/`
- Presence/heartbeat managed by `UnifiedStreamScreen` (`_startHeartbeat`/`_stopHeartbeat`). Call `_stopHeartbeat` on dispose and on `paused`/`detached`/`hidden` lifecycle states.

### Screens
- `lib/screens/chat/` — Chat list and individual chat
- `lib/screens/group/` — Group list, chat, and info
- `lib/screens/people/` — People search and user info
- `lib/screens/stream/` — UnifiedStreamScreen (presence/heartbeat owner)
- `lib/screens/auth/` — Login
- `lib/screens/profile/` — Profile and settings
- `lib/screens/subscription/` — AI subscription (RevenueCat)

### Key Patterns
- Streams + Realtime for lists that users expect to update live (chats, messages, users, groups, invites)
- Per-member unread counts stored as JSON strings in `chats.unreadCount` and `groups.unreadCount`
- Bots are excluded from group invites (`UserModel.isExcludedFromGroups`)
- Shared preferences used for default seen/notify settings per chat

## Appwrite Cloud Functions

Located in `appwrite_functions/`:
- `chat_ai/` — AI chat functionality using @ai-sdk
- `delete_old_media/` — Cleanup of old media files

## CI/CD

- **Android**: `.github/workflows/android-release.yml` builds on push/PR to main
- **iOS**: `.github/workflows/ios-build.yml` (macOS runners) for unsigned `.app.zip` on push/PR; manual `workflow_dispatch` for signed `.ipa` with TestFlight upload support

## Cursor Rules

`.cursor/rules/pointchat-appwrite.mdc` contains critical rules for Appwrite Tables DB and Realtime usage. Apply them when editing data layer code.
