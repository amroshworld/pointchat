import re

with open('lib/widgets/message_bubble.dart', 'r') as f:
    content = f.read()

# Replace the specific block of borderRadius
content = re.sub(
    r'borderRadius: BorderRadius\.only\([\s\S]*?bottomRight:[\s\S]*?\),',
    'borderRadius: BorderRadius.zero,',
    content
)

with open('lib/widgets/message_bubble.dart', 'w') as f:
    f.write(content)
