import os

def replace_in_file(filepath, old_str, new_str):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    content = content.replace(old_str, new_str)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

login_file = 'lib/screens/auth/login_screen.dart'
sub_file = 'lib/screens/subscription/ai_subscription_screen.dart'
chat_list_file = 'lib/screens/chat/chat_list_screen.dart'
stream_file = 'lib/screens/stream/unified_stream_screen.dart'

# Fix login_screen
replace_in_file(login_file, 'const BorderSide(', 'BorderSide(')

# Fix subscription screen
replace_in_file(sub_file, 'const BorderSide(', 'BorderSide(')

# Fix chat_list_screen
replace_in_file(chat_list_file, 'const Icon(Icons.close, color: _textSecondary)', 'Icon(Icons.close, color: _textSecondary)')
replace_in_file(chat_list_file, '''const Center(
                  child: CircularProgressIndicator(color: _accent),
                )''', '''Center(
                  child: CircularProgressIndicator(color: _accent),
                )''')
replace_in_file(chat_list_file, '''const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Center(
              child: Text(
                'No messages yet',
                style: TextStyle(color: _textSecondary, fontSize: 13),
              ),''', '''Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Center(
              child: Text(
                'No messages yet',
                style: TextStyle(color: _textSecondary, fontSize: 13),
              ),''')
replace_in_file(chat_list_file, '''style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 14,
                            height: 1.35,
                          )''', '''style: TextStyle(
                            color: _textPrimary,
                            fontSize: 14,
                            height: 1.35,
                          )''')
replace_in_file(chat_list_file, '''style: const TextStyle(
                                color: _textSecondary,
                                fontSize: 10,
                              )''', '''style: TextStyle(
                                color: _textSecondary,
                                fontSize: 10,
                              )''')
replace_in_file(chat_list_file, 'style: const TextStyle(color: _textPrimary, fontSize: 15)', 'style: TextStyle(color: _textPrimary, fontSize: 15)')
replace_in_file(chat_list_file, 'hintStyle: const TextStyle(color: _textSecondary, fontSize: 15)', 'hintStyle: TextStyle(color: _textSecondary, fontSize: 15)')
replace_in_file(chat_list_file, '''const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 60, color: _textSecondary),''', '''Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 60, color: _textSecondary),''')

# Fix unified_stream_screen.dart (unused warning)
replace_in_file(stream_file, '  List<Map<String, dynamic>> _latestCombinedItems = [];\n', '')
