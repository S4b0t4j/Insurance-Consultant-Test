import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vantage_public_sector/main.dart';
import 'package:vantage_public_sector/widgets/app_sidebar.dart';

/// Below _mobileBreakpoint (home_screen.dart) the sidebar moves into a
/// Drawer, opened via a menu button, instead of sitting inline in the body
/// Row — otherwise it eats a fixed 72-240px on a ~390px phone viewport,
/// breaking the dashboard. Pins that the branch actually swaps layouts
/// rather than always doing one.
void main() {
  // Skips the first-run onboarding dialog (barrierDismissible: false), which
  // would otherwise swallow the tap on the menu button meant for the app
  // underneath. Keyed to the seeded admin id since skipLoginForNow bypasses
  // sign-in straight to that user (see auth_provider.dart).
  const mockPrefs = {'app_onboarded_admin-seed': true};

  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('narrow viewport: sidebar opens in a Drawer via a menu button',
      (tester) async {
    // AuthProvider._bootstrap() calls SharedPreferences.getInstance(); the
    // plugin channel throws without a registered mock, which silently stalls
    // bootstrap on the loading spinner forever (see auth_bypass_test.dart).
    SharedPreferences.setMockInitialValues(mockPrefs);
    // setSurfaceSize takes physical pixels; the default test device pixel
    // ratio isn't 1.0, so pin it or 390 physical px becomes way fewer than
    // 390 logical px and MediaQuery lies about the viewport under test.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    // Not pumpAndSettle: the app has periodic timers (auto-refresh, radar
    // scan) that never quiesce, same reason widget_test.dart avoids it too.
    await tester.pumpWidget(const VantagePublicSectorApp());
    await pumpUntilFound(tester, find.byIcon(Icons.menu));
    expect(find.byType(AppSidebar), findsNothing,
        reason: 'closed Drawer content is not built at all until opened');

    await tester.tap(find.byIcon(Icons.menu));
    await pumpUntilFound(tester, find.byType(AppSidebar));

    final sidebarFinder = find.byType(AppSidebar);
    expect(sidebarFinder, findsOneWidget);
    expect(
      find.ancestor(of: sidebarFinder, matching: find.byType(Drawer)),
      findsOneWidget,
      reason: 'the sidebar must be inside the Drawer, not the body Row',
    );
  });

  testWidgets('wide viewport: sidebar sits inline, no menu button',
      (tester) async {
    SharedPreferences.setMockInitialValues(mockPrefs);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const VantagePublicSectorApp());
    await pumpUntilFound(tester, find.byType(AppSidebar));

    expect(find.byType(AppSidebar), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsNothing);
  });
}
