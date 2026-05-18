/// 本地多用户(原型 ⑦):无账号系统,同机切换,每人独立记录。
class UserProfile {
  final String id;
  final String name;

  /// 体重(kg),为后续提高卡路里估算锚点预留;可空。
  final double? weightKg;

  /// 头像渐变两端色(存 ARGB int,UI 还原原型的彩色圆形头像)。
  final int avatarColorA;
  final int avatarColorB;

  const UserProfile({
    required this.id,
    required this.name,
    this.weightKg,
    this.avatarColorA = 0xFF3D7BFF,
    this.avatarColorB = 0xFF2F6BFF,
  });

  /// 头像首字(取名字首字符,与原型一致:房/嫂/儿)。
  String get initial => name.isEmpty ? '?' : name.substring(0, 1);

  UserProfile copyWith({String? name, double? weightKg}) => UserProfile(
        id: id,
        name: name ?? this.name,
        weightKg: weightKg ?? this.weightKg,
        avatarColorA: avatarColorA,
        avatarColorB: avatarColorB,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'weightKg': weightKg,
        'avatarColorA': avatarColorA,
        'avatarColorB': avatarColorB,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        weightKg: (j['weightKg'] as num?)?.toDouble(),
        avatarColorA: j['avatarColorA'] as int? ?? 0xFF3D7BFF,
        avatarColorB: j['avatarColorB'] as int? ?? 0xFF2F6BFF,
      );
}
