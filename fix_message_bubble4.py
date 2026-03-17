import re

with open('lib/widgets/message_bubble.dart', 'r') as f:
    content = f.read()

content = re.sub(
    r'borderRadius:\s*BorderRadius\.only\([^)]+\),',
    'borderRadius: BorderRadius.zero,',
    content,
    flags=re.DOTALL
)
content = re.sub(
    r'borderRadius:\s*BorderRadius\.only\((?:[^)(]|\([^)(]*\))*\),',
    'borderRadius: BorderRadius.zero,',
    content,
    flags=re.DOTALL
)

with open('lib/widgets/message_bubble.dart', 'w') as f:
    f.write(content)
