import re

def main():
    login_screen = "lib/screens/auth/login_screen.dart"
    with open(login_screen, "r", encoding="utf-8") as f:
        content = f.read()
    content = content.replace("const BorderSide(", "BorderSide(")
    with open(login_screen, "w", encoding="utf-8") as f:
        f.write(content)
        
    ai_sub = "lib/screens/subscription/ai_subscription_screen.dart"
    with open(ai_sub, "r", encoding="utf-8") as f:
        content = f.read()
    content = content.replace("const BorderSide(color: Theme.of(context)", "BorderSide(color: Theme.of(context)")
    with open(ai_sub, "w", encoding="utf-8") as f:
        f.write(content)

    chat_list = "lib/screens/chat/chat_list_screen.dart"
    with open(chat_list, "r", encoding="utf-8") as f:
        content = f.read()
    content = content.replace("const Icon(Icons.close, color: _textSecondary)", "Icon(Icons.close, color: _textSecondary)")
    content = content.replace("child: const CircularProgressIndicator(color: _accent)", "child: CircularProgressIndicator(color: _accent)")
    content = content.replace("const TextStyle(color: _textSecondary, fontSize: 13)", "TextStyle(color: _textSecondary, fontSize: 13)")
    content = content.replace("const TextStyle(color: _textPrimary, fontSize: 13)", "TextStyle(color: _textPrimary, fontSize: 13)")
    content = content.replace("const TextStyle(color: _textPrimary, fontSize: 15)", "TextStyle(color: _textPrimary, fontSize: 15)")
    content = content.replace("const TextStyle(color: _textSecondary, fontSize: 15)", "TextStyle(color: _textSecondary, fontSize: 15)")
    content = content.replace("const Icon(Icons.chat_bubble_outline, size: 60, color: _textSecondary)", "Icon(Icons.chat_bubble_outline, size: 60, color: _textSecondary)")
    
    with open(chat_list, "w", encoding="utf-8") as f:
        f.write(content)

if __name__ == '__main__':
    main()
