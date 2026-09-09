import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the demo list renders every section', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('AI Barcode Scanner'), findsOneWidget);
    expect(find.text('showAiBarcodeScanner'), findsOneWidget);

    // The rest of the list is below the fold on a small test viewport.
    await tester.scrollUntilVisible(
      find.text('Embedded scanner'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Embedded scanner'), findsOneWidget);
    expect(find.text('Batch collection'), findsOneWidget);
  });

  testWidgets('the platform support sheet lists capabilities', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    expect(find.text('Camera scanning'), findsOneWidget);
    expect(find.text('Scan from gallery'), findsOneWidget);
  });
}
