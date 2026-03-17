import re

with open('lib/screens/stream/unified_stream_screen.dart', 'r') as f:
    content = f.read()

# I also need to update the _StreamItemWidget class
# Let's see how `initials` and the main tile title is displayed.
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

with open('lib/screens/stream/unified_stream_screen.dart', 'w') as f:
    f.write(content)
