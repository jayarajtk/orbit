import 'dart:convert';
import 'dart:typed_data';

/// Removes metadata from a JPEG or PNG photo before it leaves the phone.
///
/// The server re-encodes every photo and drops all metadata, but the file
/// still travels to storage first. On iOS `image_picker` keeps the EXIF GPS
/// block even with `requestFullMetadata: false`, so the app cleans the file
/// itself (design doc §7.4: location never leaves the device in a photo).
///
/// This edits the file's structure only; pixels are not decoded or
/// re-encoded, so it is fast and loses no quality.
///
/// * JPEG: keeps what decoding needs (JFIF header, ICC colour profile, Adobe
///   colour transform, tables, frames and scans). EXIF, XMP, IPTC, comments,
///   multi-picture indexes and anything after the first image (such as HDR
///   gain maps, which carry their own EXIF) are dropped. A rotation is kept
///   as the only tag of a new EXIF block: the pixels are stored unrotated
///   and the server applies it.
/// * PNG: drops EXIF, text and time chunks and anything after the image.
///
/// Throws [FormatException] for any other format or a malformed file, so a
/// file that could not be cleaned is never uploaded.
Uint8List stripPhotoMetadata(Uint8List bytes) {
  if (_startsWith(bytes, _jpegStart)) return _stripJpeg(bytes);
  if (_startsWith(bytes, _pngSignature)) return _stripPng(bytes);
  throw const FormatException('Not a JPEG or PNG photo');
}

const _jpegStart = [0xFF, 0xD8];
const _pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

