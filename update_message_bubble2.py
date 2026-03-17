import re

with open('lib/widgets/message_bubble.dart', 'r') as f:
    content = f.read()

# The issue was that I replaced "borderRadius: BorderRadius.only(...)" which was inside a BoxDecoration
# with "borderRadius: BorderRadius.zero". But it was probably inside a multi-line only(...) call and my
# regex substitution might have messed up the syntax or left dangling arguments. Let's do it carefully.

# Replace the specific block of borderRadius
content = re.sub(
    r'borderRadius: BorderRadius\.only\([\s\S]*?\),',
    'borderRadius: BorderRadius.zero,',
    content
)

with open('lib/widgets/message_bubble.dart', 'w') as f:
    f.write(content)
