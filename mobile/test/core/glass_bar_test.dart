import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/app/theme.dart';
import 'package:orbit/core/widgets/glass_bar.dart';

Future<void> _pumpBar(WidgetTester tester, TargetPlatform platform) async {
  tester.view
    ..physicalSize = const Size(1179, 2556)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildOrbitTheme(Brightness.light).copyWith(platform: platform),
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            const LargeTitleSliverAppBar(title: 'Inbox'),
            SliverList(
              delegate: SliverChildListDelegate([
                for (var i = 0; i < 40; i++)
                  SizedBox(height: 60, child: Text('Row $i')),
              ]),
            ),
          ],
        ),
      ),
    ),
  );
}

FontWeight? _titleWeight(WidgetTester tester) =>
    tester.widget<Text>(find.text('Inbox')).style?.fontWeight;

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('the large title is bold and leading on ${platform.name}', (
      tester,
    ) async {
      await _pumpBar(tester, platform);

      expect(tester.getTopLeft(find.text('Inbox')).dx, closeTo(16, 1));
      expect(_titleWeight(tester), FontWeight.w700);
    });
  }

  testWidgets('the collapsed title is semibold', (tester) async {
    await _pumpBar(tester, TargetPlatform.iOS);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(_titleWeight(tester), FontWeight.w600);
  });
}
