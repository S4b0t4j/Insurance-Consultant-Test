import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vantage_public_sector/providers/auth_provider.dart';

/// AuthProvider.skipLoginForNow auto-signs sessions in as the seeded admin
/// so the app is reachable without a credential prompt. This only matters
/// while the flag stays on the codebase's default (true) — pin that so a
/// silent flip back to false doesn't leave the app unexpectedly locked
/// behind sign-in for whoever set it up expecting the bypass.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('skipLoginForNow is on', () {
    expect(AuthProvider.skipLoginForNow, isTrue,
        reason: 'If this was flipped off deliberately, delete this test '
            'along with the flag rather than editing the expectation.');
  });

  test('a fresh session lands logged in as an admin, no credentials entered',
      () async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthProvider();

    // _bootstrap() is async and unawaited from the constructor; poll until
    // it settles rather than assuming a fixed number of microtasks.
    for (var i = 0; i < 50 && !auth.initialized; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(auth.initialized, isTrue);
    expect(auth.isLoggedIn, isTrue,
        reason: 'skipLoginForNow should auto-select the seeded admin');
    expect(auth.isAdmin, isTrue);
    expect(auth.currentUser?.email, 'admin@vantage.local');
  });

  test('an explicit prior session is respected, not overridden', () async {
    SharedPreferences.setMockInitialValues({
      'app_users_v1': '''[
        {"id":"u_1","email":"someone@vantage.local","displayName":"Someone",
         "passwordHash":"x","role":"viewer","createdAt":"2026-01-01T00:00:00.000Z",
         "active":true,"canUseReportStudio":false},
        {"id":"admin-seed","email":"admin@vantage.local","displayName":"VANTAGE Admin",
         "passwordHash":"x","role":"admin","createdAt":"2026-01-01T00:00:00.000Z",
         "active":true,"canUseReportStudio":false}
      ]''',
      'app_session_v1': 'u_1',
    });
    final auth = AuthProvider();
    for (var i = 0; i < 50 && !auth.initialized; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(auth.currentUser?.id, 'u_1',
        reason: 'a real prior session must win over the bypass, or logging '
            'in as a specific user would never stick');
    expect(auth.isAdmin, isFalse);
  });
}
