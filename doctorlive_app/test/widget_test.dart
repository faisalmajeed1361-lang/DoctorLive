import 'package:flutter_test/flutter_test.dart';

import 'package:doctorlive_app/main.dart';

void main() {
  testWidgets('DoctorLive welcome screen loads successfully', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DoctorLiveApp());

    await tester.pumpAndSettle();

    // Main DoctorLive branding should be visible.
    expect(find.textContaining('DoctorLive'), findsWidgets);

    // Welcome screen headline should be visible.
    expect(find.textContaining('Your Doctor.'), findsOneWidget);

    // Slider action should be available.
    expect(find.text('Slide to Get Started'), findsOneWidget);

    // Developer credit should be visible.
    expect(find.text('Developed by Faisal Majeed'), findsOneWidget);
  });
}
