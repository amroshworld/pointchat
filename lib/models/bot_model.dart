class BotModel {
  final String botId;
  final String name;
  final String ownerId;
  final String instructions;
  final String photoUrl;
  final bool isActive;

  BotModel({
    required this.botId,
    required this.name,
    required this.ownerId,
    required this.instructions,
    this.photoUrl = '',
    this.isActive = true,
  });

  factory BotModel.fromMap(Map<String, dynamic> map, String id) {
    return BotModel(
      botId: id,
      name: map['name'] ?? '',
      ownerId: map['ownerId'] ?? '',
      instructions: map['instructions'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerId': ownerId,
      'instructions': instructions,
      'photoUrl': photoUrl,
      'isActive': isActive,
    };
  }
}
