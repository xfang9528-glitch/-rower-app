import 'package:flutter_test/flutter_test.dart';

import 'package:rower_app/main.dart';

void main() {
  testWidgets('App boots to scan screen', (WidgetTester tester) async {
    await tester.pumpWidget(const RowerApp());
    expect(find.text('小莫划船机 · 蓝牙探测'), findsOneWidget);
  });
}
