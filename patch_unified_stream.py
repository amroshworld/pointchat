import re

with open('lib/screens/stream/unified_stream_screen.dart', 'r') as f:
    content = f.read()

# Add the import
if "import '../../widgets/pixel_symbol.dart';" not in content:
    content = content.replace(
        "import '../../widgets/message_bubble.dart';",
        "import '../../widgets/message_bubble.dart';\nimport '../../widgets/pixel_symbol.dart';"
    )

# Replace the text-based @/# with PixelSymbol in the handle display UI
# Need to find `Text(initials` and `Text(handle` uses.

# In the _StreamItemTile build method:
# Text(handleText) or Text(initials) - actually, the tile shows the handle text itself.
content = re.sub(
    r"Text\(\s*handleText,\s*style:\s*GoogleFonts\.inter\(\s*color:\s*handleColor,\s*fontWeight:\s*isUnread\s*\?\s*FontWeight\.w700\s*:\s*FontWeight\.w600,\s*fontSize:\s*16,\s*letterSpacing:\s*-0\.3,\s*\),\s*maxLines:\s*1,\s*overflow:\s*TextOverflow\.ellipsis,\s*\),",
    r"""Row(
                                children: [
                                  PixelSymbol(
                                    isGroup: isGroup,
                                    color: handleColor,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      handleText.substring(1), // hide @ or #
                                      style: GoogleFonts.inter(
                                        color: handleColor,
                                        fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                                        fontSize: 16,
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),""",
    content,
    flags=re.DOTALL
)


# In Search matches (ListTile):
# title: Text(_formatHandle(name)) / title: Text(handle)
content = re.sub(
    r"title:\s*Text\(\s*user\.displayName,\s*style:\s*GoogleFonts\.inter\(\s*color:\s*AppTheme\.textPri,\s*fontSize:\s*13,\s*\),\s*\),",
    r"""title: Row(
                              children: [
                                PixelSymbol(isGroup: false, color: AppTheme.purple, size: 10),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    user.displayName,
                                    style: GoogleFonts.inter(color: AppTheme.textPri, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),""",
    content,
    flags=re.DOTALL
)

# And in _buildUserItem logic where it creates handles:
content = re.sub(
    r"title:\s*Text\(handle\),",
    r"""title: Row(
                          children: [
                            PixelSymbol(isGroup: handle.startsWith('#'), color: handle.startsWith('#') ? AppTheme.green : AppTheme.purple, size: 12),
                            const SizedBox(width: 6),
                            Expanded(child: Text(handle.substring(1))),
                          ],
                        ),""",
    content,
    flags=re.DOTALL
)

with open('lib/screens/stream/unified_stream_screen.dart', 'w') as f:
    f.write(content)
