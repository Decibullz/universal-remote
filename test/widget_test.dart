import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_tv_remote/app.dart';

void main() {
  testWidgets('shows the empty remote state', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const UniversalTvRemoteApp());
    await tester.pumpAndSettle();

    expect(find.text('Tv Remote'), findsOneWidget);
    expect(find.text('No TVs yet'), findsOneWidget);
    expect(find.text('Add TV'), findsOneWidget);
  });
}
