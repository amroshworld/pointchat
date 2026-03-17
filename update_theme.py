import re

with open('lib/theme/app_theme.dart', 'r') as f:
    content = f.read()

# Replace colors
content = re.sub(r'static const Color darkBg = [^;]+;', 'static const Color darkBg = Color(0xFF26333B);', content)
content = re.sub(r'static const Color darkSurface = [^;]+;', 'static const Color darkSurface = Color(0xFF384B49);', content)
content = re.sub(r'static const Color darkSurface2 = [^;]+;', 'static const Color darkSurface2 = Color(0xFF5E7D78);', content)
content = re.sub(r'static const Color darkBorder = [^;]+;', 'static const Color darkBorder = Color(0xFF5E7D78);', content)
content = re.sub(r'static const Color darkMuted = [^;]+;', 'static const Color darkMuted = Color(0xFF995B36);', content)
content = re.sub(r'static const Color darkTextPri = [^;]+;', 'static const Color darkTextPri = Color(0xFFFFFFFF);', content)
content = re.sub(r'static const Color darkTextSec = [^;]+;', 'static const Color darkTextSec = Color(0xFFC08B57);', content)

content = re.sub(r'static const Color primaryAccent = [^;]+;', 'static const Color primaryAccent = Color(0xFFC08B57);', content)
content = re.sub(r'static const Color success = [^;]+;', 'static const Color success = Color(0xFF5E7D78);', content)
content = re.sub(r'static const Color error = [^;]+;', 'static const Color error = Color(0xFF995B36);', content)
content = re.sub(r'static const Color warning = [^;]+;', 'static const Color warning = Color(0xFFC08B57);', content)
content = re.sub(r'static const Color focusBlue = [^;]+;', 'static const Color focusBlue = Color(0xFFC08B57);', content)

# Change purple fallback map
content = re.sub(r'static const Color purple = [^;]+;', 'static const Color purple = Color(0xFFC08B57);', content)
content = re.sub(r'static const Color purpleLt = [^;]+;', 'static const Color purpleLt = Color(0xFFC08B57);', content)
content = re.sub(r'static const Color purpleDim = [^;]+;', 'static const Color purpleDim = Color(0xFF5E7D78);', content)

# Remove border radius completely
content = re.sub(r'borderRadius: BorderRadius\.circular\([^)]+\)', 'borderRadius: BorderRadius.zero', content)
content = re.sub(r'borderRadius: BorderRadius\.all\(Radius\.circular\([^)]+\)\)', 'borderRadius: BorderRadius.zero', content)
content = re.sub(r'borderRadius: BorderRadius\.vertical\(top: Radius\.circular\([^)]+\)\)', 'borderRadius: BorderRadius.zero', content)

with open('lib/theme/app_theme.dart', 'w') as f:
    f.write(content)
