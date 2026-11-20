import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Compares goldens like [LocalFileComparator], but passes when at most
/// [tolerance] of the pixels differ (0.005 is 0.5%).
///
/// Two Macs anti-alias text slightly differently: the CI runner differs
/// from the machine that made the goldens by up to 0.06%. A changed label
/// or layout differs by far more, so it still fails.
class TolerantGoldenComparator extends LocalFileComparator {
  /// Resolves goldens next to [testFile].
  TolerantGoldenComparator(super.testFile, {required this.tolerance});

  /// Largest share of differing pixels, from 0 to 1, that still passes.
  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    try {
      if (result.passed || result.diffPercent <= tolerance) return true;
      throw FlutterError(
        await generateFailureOutput(result, golden, basedir),
      );
    } finally {
      result.dispose();
    }
  }
}
