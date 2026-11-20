import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/tolerant_golden_comparator.dart';

/// A 100 x 100 white PNG with the first [black] pixels black: each one is
/// 0.01% of the image.
Future<Uint8List> png(int black) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      const Rect.fromLTWH(0, 0, 100, 100),
      Paint()..color = const Color(0xFFFFFFFF),
    );
  final ink = Paint()..color = const Color(0xFF000000);
  for (var i = 0; i < black; i++) {
    canvas.drawRect(
      Rect.fromLTWH((i % 100).toDouble(), (i ~/ 100).toDouble(), 1, 1),
      ink,
    );
  }
  final image = await recorder.endRecording().toImage(100, 100);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  late Directory dir;
  late TolerantGoldenComparator comparator;
  final golden = Uri.parse('screen.png');

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('golden');
    comparator = TolerantGoldenComparator(
      Uri.file('${dir.path}/screen_test.dart'),
      tolerance: 0.005,
    );
  });
  tearDown(() => dir.delete(recursive: true));

  testWidgets('passes when fewer pixels differ than the tolerance', (
    tester,
  ) async {
    await tester.runAsync(() async {
      File('${dir.path}/screen.png').writeAsBytesSync(await png(0));
      expect(await comparator.compare(await png(40), golden), isTrue);
    });
  });

  testWidgets('fails when more pixels differ than the tolerance', (
    tester,
  ) async {
    await tester.runAsync(() async {
      File('${dir.path}/screen.png').writeAsBytesSync(await png(0));
      await expectLater(
        comparator.compare(await png(60), golden),
        throwsA(
          isA<FlutterError>().having(
            (e) => e.message,
            'message',
            contains('0.60%'),
          ),
        ),
      );
    });
  });
}
