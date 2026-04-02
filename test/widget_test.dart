import 'package:flutter_test/flutter_test.dart';

import 'package:readflow/main.dart';

void main() {
  testWidgets('ReadFlow app bootstraps', (WidgetTester tester) async {
    await tester.pumpWidget(const ReadFlowApp());

    expect(find.text('ReadFlow'), findsOneWidget);
    expect(find.text('Read anything. Listen anywhere.'), findsOneWidget);
  });
}
