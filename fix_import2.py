import re

with open('lib/screens/stream/unified_stream_screen.dart', 'r') as f:
    content = f.read()

# Make sure pixel_symbol is imported at the top
if "import '../../widgets/pixel_symbol.dart';" not in content:
    content = "import '../../widgets/pixel_symbol.dart';\n" + content

with open('lib/screens/stream/unified_stream_screen.dart', 'w') as f:
    f.write(content)
