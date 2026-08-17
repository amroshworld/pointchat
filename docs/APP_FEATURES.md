# PointChat — App Features & Architecture Guide

> This document is a complete, agent-readable reference for the PointChat app.
> Any AI agent (or human developer) should be able to understand the app's
> features, architecture, and behavior from this file alone.
>
> App name: **PointChat: Fast Messenger** · Package/Bundle ID: `com.amrosh.Pointchat`
> Version: `1.0.1+2` · Flutter SDK `>=3.4.0 <4.0.0` · State: production on Google Play, new submission on App Store Connect (in progress)

---

## 1. What is PointChat?

PointChat is a **fast, privacy-focused messenger** with 1:1 chats, group chats,
voice messages, file/photo/location sharing, read receipts, presence, and
security features (app lock with PIN/biometric, per-chat lock, blocking,
reporting). It has a distinctive **black & white, high-contrast design** with
sharp (square) corners and the Inter font.

Backend: **Appwrite** — all data lives in **Appwrite Tables DB** (NOT the legacy
Databases document API). Real-time updates use Tables-DB realtime channels.

---

## 2. Tech Stack & Architecture

| Layer | Technology |
|---|---|
| UI | Flutter (Material 3), Riverpod state management |
| Backend | Appwrite (project `69a6d89d0007909f06f7`, endpoint `https://fra.cloud.appwrite.io/v1`) |
| Database | Appwrite Tables DB — tables: `users`, `chats`, `messages`, `groups`, `group_invites` |
| Storage | Appwrite Storage bucket `chat_files` (images, files, audio) |
| Realtime | Appwrite Realtime, channels `tableRows(tableId)` / `tableRow(tableId, rowId)` |
| Auth | Appwrite Email/Password + Google OAuth (FlutterWebAuth2 on mobile) |
| Local storage | SharedPreferences (settings, caches, PIN, locked chats, blocked users) |
| Notifications | `flutter_local_notifications` (in-app realtime-driven local notifications) |
| Media | `image_picker`, `file_picker`, `record` (audio), `geolocator` (location), `flutter_cache_manager` |
| Biometrics | `local_auth` (fingerprint/face for unlocking) |
| Analytics | Firebase Analytics (Firebase init is fail-safe: app works without it) |

### Critical rules (CLAUDE.md & `.cursor/rules/pointchat-appwrite.mdc`)
- **Always use Tables DB**: `appwriteTablesDB.listRows/getRow/updateRow/createRow`. Never the legacy `Databases` document API for app tables.
- **Realtime channels**: use `AppwriteRealtimeChannels.tableRows(tableId)` / `tableRow(tableId, rowId)`. Subscribing with `databases.*.collections.*.documents*` will NOT fire and the UI will look "stuck".
- `AppwriteConstants` holds **table IDs**, not collection names.

---

## 3. App Bootstrap (`lib/main.dart`)

Startup sequence:
1. `WidgetsFlutterBinding.ensureInitialized()`
2. Firebase init (safe-catch) + `AnalyticsService.instance.initialize()`
3. Hide Android system bottom navigation bar (immersive mode)
4. Ping Appwrite server (`appwriteClient.ping()`)
5. Load cached current user (`AuthService.loadCurrentUser()`)
6. Initialize `NotificationService.instance`
7. Sync app-lock / PIN / locked-chats prefs
8. Run `ProviderScope` → `FocusChatApp`

### App shell (`lib/app.dart`)
- `AuthGate` decides: authenticated → `AppLockGate(UnifiedStreamScreen)`, else `LoginScreen`.
- Loading → branded splash with purple progress bar. Error → "We could not load your account" screen.

---

## 4. Authentication (`lib/screens/auth/login_screen.dart`)

- **"Continue with Google"** button → Appwrite OAuth2 (mobile uses `FlutterWebAuth2` with deep-link callback `appwrite-callback-<projectId>://auth`).
- **Hidden tester login**: tapping the logo **5 times** reveals an email/password form (used by store reviewers).
- Friendly error mapping: wrong credentials, email in use, weak password, invalid email, rate-limited, restricted account.
- Client-side password policy (`password_policy.dart`): min 10 chars, ≥1 uppercase, ≥1 lowercase, ≥1 digit, ≥1 symbol.
- Sign out: sets user offline, deletes session, clears PIN/lock/blocked prefs, unbinds notifications.
- **Delete account**: must type the exact phrase `DELETE MY ACCOUNT`; calls Appwrite function `account_deletion`.

