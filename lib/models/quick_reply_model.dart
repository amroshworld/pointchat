import 'dart:convert';

class QuickReplyModel {
  final String id;
  final String title;
  final String text;
  final String category;
  final int order;

  const QuickReplyModel({
    required this.id,
    required this.title,
    required this.text,
    this.category = 'General',
    this.order = 0,
  });

  factory QuickReplyModel.fromMap(Map<String, dynamic> map, [String? fallbackId]) {
    return QuickReplyModel(
      id: (map['id'] ?? fallbackId ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      text: (map['text'] ?? '').toString(),
      category: (map['category'] ?? 'General').toString(),
      order: (map['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'text': text,
      'category': category,
      'order': order,
    };
  }

  QuickReplyModel copyWith({
    String? id,
    String? title,
    String? text,
    String? category,
    int? order,
  }) {
    return QuickReplyModel(
      id: id ?? this.id,
      title: title ?? this.title,
      text: text ?? this.text,
      category: category ?? this.category,
      order: order ?? this.order,
    );
  }

  static List<QuickReplyModel> defaultReplies() {
    return const [
      QuickReplyModel(
        id: 'default_1',
        title: "I'm on my way!",
        text: "I'm on my way! Will be there shortly.",
        category: 'Status',
        order: 1,
      ),
      QuickReplyModel(
        id: 'default_2',
        title: 'Call you soon',
        text: 'In a meeting right now. Can I call you in a bit?',
        category: 'Status',
        order: 2,
      ),
      QuickReplyModel(
        id: 'default_3',
        title: 'Sounds great!',
        text: 'Sounds great! Looking forward to it.',
        category: 'Quick',
        order: 3,
      ),
      QuickReplyModel(
        id: 'default_4',
        title: 'Got it, thanks!',
        text: 'Got it, thanks for letting me know!',
        category: 'Quick',
        order: 4,
      ),
      QuickReplyModel(
        id: 'default_5',
        title: 'Let me check',
        text: 'Let me check on this and get back to you.',
        category: 'Work',
        order: 5,
      ),
    ];
  }

  static String encodeList(List<QuickReplyModel> list) {
    return jsonEncode(list.map((e) => e.toMap()).toList());
  }

  static List<QuickReplyModel> decodeList(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return defaultReplies();
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded
            .map((e) => QuickReplyModel.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return defaultReplies();
  }
}
