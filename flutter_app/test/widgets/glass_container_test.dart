import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jcg_fitness/app/app_colors.dart';
import 'package:jcg_fitness/core/widgets/glass_container.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          extensions: const [AppSemanticColors.dark],
        ),
        home: Scaffold(body: child),
      );

  testWidgets('scroll-safe glass card never creates a live blur',
      (tester) async {
    await tester.pumpWidget(host(const GlassCard(child: Text('Meal'))));

    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(RepaintBoundary), findsWidgets);
    expect(find.text('Meal'), findsOneWidget);
  });

  testWidgets('stationary chrome uses the bounded live blur path',
      (tester) async {
    await tester.pumpWidget(
      host(
        const GlassContainer(
          level: GlassSurfaceLevel.chrome,
          liveBlur: true,
          child: Text('Navigation'),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('Navigation'), findsOneWidget);
  });
}
