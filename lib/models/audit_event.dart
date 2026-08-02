enum AuditAction {
  login,
  loginFailed,
  logout,
  userAdded,
  userRemoved,
  accessGrantChanged,
  templateUploaded,
  sourceAdded,
  generationStarted,
  generationCompleted,
  generationFailed,
  reportDownloaded,
  riskAnalysisStarted,
  riskAnalysisCompleted,
  riskAnalysisFailed,
  radarScanCompleted,
  radarRiskDetected,
}

extension AuditActionLabel on AuditAction {
  String get label {
    switch (this) {
      case AuditAction.login:
        return 'Login';
      case AuditAction.loginFailed:
        return 'Login failed';
      case AuditAction.logout:
        return 'Logout';
      case AuditAction.userAdded:
        return 'User added';
      case AuditAction.userRemoved:
        return 'User removed';
      case AuditAction.accessGrantChanged:
        return 'Access grant changed';
      case AuditAction.templateUploaded:
        return 'Template uploaded';
      case AuditAction.sourceAdded:
        return 'Source added';
      case AuditAction.generationStarted:
        return 'Generation started';
      case AuditAction.generationCompleted:
        return 'Generation completed';
      case AuditAction.generationFailed:
        return 'Generation failed';
      case AuditAction.reportDownloaded:
        return 'Report downloaded';
      case AuditAction.riskAnalysisStarted:
        return 'Risk analysis started';
      case AuditAction.riskAnalysisCompleted:
        return 'Risk analysis completed';
      case AuditAction.riskAnalysisFailed:
        return 'Risk analysis failed';
      case AuditAction.radarScanCompleted:
        return 'Radar scan completed';
      case AuditAction.radarRiskDetected:
        return 'Radar risk detected';
    }
  }
}

class AuditEvent {
  final String id;
  final DateTime timestamp;
  final String userId;
  final String userEmail;
  final AuditAction action;
  final String detail;

  const AuditEvent({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.userEmail,
    required this.action,
    this.detail = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'ts': timestamp.toIso8601String(),
        'userId': userId,
        'userEmail': userEmail,
        'action': action.name,
        'detail': detail,
      };

  factory AuditEvent.fromJson(Map<String, dynamic> json) => AuditEvent(
        id: json['id'] ?? '',
        timestamp:
            DateTime.tryParse(json['ts'] ?? '') ?? DateTime.now(),
        userId: json['userId'] ?? '',
        userEmail: json['userEmail'] ?? '',
        action: AuditAction.values.firstWhere(
          (a) => a.name == json['action'],
          orElse: () => AuditAction.login,
        ),
        detail: json['detail'] ?? '',
      );
}
