import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/tolerant_golden_comparator.dart';

/// Lets goldens in this folder differ by up to 0.5% of pixels; see
/// [TolerantGoldenComparator].
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final local = goldenFileComparator;
  if (local is LocalFileComparator) {
    goldenFileComparator = TolerantGoldenComparator(
      Uri.parse('${local.basedir}main_screens_golden_test.dart'),
      tolerance: 0.005,
    );
  }
  await testMain();
}
