import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:d22/main.dart';
import 'package:d22/grid_state.dart';

void main() {
  testWidgets('Smoke test for Puzzle Decryptor Prototype', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GridState(),
        child: const MyApp(),
      ),
    );

    // Verify that the navigation tabs are rendered.
    expect(find.text('Phase 1: Map'), findsOneWidget);
  });
}
