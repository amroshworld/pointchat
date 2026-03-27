# PointChat Codebase Structure

This document outlines the core architectural structure of the PointChat application to help you understand the files and folders.

## High-Level Architecture
The app follows a service-oriented architecture using `flutter_riverpod` for state management and `appwrite` as the backend service.

### 1. `lib/models/`
Contains the core data structures used throughout the app. These models typically include `fromJson` and `toMap` methods for serialization with Appwrite endpoints.
- `user_model.dart`: Represents a user (display name, photo, online status).
- `message_model.dart`: Represents chat messages (text, image, system messages).
- `chat_model.dart`: Represents a 1-on-1 direct message conversation.
- `group_model.dart`: Represents a group conversation including members, admins, and pending invites.
- `bot_model.dart`: Represents AI/bot entities within the chat.

### 2. `lib/services/`
Contains singleton classes responsible for interacting directly with the Appwrite backend or third-party APIs.
- `auth_service.dart`: Handles login, registration, and Google OAuth.
- `user_service.dart`: Fetches user profiles and manages online presence statuses.
- `chat_service.dart` & `group_service.dart`: The main engines for sending/receiving messages and managing direct message/group chat metadata.
- `ai_service.dart` & `bot_service.dart`: Manages integrations with the Gemini API or custom AI bots.
- `notification_service.dart`: Handles push notifications.
- `cache_service.dart` & `subscription_service.dart`: Auxiliary services for localized caching and premium subscription states.

### 3. `lib/screens/`
Organized by feature domain. Each folder typically contains the main screen and its immediate sub-screens.
- `auth/`: Login and registration UI components.
- `home/`: The main dashboard of the app (might redirect to `stream/`).
- `stream/`: Contains `unified_stream_screen.dart`, which is the primary inbox view combining individual chats and group messages into a single timeline.
- `chat/`: Contains 1-on-1 messaging screens (`chat_screen.dart`).
- `group/`: Screens for creating and managing group details (`group_chat_screen.dart`, `group_info_screen.dart`).
- `profile/`: User settings, privacy preferences, and subscription UI.
- `people/`: Screens for browsing other users or finding contacts.

### 4. `lib/widgets/`
Reusable UI components used across multiple screens.
- `user_avatar.dart`: Handles drawing user and group picture circles, including the green online status rings.
- `message_bubble.dart`: Renders individual chat message balloons.
- `chat_tile.dart`: The list item used to represent a chat in a list view.
- `typing_indicator.dart`: The animated ellipsis for when a user is typing.
- `voice_message_player.dart`: UI for playing back audio files.

### 5. `lib/providers/`
Likely contains Riverpod providers that expose instances of the services and manage global app states natively.

## Data Flow Summary
1. The **UI (`screens/`)** observes state using **Riverpod (`providers/`)**.
2. User actions trigger methods on **Providers**, which delegate complex logic to **Services (`services/`)**.
3. Services make API calls to **Appwrite** and convert the JSON responses into **Models (`models/`)**.
4. The streams update the UI automatically.