---

## 5. Main Hub — `UnifiedStreamScreen` (the core screen, ~7,900 lines)

Single main screen with 4 tabs: **Stream (chats) · Groups · People · Settings**.
It is also the owner of presence (heartbeat) and several cross-cutting behaviors.

### 5.1 Presence / heartbeat
- Updates `isOnline` + `lastSeen` in the `users` table periodically (`_startHeartbeat`).
- MUST call `_stopHeartbeat` on dispose and on `paused`/`detached`/`hidden` lifecycle states, restart on `resumed`.
- A user is "online" if `onlineFlag` is set AND `lastSeen` is within 5 minutes (`UserModel.isOnline`).

### 5.2 The composer (top of Stream tab) — target-based messaging
The composer works by **mentioning a target**, then sending:
- **`@name`** → global user search (debounced, loading state) → sends a DM.
- **`#group`** → matches user's groups; supports `#name` and `#name~idprefix` disambiguation (`GroupHandleResolver`) when names collide; suggests "Create Group" when no match.
- **`/setting`** slash command → opens Seen & read receipts settings.
- Rotating tips below the composer (`assets/pointchat_tips.json`), hideable via composer settings.

### 5.3 Sending messages (full composer, implemented HERE)
- **Text** messages (optimistic bubble, replaced by realtime).
- **Voice messages**: long-press the mic button to record (max ~60 s), drag left to cancel (drag-to-delete with visual feedback), release to send. Uses `record` package, saved as `.m4a`. Recording requires a target selected first.
- **Photos**: `ImagePicker` (gallery, quality 80, max 1024 px) → square crop → upload to `chat_files` bucket with **public read permission** → 320×320 preview URL.
- **Files**: `FilePicker` → upload with `contentType` and public read permission.
- **Location**: `geolocator` → shares current coordinates as a `MessageType.location` message.
- Sending to a locked DM requires unlock first; blocked users can't be messaged.

### 5.4 Stream chat rows (`StreamItemWidget`)
- Each DM/chat row shows avatar + online dot, name, last message preview, timeago, unread badge (cap "99+").
- **Swipe left = lock/hide chat** (blurred preview + lock icon), **swipe right = delete chat** (confirmation dialog).
- Tap row → expand inline message list (cap 25); long-press → selection mode.
- **Message gestures inside expanded thread**: swipe right = reply, swipe left = delete (own messages only, confirm).
- Group invites section at top: Accept (becomes member) / Decline (removed from pending).

### 5.5 Settings tab (built into this screen)
- **Theme toggle** (dark/light, persisted in SharedPreferences).
- **Seen & read receipts** → opens `SeenMessageSettingsScreen`.
- **Chats & performance** → hosts `ChatSecuritySettingsPanel` (app lock + PIN) and `BlockedUsersScreen`.
- Per-user rows: toggle "turned on seen notifications for this chat", SAFETY section with Block/Unblock buttons.
- Sign out; Delete account (phrase `DELETE MY ACCOUNT`).

### 5.6 Locking behavior
- Locked DMs show blurred preview; expanding requires biometric or PIN.
- Locked chats cannot receive broadcasts until unlocked.

---

## 6. 1:1 Chat Features

### 6.1 Chat list (`lib/screens/chat/chat_list_screen.dart`)
- DM list filtered to exclude blocked users; realtime + cached.
- **Expanded tile** (tap): inline messages; marks read on expand.
- **Selection mode** (long-press): multi-select chats → **Lock selected** / **Unlock selected**.
- **Broadcast composer**: send one message to all selected chats ("Broadcast to N chats…").
- Locked tiles: `ImageFilter.blur` + dark overlay + lock icon; unlock via biometric (stickyAuth) or inline PIN entry.
- Swipe right = delete chat ("Messages will be deleted."), swipe left = lock/unlock.
- Read receipt ticks (`done`/`done_all`), HH:mm timestamps, timeago, unread badges, online indicators.

