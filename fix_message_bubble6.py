import re

with open('lib/widgets/message_bubble.dart', 'r') as f:
    content = f.read()

# Replace border radius ONLY if it matches the exact 8-line pattern
# Pattern 1
pattern1 = r"""            borderRadius: BorderRadius\.only\(\n\s*topLeft: const Radius\.circular\(20\),\n\s*topRight: const Radius\.circular\(20\),\n\s*bottomLeft: isMe\n\s*\? const Radius\.circular\(20\)\n\s*: const Radius\.circular\(4\),\n\s*bottomRight: isMe\n\s*\? const Radius\.circular\(4\)\n\s*: const Radius\.circular\(20\),\n\s*\),"""
content = re.sub(pattern1, '            borderRadius: BorderRadius.zero,', content, flags=re.MULTILINE)

# Pattern 2
pattern2 = r"""                borderRadius: BorderRadius\.only\(\n\s*topLeft: const Radius\.circular\(12\),\n\s*topRight: const Radius\.circular\(12\),\n\s*bottomLeft: isMe \? const Radius\.circular\(12\) : Radius\.zero,\n\s*bottomRight: isMe \? Radius\.zero : const Radius\.circular\(12\),\n\s*\),"""
content = re.sub(pattern2, '                borderRadius: BorderRadius.zero,', content, flags=re.MULTILINE)

content = re.sub(r'borderRadius: BorderRadius\.circular\([^)]+\)', 'borderRadius: BorderRadius.zero', content)


with open('lib/widgets/message_bubble.dart', 'w') as f:
    f.write(content)
