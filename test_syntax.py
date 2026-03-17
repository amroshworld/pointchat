import subprocess
try:
    subprocess.check_output(['flutter', 'analyze', 'lib/screens/stream/unified_stream_screen.dart'])
    print("Syntax ok")
except Exception as e:
    print("Syntax error")