### 6.2 Full chat (`lib/screens/chat/chat_screen.dart`)
- AppBar: live user stream (name + Online/Offline), overflow menu.
- Reversed message list, **date separators** (Today / Yesterday / weekday / full date).
- **Auto mark-as-read** when receiving messages from the other side.
- Composer: mic ↔ send toggle, recording indicator bar (voice recording here is **TODO** — voice recording is implemented in the main-stream composer).
- **Overflow menu**: View details, Block/Unblock user, Report user, Wallpaper (no-op).
- Blocking: user can't be messaged; blocked-user notice bar replaces composer.
- **Report user**: dialog (Reason required — e.g. spam/harassment; Details optional) → stored locally + in account prefs (capped 200 reports).
- Empty state: "Say hello! 👋".

### 6.3 Message bubble (`lib/widgets/message_bubble.dart`)
- Rounded 16 corners, asymmetric padding, animated 200 ms.
- **RTL detection** by first code unit (Arabic/Hebrew ranges) → right-to-left layout.
- Group messages show sender name; system messages render as centered muted italic pill.
- Time + read-status icon (`done` vs `done_all`).

---

## 7. Group Chats

### 7.1 Group list (`group_list_screen.dart`)
- Groups + pending invites merged, sorted by last message time.
- Rows: name, photo, "sender: message" preview, unread badge, member count.
- Extended FAB **"New Group"** → wizard.

### 7.2 Create group (`create_group_screen.dart`) — two-step wizard
1. **Members**: search (bots excluded), checkbox selection, horizontal chips with remove badges, "Next (N selected)".
2. **Details**: square-cropped group photo (admins), name (required), description (optional), member list ("You — Admin"), Create.
- On create: pending invites created for invitees, system message "Group "X" created", then navigates into the new group chat.

### 7.3 Group chat (`group_chat_screen.dart`)
- Marks group read on open; header shows live member count; tap header → Group info.
- Sender names shown per message run; date separators; optimistic sends; empty state "Start the conversation!".
- Overflow menu: Group info, Leave group (with system message "$userName left the group").

### 7.4 Group info (`group_info_screen.dart`)
- Large header with group photo (admins can change it), description card.
- **Admin actions**: Edit group (name/description), Add members (search by name/email, excludes bots/self/existing/pending, system message "$admin invited N member(s)"), Leave group, Delete group ("permanently delete this group and all its messages for everyone").
- **Members list**: live per-member presence; admin per-member popup: Make admin / Remove admin / Remove from group (system message "$removedByName removed a member").
- Pending membership: Accept/Decline.

### 7.5 Group data model
- `GroupModel`: members, `pendingMemberIds`, `admins`, `isPublic`, per-member `unreadCount`, lastMessage metadata.
- Group handles: `#name`, or `#name~<8-char id prefix>` for disambiguation.

---

## 8. People / Discovery

### 8.1 People tab (`people_screen.dart`)
- **Favorites strip**: horizontal avatars (first 6 visible users), tap to chat.
- Full user list (blocked users filtered out) with "Chat" button → get-or-create chat.
- Search field (client-side filter on name/email).
- Guards: opening a chat with a blocked user shows a warning.

### 8.2 User info (`user_info_screen.dart`)
- Profile card: avatar with online dot, display name, email, status message (monospace/display fonts).
- For other users: **Block/Unblock** and **Report user** buttons.
- Self-view has no action buttons.

---

## 9. Settings & Security

### 9.1 Seen & read receipts (`seen_message_settings_screen.dart`)
- **"Show my read receipts"** (default ON): whether the other side sees your read ticks.
- **"Notify me when seen"** (default OFF): in-app alerts when someone reads your messages.
- "Apply to all chats" → writes defaults to every existing chat.
- Per-chat overrides exist (`seenEnabled`, `notifyOnSeen` per user in `chats` row).
- **Seen access requests**: a user can request seen access (`seenRequests` [{from, to}]); the other side approves/denies (stored on the chat row).

