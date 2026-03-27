# Implementation Plan

## Goal Description
Fix message routing for group mentions, update group addition behavior, fix focus mode behavior on long press, automatically mark messages as read when expanding a chat, improve the chat PIN setup UI, fix swipe behavior in chat to bounce instead of swiping fully to end, and correct the online status ring for individuals and groups.

## User Review Required
> [!IMPORTANT]
> The "Reduce Motion" setting does not exist in the codebase. I will assume this refers to the "lighter animations" text in the settings menu and any related animation constants. If there is a specific "reduce motion" variable I missed, please let me know.
> I will update the Swipe actions to use a bounce back effect using `confirmDismiss` and/or tweaking thresholds.

## Proposed Changes

### Stream Routing & Focus Mode
#### [MODIFY] `lib/screens/stream/unified_stream_screen.dart`
- Fix message routing to support `@user #group message` pattern ensuring it sends to all users.
- Implement group updates so `#group @user` adds missing users, and `#group @user "message"` sends to all.
- Fix focus mode so long pressing a chat doesn't clear focus mode, but instead sets or maintains it (auto-expand logic).
- Automatically mark messages as read when expanding a chat by calling `ChatService.markMessagesAsRead`.
- Modify `Dismissible` widgets to return `false` on `confirmDismiss` so they bounce back, but still perform their actions (e.g. `ChatPrivacyPreferences.toggleLocked`).

### User Interface & Profile Settings
#### [MODIFY] `lib/screens/profile/profile_screen.dart`
- Remove references to "lighter animations" or "reduce motion" in the settings list.

#### [MODIFY] `lib/screens/profile/chat_privacy_settings_screen.dart`
- Overhaul the Chat Security PIN setup to look more professional with clear visual indicators if a PIN is set.

### Widgets & Components
#### [MODIFY] `lib/widgets/user_avatar.dart`
- Update `UserAvatar` and `GroupAvatar` to correctly calculate and display the online ring completion rate based on online participants.

## Verification Plan
### Automated Tests
- Run `flutter analyze` to ensure no syntax errors or linter warnings are introduced.
- Build the app using `flutter build apk --debug` to verify the build process.

### Manual Verification
- Review the code changes logically to ensure correctness for all points requested.
- Deploy to emulator/device to verify UI interactions (PIN, bouncing swipe, ring colors).
