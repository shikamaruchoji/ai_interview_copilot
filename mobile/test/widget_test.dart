import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_interview_copilot/main.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const CopilotApp());
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Unlock'), findsOneWidget);
  });
}
