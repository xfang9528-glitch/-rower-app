import 'dart:convert';

import '../models/user_profile.dart';
import 'local_paths.dart';

/// 本地多用户:users.json = { currentUserId, users:[...] }。
/// 无账号系统,首次自动播种一个"房总"。
class UserStore {
  static const _seedId = 'user_local_1';

  List<UserProfile> _users = const [];
  String _currentId = _seedId;
  bool _loaded = false;

  List<UserProfile> get users => List.unmodifiable(_users);
  String get currentId => _currentId;
  UserProfile get current =>
      _users.firstWhere((u) => u.id == _currentId, orElse: () => _users.first);

  Future<void> load() async {
    if (_loaded) return;
    try {
      final f = await LocalPaths.file('users.json');
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        _users = ((j['users'] as List?) ?? const [])
            .map((e) => UserProfile.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        _currentId = j['currentUserId'] as String? ?? '';
      }
    } catch (_) {
      _users = const [];
    }
    if (_users.isEmpty) {
      _users = const [
        UserProfile(id: _seedId, name: '房总'),
      ];
      _currentId = _seedId;
      await _persist();
    }
    if (!_users.any((u) => u.id == _currentId)) _currentId = _users.first.id;
    _loaded = true;
  }

  Future<void> switchTo(String userId) async {
    if (!_users.any((u) => u.id == userId)) return;
    _currentId = userId;
    await _persist();
  }

  Future<UserProfile> addUser(String name) async {
    // 给新用户排一个与原型一致的渐变配色。
    const palette = [
      (0xFF3D7BFF, 0xFF2F6BFF),
      (0xFF22C55E, 0xFF16A34A),
      (0xFFF59E0B, 0xFFF97316),
      (0xFFF43F5E, 0xFFEF4444),
    ];
    final c = palette[_users.length % palette.length];
    final u = UserProfile(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? '用户${_users.length + 1}' : name.trim(),
      avatarColorA: c.$1,
      avatarColorB: c.$2,
    );
    _users = [..._users, u];
    await _persist();
    return u;
  }

  Future<void> updateCurrent({String? name, double? weightKg}) async {
    _users = _users
        .map((u) => u.id == _currentId
            ? u.copyWith(name: name, weightKg: weightKg)
            : u)
        .toList();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final f = await LocalPaths.file('users.json');
      await f.writeAsString(jsonEncode({
        'currentUserId': _currentId,
        'users': _users.map((u) => u.toJson()).toList(),
      }));
    } catch (_) {}
  }
}
