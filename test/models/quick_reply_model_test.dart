import 'package:flutter_test/flutter_test.dart';
import 'package:point_chat/models/quick_reply_model.dart';

void main() {
  group('QuickReplyModel', () {
    test('defaultReplies returns populated list of default replies', () {
      final defaults = QuickReplyModel.defaultReplies();
      expect(defaults.length, greaterThanOrEqualTo(4));
      expect(defaults.any((r) => r.title == "I'm on my way!"), isTrue);
      expect(defaults.any((r) => r.category == 'Status'), isTrue);
    });

    test('fromMap and toMap serialize correctly', () {
      final model = QuickReplyModel(
        id: 'qr_123',
        title: 'Be right back',
        text: 'Stepping away for 5 minutes.',
        category: 'Status',
        order: 10,
      );

      final map = model.toMap();
      expect(map['id'], 'qr_123');
      expect(map['title'], 'Be right back');
      expect(map['text'], 'Stepping away for 5 minutes.');
      expect(map['category'], 'Status');
      expect(map['order'], 10);

      final reconstructed = QuickReplyModel.fromMap(map);
      expect(reconstructed.id, model.id);
      expect(reconstructed.title, model.title);
      expect(reconstructed.text, model.text);
      expect(reconstructed.category, model.category);
      expect(reconstructed.order, model.order);
    });

    test('encodeList and decodeList handle roundtrip correctly', () {
      final list = [
        const QuickReplyModel(id: '1', title: 'Hello', text: 'Hello there!', category: 'General', order: 1),
        const QuickReplyModel(id: '2', title: 'Bye', text: 'Talk soon!', category: 'General', order: 2),
      ];

      final encoded = QuickReplyModel.encodeList(list);
      expect(encoded, isA<String>());

      final decoded = QuickReplyModel.decodeList(encoded);
      expect(decoded.length, 2);
      expect(decoded[0].title, 'Hello');
      expect(decoded[1].text, 'Talk soon!');
    });

    test('decodeList falls back to defaultReplies on null or empty input', () {
      final fromNull = QuickReplyModel.decodeList(null);
      expect(fromNull.isNotEmpty, isTrue);

      final fromEmpty = QuickReplyModel.decodeList('');
      expect(fromEmpty.isNotEmpty, isTrue);

      final fromInvalid = QuickReplyModel.decodeList('invalid-json');
      expect(fromInvalid.isNotEmpty, isTrue);
    });

    test('copyWith creates modified copy', () {
      const original = QuickReplyModel(id: '1', title: 'Test', text: 'Test text', category: 'General', order: 1);
      final modified = original.copyWith(title: 'Updated Title', order: 5);

      expect(modified.id, '1');
      expect(modified.title, 'Updated Title');
      expect(modified.text, 'Test text');
      expect(modified.order, 5);
    });
  });
}
