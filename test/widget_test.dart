import 'package:flutter_test/flutter_test.dart';
import 'package:focus_world/app.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FocusChatApp());
  });
}
