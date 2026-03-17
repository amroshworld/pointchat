import re

with open('lib/screens/auth/login_screen.dart', 'r') as f:
    content = f.read()

# Replace the gradient logic with simple solid background
content = re.sub(
    r'Positioned\.fill\(\s*child:\s*DecoratedBox\(\s*decoration:\s*BoxDecoration\(\s*gradient:\s*LinearGradient\(.*?\),\s*\),\s*\),\s*\)',
    'Positioned.fill(\n              child: DecoratedBox(\n                decoration: BoxDecoration(\n                  color: Theme.of(context).scaffoldBackgroundColor,\n                ),\n              ),\n            )',
    content,
    flags=re.DOTALL
)

# Update the logo
content = re.sub(
    r'// ── Logo mark ──(.*?)const SizedBox\(height: 48\),',
    '''// ── Logo mark ──
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: AppTheme.darkBg,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),''',
    content,
    flags=re.DOTALL
)

# Replace all `borderRadius: BorderRadius.circular(x)` with `borderRadius: BorderRadius.zero`
content = re.sub(r'borderRadius: BorderRadius\.circular\([^)]+\)', 'borderRadius: BorderRadius.zero', content)

with open('lib/screens/auth/login_screen.dart', 'w') as f:
    f.write(content)
