import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/media/data/photo_metadata.dart';

import '../helpers/photo_bytes.dart';

String _latin1(Uint8List bytes) => latin1.decode(bytes);

/// Orientation in the output's EXIF, or null when it has none.
int? _orientation(Uint8List jpeg) {
  final text = _latin1(jpeg);
  final exif = text.indexOf('Exif\u0000\u0000');
  if (exif < 0) return null;
  final tiff = exif + 6;
  final data = ByteData.sublistView(jpeg);
  final endian = text.startsWith('II', tiff) ? Endian.little : Endian.big;
  final ifd = tiff + data.getUint32(tiff + 4, endian);
  final count = data.getUint16(ifd, endian);
  for (var i = 0; i < count; i++) {
    final entry = ifd + 2 + 12 * i;
    if (data.getUint16(entry, endian) == 0x0112) {
      return data.getUint16(entry + 8, endian);
    }
  }
  return null;
}

void main() {
  group('JPEG', () {
    test('drops location and every other kind of metadata', () {
      final text = _latin1(stripPhotoMetadata(pickerJpeg()));

      expect(text, isNot(contains('GPS')));
      expect(text, isNot(contains('Exif')));
      expect(text, isNot(contains('http://ns.adobe.com')));
      expect(text, isNot(contains('Photoshop')));
      expect(text, isNot(contains('MPF')));
      expect(text, isNot(contains('taken at home')));
    });

    test('keeps what decoding needs, byte for byte', () {
      final stripped = stripPhotoMetadata(pickerJpeg());

      expect(stripped.sublist(0, 2), [0xFF, 0xD8]);
      expect(_latin1(stripped), contains('JFIF'));
      expect(_latin1(stripped), contains('ICC_PROFILE'));
      expect(
        _latin1(stripped),
        contains(_latin1(Uint8List.fromList(imageCore))),
      );
    });

    test('ends at the first image, dropping appended gain maps', () {
      final stripped = stripPhotoMetadata(pickerJpeg());

      expect(stripped.sublist(stripped.length - 2), [0xFF, 0xD9]);
      expect(
        _latin1(stripped).indexOf('ÿÙ'),
        stripped.length - 2,
        reason: 'only one end-of-image marker',
      );
    });

    test('a photo without metadata is unchanged', () {
      expect(stripPhotoMetadata(plainJpeg()), plainJpeg());
    });

    test('keeps a rotation as the only EXIF tag', () {
      for (final littleEndian in [false, true]) {
        for (var orientation = 2; orientation <= 8; orientation++) {
          final stripped = stripPhotoMetadata(
            pickerJpeg(orientation: orientation, littleEndian: littleEndian),
          );

          expect(_orientation(stripped), orientation);
          expect(_latin1(stripped), isNot(contains('GPS')));
        }
      }
    });

    test('an upright photo carries no EXIF at all', () {
      expect(_orientation(stripPhotoMetadata(pickerJpeg())), isNull);
    });

    test('refuses a truncated file rather than upload it as is', () {
      final cut = pickerJpeg().sublist(0, 40);

      expect(() => stripPhotoMetadata(cut), throwsFormatException);
    });
  });

  group('PNG', () {
    test('drops EXIF, text and time chunks and trailing bytes', () {
      final text = _latin1(stripPhotoMetadata(metadataPng()));

      for (final type in ['eXIf', 'tEXt', 'iTXt', 'zTXt', 'tIME']) {
        expect(text, isNot(contains(type)));
      }
      expect(text, isNot(contains('London')));
      expect(text, isNot(contains('trailing')));
    });

    test('keeps the image chunks', () {
      final text = _latin1(stripPhotoMetadata(metadataPng()));

      expect(text, startsWith('\u0089PNG'));
      for (final type in ['IHDR', 'iCCP', 'IDAT', 'IEND']) {
        expect(text, contains(type));
      }
    });
  });

  test('refuses anything that is not a JPEG or PNG', () {
    expect(
      () => stripPhotoMetadata(Uint8List.fromList(utf8.encode('GIF89a'))),
      throwsFormatException,
    );
  });
}