bool _startsWith(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

bool _payloadStartsWith(Uint8List payload, String signature) =>
    _startsWith(payload, ascii.encode(signature));

// JPEG markers used below.
const _app0 = 0xE0;
const _app1 = 0xE1;
const _app2 = 0xE2;
const _app14 = 0xEE;
const _comment = 0xFE;
const _startOfScan = 0xDA;
const _endOfImage = 0xD9;

bool _isApp(int marker) => marker >= _app0 && marker <= 0xEF;

bool _isRestart(int marker) => marker >= 0xD0 && marker <= 0xD7;

/// Markers with no length field. TEM (0x01) and restarts can appear outside
/// scans in unusual files.
bool _isStandalone(int marker) => marker == 0x01 || _isRestart(marker);

/// Whether a segment is needed to decode the image correctly.
bool _keepSegment(int marker, Uint8List payload) {
  if (marker == _comment) return false;
  if (!_isApp(marker)) return true;
  return switch (marker) {
    _app0 => _payloadStartsWith(payload, 'JFIF\u0000'),
    _app2 => _payloadStartsWith(payload, 'ICC_PROFILE\u0000'),
    _app14 => _payloadStartsWith(payload, 'Adobe'),
    _ => false,
  };
}

Uint8List _stripJpeg(Uint8List bytes) {
  final out = BytesBuilder(copy: false)..add(_jpegStart);
  final length = bytes.length;
  var i = 2;
  while (true) {
    if (i + 1 >= length || bytes[i] != 0xFF) {
      throw const FormatException('Malformed JPEG: expected a marker');
    }
    // Any number of 0xFF fill bytes may come before a marker.
    while (i + 1 < length && bytes[i + 1] == 0xFF) {
      i++;
    }
    if (i + 1 >= length) throw const FormatException('Truncated JPEG');
    final marker = bytes[i + 1];
    i += 2;
    if (marker == _endOfImage) {
      // Anything after the first image (gain maps, thumbnails) is dropped.
      return (out..add(const [0xFF, _endOfImage])).takeBytes();
    }
    if (_isStandalone(marker)) {
      out.add([0xFF, marker]);
      continue;
    }
    if (i + 2 > length) throw const FormatException('Truncated JPEG');
    final segmentLength = bytes[i] << 8 | bytes[i + 1];
    if (segmentLength < 2 || i + segmentLength > length) {
      throw const FormatException('Malformed JPEG segment length');
    }
    final payload = Uint8List.sublistView(bytes, i + 2, i + segmentLength);
    final segment = Uint8List.sublistView(bytes, i - 2, i + segmentLength);
    i += segmentLength;

    if (_keepSegment(marker, payload)) {
      out.add(segment);
    } else if (marker == _app1 && _payloadStartsWith(payload, 'Exif')) {
      final orientation = _exifOrientation(payload);
      if (orientation != 1) out.add(_orientationSegment(orientation));
    }
    if (marker == _startOfScan) {
      final scanEnd = _endOfScan(bytes, i);
      out.add(Uint8List.sublistView(bytes, i, scanEnd));
      i = scanEnd;
    }
  }
}

/// Index of the first marker after the entropy-coded data starting at
/// [start]. Inside scans, FF 00 is an escaped data byte and FF D0–D7 are
/// restart markers; any other FF xx ends the scan.
int _endOfScan(Uint8List bytes, int start) {
  var i = start;
  while (i + 1 < bytes.length) {
    if (bytes[i] == 0xFF) {
      final next = bytes[i + 1];
      if (next != 0x00 && !_isRestart(next)) return i;
      i += 2;
    } else {
      i++;
    }
  }
  throw const FormatException('Truncated JPEG scan');
}

/// The EXIF orientation (1–8) in an APP1 payload, or 1 when there is none or
/// the block cannot be read (the block is dropped either way).
int _exifOrientation(Uint8List payload) {
  const tiff = 6; // after "Exif\0\0"
  if (payload.length < tiff + 8) return 1;
  final Endian endian;
  if (payload[tiff] == 0x49 && payload[tiff + 1] == 0x49) {
    endian = Endian.little;
  } else if (payload[tiff] == 0x4D && payload[tiff + 1] == 0x4D) {
    endian = Endian.big;
  } else {
    return 1;
  }
  final data = ByteData.sublistView(payload, tiff);
  final ifd = data.getUint32(4, endian);
  if (ifd + 2 > data.lengthInBytes) return 1;
  final count = data.getUint16(ifd, endian);
  for (var k = 0; k < count; k++) {
    final entry = ifd + 2 + 12 * k;
    if (entry + 12 > data.lengthInBytes) return 1;
    if (data.getUint16(entry, endian) != 0x0112) continue;
    const short = 3;
    if (data.getUint16(entry + 2, endian) != short) return 1;
    final value = data.getUint16(entry + 8, endian);
    return value >= 1 && value <= 8 ? value : 1;
  }
  return 1;
}

/// An APP1 EXIF segment whose only tag is the orientation (big-endian TIFF).
Uint8List _orientationSegment(int orientation) {
  final payload = [
    ...ascii.encode('Exif'), 0, 0, //
    0x4D, 0x4D, 0, 42, 0, 0, 0, 8, // header, IFD0 at offset 8
    0, 1, // one entry
    0x01, 0x12, 0, 3, 0, 0, 0, 1, 0, orientation, 0, 0, // SHORT orientation
    0, 0, 0, 0, // no next IFD
  ];
  final length = payload.length + 2;
  return Uint8List.fromList([
    0xFF,
    _app1,
    length >> 8,
    length & 0xFF,
    ...payload,
  ]);
}

/// PNG chunks that carry metadata rather than image data.
const _pngMetadataChunks = {'eXIf', 'tEXt', 'zTXt', 'iTXt', 'tIME'};

Uint8List _stripPng(Uint8List bytes) {
  final out = BytesBuilder(copy: false)..add(_pngSignature);
  final data = ByteData.sublistView(bytes);
  var i = _pngSignature.length;
  while (true) {
    // length (4) + type (4) + data + CRC (4)
    if (i + 12 > bytes.length) throw const FormatException('Truncated PNG');
    final dataLength = data.getUint32(i);
    final end = i + 12 + dataLength;
    if (end > bytes.length) throw const FormatException('Truncated PNG');
    final type = ascii.decode(bytes.sublist(i + 4, i + 8), allowInvalid: true);
    if (!_pngMetadataChunks.contains(type)) {
      out.add(Uint8List.sublistView(bytes, i, end));
    }
    i = end;
    if (type == 'IEND') return out.takeBytes();
  }
}
