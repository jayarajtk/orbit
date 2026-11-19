import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:orbit/features/media/data/media_capture.dart';
import 'package:orbit/features/media/data/media_repository.dart';
import 'package:orbit/features/media/data/photo_metadata.dart';
import 'package:orbit/features/media/domain/media.dart';

import '../helpers/fake_api.dart';
import '../helpers/photo_bytes.dart';

/// The library as `image_picker` sees it: three photos that still carry GPS.
class _GalleryWithGps extends Fake implements ImagePicker {
  int? limit;
  double? maxWidth;
  double? maxHeight;
  int? imageQuality;
  bool? requestFullMetadata;

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    this.limit = limit;
    this.maxWidth = maxWidth;
    this.maxHeight = maxHeight;
    this.imageQuality = imageQuality;
    this.requestFullMetadata = requestFullMetadata;
    return [
      for (var i = 0; i < 3; i++)
        XFile.fromData(
          Uint8List.fromList(pickerJpeg(orientation: 6)),
          name: 'photo-$i.jpg',
        ),
    ];
  }
}

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

  group('pickPhotos', () {
    test(
      'asks for the same size and quality as pickPhoto, up to ten',
      () async {
        final gallery = _GalleryWithGps();

        final photos = await ImagePickerMediaPicker(
          picker: gallery,
        ).pickPhotos();

        expect(photos, hasLength(3));
        expect(photos.map((p) => p.contentType), everyElement('image/jpeg'));
        expect(gallery.limit, 10);
        expect(gallery.maxWidth, ImagePickerMediaPicker.maxPhotoSide);
        expect(gallery.maxHeight, ImagePickerMediaPicker.maxPhotoSide);
        expect(gallery.imageQuality, 85);
        expect(gallery.requestFullMetadata, isFalse);
      },
    );

    test('strips location metadata from every photo', () async {
      final api = FakeAdapter({
        'POST /media/uploads': (
          201,
          {
            'id': 'm1',
            'uploadUrl': 'https://storage.test/m/m1/original?X-Amz-Signature=x',
            'headers': {'Content-Type': 'image/jpeg'},
            'expiresAt': '2026-11-18T12:05:00Z',
          },
        ),
        'POST /media/uploads/m1/complete': (
          200,
          {
            'id': 'm1',
            'kind': 'PHOTO',
            'privateOnly': false,
            'links': {
              'kind': 'PHOTO',
              'url': 'https://storage.test/full',
              'width': 10,
              'height': 10,
              'expiresAt': '2026-11-18T12:10:00Z',
            },
          },
        ),
      });
      final storage = FakeAdapter({
        'PUT https://storage.test/m/m1/original?X-Amz-Signature=x': (200, null),
      });
      final repository = ApiMediaRepository(
        dioWith(api)..options.headers['Authorization'] = 'Bearer t',
        Dio()..httpClientAdapter = storage,
      );

      final photos = await ImagePickerMediaPicker(
        picker: _GalleryWithGps(),
      ).pickPhotos();
      for (final photo in photos) {
        await repository.upload(
          MediaPurpose.chatPhoto,
          photo.bytes,
          photo.contentType,
        );
      }

      expect(storage.streamedBodies, hasLength(3));
      for (final sent in storage.streamedBodies) {
        expect(_latin1(sent), isNot(contains('GPS')));
        expect(_orientation(sent), 6);
      }
    });
  });
}
