import re

with open('lib/widgets/message_bubble.dart', 'r') as f:
    content = f.read()

# Finding the exact snippet
target = """            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: isMe
                  ? const Radius.circular(20)
                  : const Radius.circular(4),
              bottomRight: isMe
                  ? const Radius.circular(4)
                  : const Radius.circular(20),
            ),"""

content = content.replace(target, "            borderRadius: BorderRadius.zero,")

# For the other one at the end of the file
target2 = """                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                ),"""
content = content.replace(target2, "                borderRadius: BorderRadius.zero,")

content = re.sub(r'borderRadius: BorderRadius\.circular\([^)]+\)', 'borderRadius: BorderRadius.zero', content)


with open('lib/widgets/message_bubble.dart', 'w') as f:
    f.write(content)
