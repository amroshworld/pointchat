import 'dart:async';

// Mock service
class MockChatService {
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String senderPhotoUrl,
    required String text,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 50));
  }
}

Future<void> main() async {
  final service = MockChatService();
  final chatIds = List.generate(50, (i) => 'chat_$i');

  print('Starting benchmark for 50 chats...');

  // Baseline: Sequential
  final stopwatchSeq = Stopwatch()..start();
  for (final chatId in chatIds) {
    await service.sendMessage(
      chatId: chatId,
      senderId: 'me',
      senderName: 'Test',
      senderPhotoUrl: '',
      text: 'Hello',
    );
  }
  stopwatchSeq.stop();
  final seqTime = stopwatchSeq.elapsedMilliseconds;
  print('Sequential time: ${seqTime}ms');

  // Proposed: Future.wait
  final stopwatchPar = Stopwatch()..start();
  await Future.wait(
    chatIds.map((chatId) => service.sendMessage(
      chatId: chatId,
      senderId: 'me',
      senderName: 'Test',
      senderPhotoUrl: '',
      text: 'Hello',
    )),
  );
  stopwatchPar.stop();
  final parTime = stopwatchPar.elapsedMilliseconds;
  print('Future.wait time: ${parTime}ms');

  final improvement = seqTime - parTime;
  final percent = ((improvement / seqTime) * 100).toStringAsFixed(2);
  print('Improvement: ${improvement}ms ($percent% faster)');
}
