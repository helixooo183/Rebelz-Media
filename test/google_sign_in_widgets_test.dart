import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sohbet/core/theme/app_theme.dart';
import 'package:sohbet/core/widgets/google_logo.dart';
import 'package:sohbet/core/widgets/google_sign_in_button.dart';
import 'package:sohbet/core/widgets/or_divider.dart';

void main() {
  testWidgets('Google butonu etiketi gösterir ve dokunuşu iletir',
      (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: GoogleSignInButton(onPressed: () => taps++),
          ),
        ),
      ),
    );

    expect(find.text('Google ile devam et'), findsOneWidget);
    expect(find.byType(GoogleLogo), findsOneWidget);

    await tester.tap(find.byType(GoogleSignInButton));
    expect(taps, 1);
  });

  testWidgets('Yükleme sırasında buton tıklanamaz', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: GoogleSignInButton(
              onPressed: () => taps++,
              isLoading: true,
            ),
          ),
        ),
      ),
    );

    // Yükleme sırasında etiket yerine spinner gösterilir.
    expect(find.text('Google ile devam et'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(GoogleSignInButton));
    expect(taps, 0);
  });

  testWidgets('OrDivider "veya" yazar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: OrDivider())),
      ),
    );

    expect(find.text('veya'), findsOneWidget);
  });
}
