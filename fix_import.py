import re

with open('lib/screens/stream/unified_stream_screen.dart', 'r') as f:
    content = f.read()

# Make sure pixel_symbol is imported
if "import '../../widgets/pixel_symbol.dart';" not in content:
    content = content.replace(
        "import '../../widgets/message_bubble.dart';",
        "import '../../widgets/message_bubble.dart';\nimport '../../widgets/pixel_symbol.dart';"
    )

with open('lib/screens/stream/unified_stream_screen.dart', 'w') as f:
    f.write(content)
