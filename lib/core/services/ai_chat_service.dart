import 'package:cloud_firestore/cloud_firestore.dart';

/// Persists the user's AI Advisor conversation in `users/{uid}/ai_chats/latest`
/// so chat context survives navigation and app restarts.
class AiChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const int maxStoredMessages = 30;

  DocumentReference<Map<String, dynamic>> _doc(String userId) =>
      _db.collection('users').doc(userId).collection('ai_chats').doc('latest');

  Future<List<Map<String, dynamic>>> loadMessages(String userId) async {
    try {
      final snap = await _doc(userId).get();
      if (!snap.exists) return [];
      final raw = snap.data()?['messages'];
      if (raw is! List) return [];
      return raw.whereType<Map>().map((item) {
        final ts = item['timestamp'];
        DateTime time;
        if (ts is Timestamp) {
          time = ts.toDate();
        } else if (ts is String) {
          time = DateTime.tryParse(ts) ?? DateTime.now();
        } else {
          time = DateTime.now();
        }
        return <String, dynamic>{
          'text': (item['text'] ?? '').toString(),
          'isUser': item['isUser'] == true,
          'timestamp': time,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMessages(
    String userId,
    List<Map<String, dynamic>> messages,
  ) async {
    try {
      final capped = messages.length > maxStoredMessages
          ? messages.sublist(messages.length - maxStoredMessages)
          : messages;

      final payload = capped
          .map(
            (m) => <String, dynamic>{
              'text': (m['text'] ?? '').toString(),
              'isUser': m['isUser'] == true,
              'timestamp': Timestamp.fromDate(
                m['timestamp'] is DateTime
                    ? m['timestamp'] as DateTime
                    : DateTime.now(),
              ),
            },
          )
          .toList();

      await _doc(userId).set({
        'messages': payload,
        'updatedAt': Timestamp.now(),
      });
    } catch (_) {
      // Non-blocking: chat works even if persistence fails offline.
    }
  }

  Future<void> clearMessages(String userId) async {
    try {
      await _doc(userId).delete();
    } catch (_) {
      // Non-blocking.
    }
  }
}
