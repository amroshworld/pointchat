import re

with open('lib/widgets/message_bubble.dart', 'r') as f:
    content = f.read()

# Replace border radius logic with simple zero radius
content = re.sub(
    r'borderRadius: BorderRadius\.only\([^)]+\)',
    'borderRadius: BorderRadius.zero',
    content,
    flags=re.DOTALL
)

with open('lib/widgets/message_bubble.dart', 'w') as f:
    f.write(content)
