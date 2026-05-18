import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('App shows login flow when logged out', (WidgetTester tester) async {
    await tester.pumpWidget(const NEETPrepApp(loggedIn: false));

    expect(find.text('NEET Prep'), findsOneWidget);
    expect(find.text('Login to continue'), findsOneWidget);
  });
}
