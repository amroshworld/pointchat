import re

with open('lib/widgets/message_bubble.dart', 'r') as f:
    content = f.read()

# Let's find out where the error is. The `borderRadius` is in AnimatedContainer decoration.
# We'll just carefully replace the contents.
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

target2 = """                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                ),"""
content = content.replace(target2, "                borderRadius: BorderRadius.zero,")

# Do not run a global regex `borderRadius: BorderRadius.circular` blindly, as it might mess up something else.
# Let's see what else might be there using circular.
content = content.replace('borderRadius: BorderRadius.circular(12),', 'borderRadius: BorderRadius.zero,')
content = content.replace('borderRadius: BorderRadius.circular(8),', 'borderRadius: BorderRadius.zero,')

with open('lib/widgets/message_bubble.dart', 'w') as f:
    f.write(content)
