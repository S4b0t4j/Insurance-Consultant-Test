enum UserRole { admin, viewer }

class AppUser {
  final String id;
  final String email;
  final String displayName;
  final String passwordHash;
  final UserRole role;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool active;

  /// Grants access to Report Studio + Risk Desk. Default deny; admins are
  /// implicitly granted via AuthProvider.
  final bool canUseReportStudio;

  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.passwordHash,
    required this.role,
    required this.createdAt,
    this.lastLoginAt,
    this.active = true,
    this.canUseReportStudio = false,
  });

  bool get isAdmin => role == UserRole.admin;

  AppUser copyWith({
    String? displayName,
    String? passwordHash,
    UserRole? role,
    DateTime? lastLoginAt,
    bool? active,
    bool? canUseReportStudio,
  }) {
    return AppUser(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      active: active ?? this.active,
      canUseReportStudio: canUseReportStudio ?? this.canUseReportStudio,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'passwordHash': passwordHash,
        'role': role.name,
        'createdAt': createdAt.toIso8601String(),
        'lastLoginAt': lastLoginAt?.toIso8601String(),
        'active': active,
        'canUseReportStudio': canUseReportStudio,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'],
        email: json['email'],
        displayName: json['displayName'],
        passwordHash: json['passwordHash'],
        role: UserRole.values.firstWhere((r) => r.name == json['role'],
            orElse: () => UserRole.viewer),
        createdAt: DateTime.parse(json['createdAt']),
        lastLoginAt: json['lastLoginAt'] != null
            ? DateTime.parse(json['lastLoginAt'])
            : null,
        active: json['active'] ?? true,
        canUseReportStudio: json['canUseReportStudio'] ?? false,
      );
}
