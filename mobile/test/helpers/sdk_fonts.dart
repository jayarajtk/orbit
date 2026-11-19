import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the fonts that ship with the Flutter SDK, so text and icons render
/// as glyphs instead of the test font's solid blocks.
Future<void> loadSdkFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null || root.isEmpty) {
    throw StateError('FLUTTER_ROOT is not set; run via `flutter test`.');
  }
  final fonts = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!fonts.existsSync()) {
    throw StateError(
      'No SDK fonts at ${fonts.path}; run `flutter precache` and retry.',
    );
  }
  Future<void> load(String family, List<String> names) async {
    final loader = FontLoader(family);
    for (final name in names) {
      final bytes = File('${fonts.path}/$name').readAsBytes();
      loader.addFont(bytes.then(ByteData.sublistView));
    }
    await loader.load();
  }

  await load('Roboto', [
    for (final weight in [
      'Thin',
      'Light',
      'Regular',
      'Medium',
      'Bold',
      'Black',
    ])
      'Roboto-$weight.ttf',
  ]);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}
