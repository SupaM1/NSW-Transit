import 'package:flutter_test/flutter_test.dart';

import 'package:nsw_transit/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const NswTransitApp());
    await tester.pump();
    expect(find.byType(NswTransitApp), findsOneWidget);
  });
}
