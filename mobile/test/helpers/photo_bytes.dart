import 'dart:convert';
import 'dart:typed_data';

/// Builders for JPEG and PNG byte layouts. The metadata stripper never
/// decodes pixels, so files with the right structure are enough to test it.

List<int> _u16(int value) => [value >> 8 & 0xFF, value & 0xFF];

List<int> _u32(int value) => [
  value >> 24 & 0xFF,
  value >> 16 & 0xFF,
  value >> 8 & 0xFF,
  value & 0xFF,
];

/// A JPEG marker segment: FF, [marker], length, [payload].
List<int> segment(int marker, List<int> payload) => [
  0xFF,
  marker,
  ..._u16(payload.length + 2),
  ...payload,
];

/// An EXIF APP1 payload with an orientation tag and a GPS IFD holding a
/// latitude, laid out as the iOS picker writes it.
List<int> exifPayload({required int orientation, bool littleEndian = false}) {
  List<int> u16(int v) => littleEndian ? _u16(v).reversed.toList() : _u16(v);
  List<int> u32(int v) => littleEndian ? _u32(v).reversed.toList() : _u32(v);
  List<int> entry(int tag, int type, int count, List<int> value) => [
    ...u16(tag),
    ...u16(type),
    ...u32(count),
    ...value,
  ];
  // IFD0 at 8 with two entries (2 + 24 + 4 bytes), GPS IFD right after it.
  const gpsIfd = 8 + 2 + 24 + 4;
  return [
    ...ascii.encode('Exif'),
    0,
    0,
    ...(littleEndian ? ascii.encode('II') : ascii.encode('MM')),
    ...u16(42),
    ...u32(8),
    ...u16(2),
    ...entry(0x0112, 3, 1, [...u16(orientation), 0, 0]),
    ...entry(0x8825, 4, 1, u32(gpsIfd)),
    ...u32(0),
    ...u16(1),
    ...entry(0x0001, 2, 2, [...ascii.encode('N'), 0, 0, 0]),
    ...u32(0),
    ...ascii.encode('GPS-LATITUDE-51.5007'),
  ];
}

/// Tables, frame and scan of a tiny baseline JPEG. The scan data contains a
/// stuffed FF 00 and a restart marker, as real scans do.
final List<int> imageCore = [
  ...segment(0xDB, [0, ...List.filled(64, 1)]),
  ...segment(0xC0, [8, 0, 16, 0, 16, 1, 1, 0x11, 0]),
  ...segment(0xC4, [0, ...List.filled(16, 0)]),
  ...segment(0xDD, [0, 4]),
  ...segment(0xDA, [1, 1, 0, 0, 63, 0]),
  0x12, 0xFF, 0x00, 0x34, 0xFF, 0xD0, 0x56, 0x78, //
];

/// A JPEG as the iOS picker produces it: JFIF, EXIF with GPS, XMP, IPTC,
/// an ICC profile, a multi-picture index, a comment, the image, and a gain
/// map image appended after the end marker.
Uint8List pickerJpeg({int orientation = 1, bool littleEndian = false}) =>
    Uint8List.fromList([
      0xFF, 0xD8, //
      ...segment(0xE0, [...ascii.encode('JFIF'), 0, 1, 1, 0, 0, 1, 0, 1, 0, 0]),
      ...segment(
        0xE1,
        exifPayload(orientation: orientation, littleEndian: littleEndian),
      ),
      ...segment(0xE1, [
        ...ascii.encode('http://ns.adobe.com/xap/1.0/'),
        0,
        ...ascii.encode('<exif:GPSLatitude>51,30.04N</exif:GPSLatitude>'),
      ]),
      ...segment(0xED, ascii.encode('Photoshop 3.0 IPTC-City London')),
      ...segment(0xE2, [...ascii.encode('ICC_PROFILE'), 0, 1, 1, 9, 9, 9]),
      ...segment(0xE2, [...ascii.encode('MPF'), 0, 7, 7]),
      ...segment(0xFE, ascii.encode('taken at home')),
      ...imageCore,
      0xFF, 0xD9, //
      0xFF, 0xD8, //
      ...segment(0xE1, exifPayload(orientation: 1)),
      0xFF, 0xD9, //
    ]);

/// A clean JPEG with no metadata at all.
Uint8List plainJpeg() => Uint8List.fromList([
  0xFF, 0xD8, //
  ...segment(0xE0, [...ascii.encode('JFIF'), 0, 1, 1, 0, 0, 1, 0, 1, 0, 0]),
  ...imageCore,
  0xFF, 0xD9, //
]);

/// A PNG chunk: length, [type], [data], CRC (not checked by the stripper).
List<int> chunk(String type, List<int> data) => [
  ..._u32(data.length),
  ...ascii.encode(type),
  ...data,
  0, 0, 0, 0, //
];

/// A PNG with EXIF, text and time chunks around the image data.
Uint8List metadataPng() => Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, //
  ...chunk('IHDR', [0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0]),
  ...chunk('eXIf', exifPayload(orientation: 1).sublist(6)),
  ...chunk('tEXt', ascii.encode('Location\u0000London')),
  ...chunk('iTXt', ascii.encode('XML:com.adobe.xmp\u0000GPS')),
  ...chunk('zTXt', ascii.encode('Comment\u0000\u0000x')),
  ...chunk('tIME', [7, 234, 11, 18, 12, 0, 0]),
  ...chunk('iCCP', ascii.encode('icc\u0000\u0000x')),
  ...chunk('IDAT', [1, 2, 3]),
  ...chunk('IEND', []),
  ...ascii.encode('trailing'),
]);
