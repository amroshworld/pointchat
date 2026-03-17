import re

with open('lib/screens/stream/unified_stream_screen.dart', 'r') as f:
    content = f.read()

# Remove the white border on the text input
content = re.sub(
    r'color:\s*isFocusModeActive\n\s*\?\s*AppTheme\.focusBlue\n\s*:\s*\(_isAiMode\s*\?\s*AppTheme\.purple\s*:\s*Colors\.white\),',
    'color: isFocusModeActive ? AppTheme.focusBlue : AppTheme.purple,',
    content
)

# And remove gradients that might be remaining inside the file
# Example:
# gradient: const LinearGradient(...) -> color: AppTheme.purple,
content = re.sub(
    r'gradient:\s*(?:const\s*)?LinearGradient\([^)]+\),',
    'color: AppTheme.purple,',
    content,
    flags=re.DOTALL
)


# Remove generic circular borders:
content = re.sub(r'borderRadius: BorderRadius\.circular\([^)]+\)', 'borderRadius: BorderRadius.zero', content)


with open('lib/screens/stream/unified_stream_screen.dart', 'w') as f:
    f.write(content)
