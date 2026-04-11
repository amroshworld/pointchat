import 'dart:async';
import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../appwrite_client.dart';

class ModerationService {
  ModerationService._internal();

  static final ModerationService instance = ModerationService._internal();

  static const String _blockedUsersKey = 'moderation.blocked_users';
  static const String _userReportsKey = 'moderation.user_reports';

  final Account _account = appwriteAccount;
  final Realtime _realtime = appwriteRealtime;

  final ValueNotifier<Set<String>> blockedUserIdsListenable =
      ValueNotifier<Set<String>>(<String>{});

  bool _initialized = false;
  RealtimeSubscription? _accountSubscription;
  Timer? _pollTimer;
  bool _pollRefreshInFlight = false;

  Future<void> initialize() async {
    if (_initialized) {
      await refresh();
      return;
    }

    await _loadBlockedUsers();
    _startRemoteSync();
    _initialized = true;
  }

  Future<void> refresh() async {
    await _loadBlockedUsers();
  }

  void _startRemoteSync() {
    if (_accountSubscription == null) {
      try {
        _accountSubscription = _realtime.subscribe(['account']);
        _accountSubscription!.stream.listen((_) {
          unawaited(refresh());
        });
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Moderation account realtime unavailable: $e');
        }
      }
    }

    _pollTimer ??= Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_pollRefresh());
    });
  }

  Future<void> _pollRefresh() async {
    if (_pollRefreshInFlight) {
      return;
    }
    _pollRefreshInFlight = true;
    try {
      await refresh();
    } finally {
      _pollRefreshInFlight = false;
    }
  }

  bool isBlocked(String userId) {
    final normalizedUserId = _normalizeUserId(userId);
    if (normalizedUserId.isEmpty) {
      return false;
    }
    return blockedUserIdsListenable.value.contains(normalizedUserId);
  }

  Future<void> blockUser(String userId) async {
    final normalizedUserId = _normalizeUserId(userId);
    if (normalizedUserId.isEmpty) {
      return;
    }

    final current = Set<String>.from(blockedUserIdsListenable.value);
    if (current.add(normalizedUserId)) {
      await _saveBlockedUsers(current);
    }
  }

  Future<void> unblockUser(String userId) async {
    final normalizedUserId = _normalizeUserId(userId);
    if (normalizedUserId.isEmpty) {
      return;
    }

    final current = Set<String>.from(blockedUserIdsListenable.value);
    if (current.remove(normalizedUserId)) {
      await _saveBlockedUsers(current);
    }
  }

  Future<void> submitUserReport({
    required String reporterUserId,
    required String targetUserId,
    required String reason,
    String details = '',
  }) async {
    final normalizedTargetUserId = _normalizeUserId(targetUserId);
    final normalizedReporterUserId = _normalizeUserId(reporterUserId);
    final trimmedReason = reason.trim();
    final trimmedDetails = details.trim();

    if (normalizedTargetUserId.isEmpty || trimmedReason.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_userReportsKey) ?? <String>[];
    final report = <String, dynamic>{
      'reportId':
          '${DateTime.now().millisecondsSinceEpoch}_$normalizedTargetUserId',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'reporterUserId': normalizedReporterUserId,
      'targetUserId': normalizedTargetUserId,
      'reason': trimmedReason,
      'details': trimmedDetails,
    };

    stored.insert(0, jsonEncode(report));
    await prefs.setStringList(
      _userReportsKey,
      stored.take(200).toList(growable: false),
    );

    final remotePrefs = await _getRemotePrefsSafe();
    if (remotePrefs == null) {
      return;
    }

    final remoteReports = _extractReportList(remotePrefs[_userReportsKey]);
    remoteReports.insert(0, report);
    remotePrefs[_userReportsKey] =
        remoteReports.take(200).toList(growable: false);
    await _updateRemotePrefsSafe(remotePrefs);
  }

  Future<List<Map<String, dynamic>>> getStoredReports() async {
    final remotePrefs = await _getRemotePrefsSafe();
    if (remotePrefs != null && remotePrefs.containsKey(_userReportsKey)) {
      final remoteReports = _extractReportList(remotePrefs[_userReportsKey]);

      final prefs = await SharedPreferences.getInstance();
      final serialized = remoteReports
          .map((report) => jsonEncode(report))
          .toList(growable: false);
      await prefs.setStringList(_userReportsKey, serialized);

      return remoteReports;
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_userReportsKey) ?? <String>[];
    return stored
        .map((item) {
          try {
            return Map<String, dynamic>.from(jsonDecode(item) as Map);
          } catch (_) {
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<void> _loadBlockedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final localBlocked = prefs.getStringList(_blockedUsersKey) ?? <String>[];
    final normalizedLocalBlocked = localBlocked
        .map(_normalizeUserId)
        .where((userId) => userId.isNotEmpty)
        .toList(growable: false);

    blockedUserIdsListenable.value = normalizedLocalBlocked.toSet();

    final remotePrefs = await _getRemotePrefsSafe();
    if (remotePrefs == null) {
      return;
    }

    if (remotePrefs.containsKey(_blockedUsersKey)) {
      final remoteBlocked = _extractStringList(remotePrefs[_blockedUsersKey]);
      await prefs.setStringList(_blockedUsersKey, remoteBlocked);
      blockedUserIdsListenable.value = remoteBlocked.toSet();
      return;
    }

    // First-time migration: push existing local blocked users to Appwrite prefs.
    if (normalizedLocalBlocked.isNotEmpty) {
      remotePrefs[_blockedUsersKey] = normalizedLocalBlocked;
      await _updateRemotePrefsSafe(remotePrefs);
    }
  }

  Future<void> _saveBlockedUsers(Set<String> users) async {
    final prefs = await SharedPreferences.getInstance();
    final orderedUsers = users.toList()..sort();
    await prefs.setStringList(_blockedUsersKey, orderedUsers);
    blockedUserIdsListenable.value = Set<String>.from(users);

    final remotePrefs = await _getRemotePrefsSafe();
    if (remotePrefs == null) {
      return;
    }
    remotePrefs[_blockedUsersKey] = orderedUsers;
    await _updateRemotePrefsSafe(remotePrefs);
  }

  Future<Map<String, dynamic>?> _getRemotePrefsSafe() async {
    try {
      final prefs = await _account.getPrefs();
      return Map<String, dynamic>.from(prefs.data);
    } on AppwriteException catch (e) {
      if (kDebugMode) {
        debugPrint('Moderation remote prefs unavailable: ${e.message}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Moderation remote prefs unavailable: $e');
      }
      return null;
    }
  }

  Future<void> _updateRemotePrefsSafe(Map<String, dynamic> prefs) async {
    try {
      await _account.updatePrefs(prefs: prefs);
    } on AppwriteException catch (e) {
      if (kDebugMode) {
        debugPrint('Moderation remote prefs update failed: ${e.message}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Moderation remote prefs update failed: $e');
      }
    }
  }

  List<String> _extractStringList(dynamic raw) {
    if (raw is! List) {
      return <String>[];
    }

    final values = raw
        .map((item) => _normalizeUserId(item.toString()))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return values;
  }

  List<Map<String, dynamic>> _extractReportList(dynamic raw) {
    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }

    return raw
        .map((item) {
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
          return null;
        })
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  String _normalizeUserId(String userId) => userId.trim();
}
