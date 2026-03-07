import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:point_chat/app.dart';
import 'package:point_chat/providers/auth_provider.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const FocusChatApp(),
      ),
    );
  });
}
