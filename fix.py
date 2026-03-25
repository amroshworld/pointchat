import re

with open('lib/screens/chat/chat_list_screen.dart', 'r') as f:
    content = f.read()

old_code = """    if (_isSelectionMode && _selectedChatIds.isNotEmpty) {
      for (final chatId in _selectedChatIds) {
        await _chatService.sendMessage(
          chatId: chatId,
          senderId: widget.currentUserId,
          senderName: senderName,
          senderPhotoUrl: senderPhoto,
          text: text,
        );
      }
      _clearSelection();"""

new_code = """    if (_isSelectionMode && _selectedChatIds.isNotEmpty) {
      await Future.wait(
        _selectedChatIds.map(
          (chatId) => _chatService.sendMessage(
            chatId: chatId,
            senderId: widget.currentUserId,
            senderName: senderName,
            senderPhotoUrl: senderPhoto,
            text: text,
          ),
        ),
      );
      _clearSelection();"""

new_content = content.replace(old_code, new_code)

if old_code in content:
    with open('lib/screens/chat/chat_list_screen.dart', 'w') as f:
        f.write(new_content)
    print("Success")
else:
    print("Code not found")
