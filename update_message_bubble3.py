import re

with open('lib/widgets/message_bubble.dart', 'r') as f:
    content = f.read()

# Instead of using a broad regex that failed, let's just find and replace the block
# Or just replace `BorderRadius.only(...)` with `BorderRadius.zero` more accurately.
content = re.sub(
    r'borderRadius: BorderRadius\.only\([\s\S]*?,\s*\),',
    'borderRadius: BorderRadius.zero,',
    content
)
content = re.sub(r'borderRadius: BorderRadius\.circular\([^)]+\)', 'borderRadius: BorderRadius.zero', content)


with open('lib/widgets/message_bubble.dart', 'w') as f:
    f.write(content)
