import 'package:flutter_test/flutter_test.dart';
import 'package:vantage_public_sector/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const VantagePublicSectorApp());
    await tester.pump();
  });
}
