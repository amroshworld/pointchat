import '../models/group_model.dart';

/// Parsed `#group` or `#group~idprefix` from the composer (without the leading `#`).
class ParsedGroupHandle {
  final String nameToken;
  final String? idSuffix;

  const ParsedGroupHandle({required this.nameToken, this.idSuffix});
}

/// Resolves group hashtags when multiple groups share the same normalized name.
class GroupHandleResolver {
  GroupHandleResolver._();

  static String normalizeNameToken(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  static ParsedGroupHandle parseAfterHash(String raw) {
    final s = raw.trim().toLowerCase();
    final tilde = s.indexOf('~');
    if (tilde >= 0) {
      final namePart = s.substring(0, tilde);
      final idPart = s.substring(tilde + 1).replaceAll(RegExp(r'\s+'), '');
      return ParsedGroupHandle(
        nameToken: normalizeNameToken(namePart),
        idSuffix: idPart.isEmpty ? null : idPart,
      );
    }
    return ParsedGroupHandle(nameToken: normalizeNameToken(s), idSuffix: null);
  }

  static List<GroupModel> matchingByName(
    Iterable<GroupModel> groups,
    String nameToken,
  ) {
    final list =
        groups.where((g) => normalizeNameToken(g.name) == nameToken).toList();
    list.sort((a, b) {
      final ta = a.lastMessageTime;
      final tb = b.lastMessageTime;
      if (ta == null && tb == null) {
        return a.groupId.compareTo(b.groupId);
      }
      if (ta == null) {
        return 1;
      }
      if (tb == null) {
        return -1;
      }
      return tb.compareTo(ta);
    });
    return list;
  }

  /// Picks a single group when [suffix] matches a substring of [groupId].
  static GroupModel? pickByIdSuffix(List<GroupModel> matches, String suffix) {
    if (matches.isEmpty) {
      return null;
    }
    if (suffix.isEmpty) {
      return matches.length == 1 ? matches.first : null;
    }
    final s = suffix.toLowerCase();
    if (matches.length == 1) {
      final gid = matches.first.groupId.toLowerCase();
      if (gid.startsWith(s) || gid.contains(s)) {
        return matches.first;
      }
      return null;
    }
    final byPrefix =
        matches.where((g) => g.groupId.toLowerCase().startsWith(s)).toList();
    if (byPrefix.length == 1) {
      return byPrefix.first;
    }
    final byContains =
        matches.where((g) => g.groupId.toLowerCase().contains(s)).toList();
    if (byContains.length == 1) {
      return byContains.first;
    }
    return null;
  }

  /// Composer token: `#name` or `#name~idprefix` when the name is not unique.
  static String composerHandleForGroup(
    GroupModel group,
    Iterable<GroupModel> allGroups,
  ) {
    final base = '#${normalizeNameToken(group.name)}';
    final dupCount = allGroups
        .where(
          (g) => normalizeNameToken(g.name) == normalizeNameToken(group.name),
        )
        .length;
    if (dupCount <= 1) {
      return base;
    }
    final id = group.groupId;
    final frag = id.length <= 8 ? id : id.substring(0, 8);
    return '$base~${frag.toLowerCase()}';
  }
}
