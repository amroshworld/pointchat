import re

with open('lib/widgets/chat_tile.dart', 'r') as f:
    content = f.read()

# Replace border radius
content = re.sub(r'borderRadius: BorderRadius\.circular\([^)]+\)', 'borderRadius: BorderRadius.zero', content)

with open('lib/widgets/chat_tile.dart', 'w') as f:
    f.write(content)