### 9.2 App lock + PIN (`chat_security_panel.dart`, `app_lock_gate.dart`, `pin_setup_screen.dart`, `four_digit_pin_entry.dart`)
- **Lock app when opening**: full-screen lock overlay on app open/resume (biometric or PIN). Re-locks on `AppLifecycleState.resumed`.
- **4-digit PIN**: set/change with verify-current-PIN step (new PIN must differ), confirm step; mismatches reset.
- AppLockGate: greeting with user name, PIN dots, numeric keypad with haptics, fingerprint button when empty, backspace otherwise, "Forgot?" → dialog (logout resets PIN + locked chats).
- The lock overlay only shows when a PIN actually exists (enabling lock forces PIN setup first).

### 9.3 Per-chat lock
- Swipe a DM left to **blur + lock** it; unlock with biometric or PIN.
- Locked chats list persisted in SharedPreferences (`chat_locked_ids_json`).

### 9.4 Blocking
- Block/Unblock from chat overflow, user info, or the settings SAFETY section.
- Blocked list synced locally **and** to Appwrite account prefs, with realtime + 20 s poll refresh.
- Blocked users are hidden from people list and cannot be messaged.

### 9.5 Blocked users screen
- List of blocked users with Unblock buttons; empty state explanation.

---

## 10. Presence & Online Indicators

- `UserModel.isOnline`: `onlineFlag` && `lastSeen` within 5 min TTL.
- User streams (`getUserStream`) add a **1-minute refetch timer** to keep presence TTL accurate on top of realtime.
- Online dot on avatars (square, green/grey).
- **Group presence ring**: `GroupAvatar` draws a green arc proportional to the % of online members.

---

## 11. Notifications (`notification_service.dart`)

- Local notifications channel `pointchat_messages` (high importance).
- Subscribes to `messages` table realtime: on new message → resolves target (DM participant check / group membership check) → shows notification with type-specific preview:
  - Photo: "Sent a photo" · File: "Sent {file}" · Voice: "Sent a voice message" · Location: "Shared a location" · Text: text (trimmed).
- Group invites: "Group invite — Invited to "X" — Open PointChat to accept or decline."
- Own messages are ignored; incremental notification IDs; unbind on sign-out.

---

## 12. Voice Message Playback (`voice_message_player.dart`)

- Play/pause with circular progress ring; **dynamic waveform** (28 bars, custom paint, played portion in accent color).
- **Seek** by tap or horizontal drag on the waveform.
- **Speed control**: 1x → 1.5x → 2x cycle chip.
- Duration display "mm:ss / mm:ss"; resets speed on completion.
- **Robust loading**: downloads via `MediaCacheManager.downloadWithExtension` to a temp `.m4a` file (the Appwrite view endpoint returns `text/plain` without an extension and AVPlayer rejects `.txt`); falls back to URL source; failure → "Could not play this voice message."

---

## 13. Data Layer Details (critical for agents)

### Tables (Appwrite Tables DB)
| Table | Content |
|---|---|
| `users` | uid, displayName, email, photoUrl, status, lastSeen, onlineFlag, chatIds[], groupIds[], favorites[] |
| `chats` | chatId, participants[], lastMessage, lastMessageTime, lastMessageSenderId, **unreadCount (JSON string, per-user)**, **seenEnabled (JSON, per-user)**, **seenRequests (JSON array)**, **notifyOnSeen (JSON, per-user)** |
| `messages` | messageId, chatId/groupId, senderId, senderName, senderPhotoUrl, text, type (text/image/file/audio/location/system), isRead, readBy (JSON map), fileName, fileSize, audioDuration, latitude, longitude |
| `groups` | groupId, name, description, photoUrl, createdBy, members[], pendingMemberIds[], admins[], isPublic, lastMessage*, unreadCount (JSON per-user) |
| `group_invites` | invite rows: groupId, userId, status (pending/approved/exited), actedAt |

### Storage
- Bucket `chat_files`. **Permissions matter**: images/files/audio must be uploaded with `publicReadPermissions()` (read for `Role.any()`), otherwise clients get 401. Uploads also pass an explicit `contentType`.

### JSON-encoded structures
- `unreadCount`, `seenEnabled`, `notifyOnSeen`, `readBy`, `seenRequests` are stored as **JSON strings** in Appwrite rows and parsed defensively (helpers like `GroupModel.decodeUnreadCount`).

