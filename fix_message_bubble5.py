import re

with open('lib/widgets/message_bubble.dart', 'r') as f:
    content = f.read()

# Replace border radius ONLY if it matches the outer structure correctly
# We are currently replacing something that breaks the syntax. Let's see the context.

def replacer(match):
    return 'borderRadius: BorderRadius.zero,'

# Replace everything starting from `borderRadius: BorderRadius.only(` until `),`
# Let's use a simpler approach. Just read the file and replace line by line.
lines = content.split('\n')
new_lines = []
skip = False
for line in lines:
    if 'borderRadius: BorderRadius.only(' in line:
        skip = True
        new_lines.append('            borderRadius: BorderRadius.zero,')
        continue

    if skip:
        if '),' in line:
            # check if this is the end of the only
            if 'topLeft' not in line and 'topRight' not in line and 'bottomLeft' not in line and 'bottomRight' not in line:
                skip = False
        continue

    # Also replace circular
    line = re.sub(r'borderRadius: BorderRadius\.circular\([^)]+\)', 'borderRadius: BorderRadius.zero', line)

    new_lines.append(line)

with open('lib/widgets/message_bubble.dart', 'w') as f:
    f.write('\n'.join(new_lines))
