import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_tv_remote/widgets/vizio_pin_dialog.dart';

void main() {
  testWidgets('submits the Vizio PIN without TextInput disposal errors', (
    WidgetTester tester,
  ) async {
    String? submittedPin;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                submittedPin = await showVizioPinDialog(context);
              },
              child: const Text('Open pairing'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open pairing'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '12a34');
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'Pair'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Pair'));
    await tester.pumpAndSettle();

    expect(submittedPin, '1234');
    expect(find.text('Enter Vizio PIN'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('submits the Vizio PIN from the keyboard action', (
    WidgetTester tester,
  ) async {
    String? submittedPin;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                submittedPin = await showVizioPinDialog(context);
              },
              child: const Text('Open pairing'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open pairing'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '5678');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(submittedPin, '5678');
    expect(tester.takeException(), isNull);
  });
}
