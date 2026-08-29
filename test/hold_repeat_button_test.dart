import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_tv_remote/widgets/hold_repeat_button.dart';

void main() {
  testWidgets('taps once and repeats until the press is released', (
    WidgetTester tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 80,
              child: Material(
                child: HoldRepeatButton(
                  semanticsLabel: 'Test control',
                  initialRepeatDelay: const Duration(milliseconds: 200),
                  repeatInterval: const Duration(milliseconds: 100),
                  onPressed: () async => presses++,
                  child: const Icon(Icons.add),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldRepeatButton)),
    );
    await tester.pump();
    expect(presses, 1);

    await tester.pump(const Duration(milliseconds: 190));
    expect(presses, 1);

    await tester.pump(const Duration(milliseconds: 220));
    expect(presses, greaterThanOrEqualTo(3));

    await gesture.up();
    await tester.pump();
    final releasedCount = presses;
    await tester.pump(const Duration(milliseconds: 300));
    expect(presses, releasedCount);
  });

  testWidgets('does not overlap slow asynchronous commands', (
    WidgetTester tester,
  ) async {
    var presses = 0;
    var activeCommands = 0;
    var maximumActiveCommands = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: HoldRepeatButton(
            semanticsLabel: 'Test control',
            initialRepeatDelay: const Duration(milliseconds: 50),
            repeatInterval: const Duration(milliseconds: 20),
            onPressed: () async {
              presses++;
              activeCommands++;
              maximumActiveCommands = activeCommands > maximumActiveCommands
                  ? activeCommands
                  : maximumActiveCommands;
              await Future<void>.delayed(const Duration(milliseconds: 75));
              activeCommands--;
            },
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldRepeatButton)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));

    expect(presses, greaterThan(1));
    expect(maximumActiveCommands, 1);
  });
}