### Realtime
- `AppwriteRealtimeChannels.tableRows(tableId)` for lists; `tableRow(tableId, rowId)` for single rows (chat/group streams).
- Pattern everywhere: initial fetch → realtime subscription → **SharedPreferences cache fallback** on errors (chats, messages, groups).

### Presence TTL
- `UserModel.onlineTtlMinutes = 5`. isOnline = flag && within TTL.

---

## 14. Services Overview

| Service | Responsibility |
|---|---|
| `AuthService` | email/Google sign-in, session, user-row upsert, online status, sign-out, account deletion (Appwrite function `account_deletion`) |
| `ChatService` | get-or-create chat, chat/message streams, sendMessage (all types), markMessagesAsRead (honors seenEnabled), seen toggles/requests/apply-all, delete message/chat (batch delete messages 500/batch) |
| `GroupService` | create/update/delete groups, member/admin management, invites via InviteService, messages, read-marking, leave/join, system messages |
| `UserService` | get/search users, live streams + 1-min presence refresh, status update, favorites toggle, photo update |
| `InviteService` | pending invites CRUD (statuses pending/approved/exited) |
| `ModerationService` | block/unblock (local + account prefs), reports (local + prefs, cap 200) |
| `NotificationService` | realtime-driven local notifications for messages + invites |
| `CacheService` | `MediaCacheManager` (30-day stale, 1000 objects) + `downloadWithExtension` for audio |
| `AnalyticsService` | Firebase Analytics init + userId |

---

## 15. Utilities

| File | Purpose |
|---|---|
| `chat_image_upload.dart` | pick → square crop (1:1, max 512) → upload with public read + contentType → 320×320 preview URL |
| `chat_privacy_preferences.dart` | PIN, app-lock flag, locked-chat IDs with Listenables; `clearAll()` on sign-out |
| `composer_preferences.dart` | composer tips rotate/hidden flags |
| `group_handle_resolver.dart` | `#name` / `#name~idprefix` parsing & disambiguation |
| `password_policy.dart` | password strength validation |
| `pointchat_tips.dart` | rotating composer tips from JSON asset |

---

## 16. Theme (`app_theme.dart`)

- **High-contrast black & white**: dark bg `#000000`, surfaces `#121212`/`#222222`, borders `#333333`; light equivalents. Accent inverts (white on dark, black on light).
- Semantic colors: green `#4CAF50` (success/online), red `#F44336` (error), yellow `#FF9800` (warning), blue `#2196F3` (focus).
- Inter font everywhere (with Arabic fallback stack for conversation titles).
- Material 3 with **square corners** (BorderRadius.zero): AppBar, NavigationBar (60 px, icons-only), cards with 1 px borders, filled square inputs, square buttons/FABs, platform page transitions (Zoom on Android, Cupertino on iOS/macOS).

---

## 17. Known TODOs / Incomplete Features (as of 1.0.1+2)

- `ChatScreen` composer: attachment button and voice recording are TODO (fully implemented in the main-stream composer).
- People search field exists but the query is currently hardcoded empty.
- Group list search button is a TODO.
- Wallpaper setting (chat overflow menu) is a no-op.
- `bots` table + `chat_ai` Appwrite function exist in the backend, but the AI/bot feature was **removed from the app** (no AI subscription UI, no bot models in the shipped binary).

---

## 18. Store & Release Facts

- **Google Play**: live app "PointChat: Fast Messenger" (package `com.amrosh.Pointchat`), developer account "Amrosh" (Account ID `5815019363958889340`). Last production update Jul 29, 2026.
- **App Store Connect**: not yet created (new app submission in progress). Team: Amr Taha (Team ID `KGY5RUQ34C`), Xcode signing = Automatic, DEVELOPMENT_TEAM `KGY5RUQ34C`.
- Version `1.0.1+2`; Android minSdk 24, targetSdk 35.
- Tester account for store reviewers (revealed by tapping the login logo 5×): `reviewer.ai.pointchat@gmail.com`.
- Screenshots for the stores live in `screenshots/` (iPhone 16: 1179×2556; iPad Pro 13": 2064×2752; plus a promo video `.mov`).
