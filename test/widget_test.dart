import 'package:flutter_test/flutter_test.dart';
import 'package:education_news_monitor/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const EducationNewsMonitorApp());
    await tester.pump();
  });
}
