import 'dart:convert';
import 'dart:typed_data';

/// Builders for MP4/QuickTime box layouts. The metadata stripper never
/// decodes media, so files with the right structure are enough to test it.

List<int> _u32(int value) => [
  value >> 24 & 0xFF,
  value >> 16 & 0xFF,
  value >> 8 & 0xFF,
  value & 0xFF,
];

/// A box: size, [type], [payload].
List<int> box(String type, List<int> payload) => [
  ..._u32(payload.length + 8),
  ...latin1.encode(type),
  ...payload,
];

/// A box with a 64-bit size, as large `mdat` boxes are written.
List<int> largeBox(String type, List<int> payload) => [
  ..._u32(1),
  ...latin1.encode(type),
  ...List.filled(4, 0),
  ..._u32(payload.length + 16),
  ...payload,
];

/// Location as iPhone and Android cameras write it.
const String location = '+51.5007-000.1246+010.000/';

/// Media data that must survive untouched.
final List<int> mediaData = latin1.encode('frame-1 frame-2 frame-3');

/// The adobe XMP box id.
const List<int> xmpUuid = [
  0xBE, 0x7A, 0xCF, 0xCB, 0x97, 0xA9, 0x42, 0xE8, //
  0x9C, 0x71, 0x99, 0x94, 0x91, 0xE3, 0xAF, 0xAC,
];

/// The parts of `moov` needed to play the file. Contains the chunk offset
/// table (`stco`), which is why the stripper must not move any bytes.
final List<int> playbackBoxes = [
  ...box('mvhd', List.filled(20, 1)),
  ...box(
    'trak',
    [
      ...box('tkhd', List.filled(20, 2)),
      ...box(
        'mdia',
        box(
          'minf',
          box('stbl', box('stco', [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 40])),
        ),
      ),
    ],
  ),
];

/// A QuickTime file as the iOS picker hands it over: location in
/// `moov/udta/©xyz`, in `moov/meta` (keys + ilst), in a track's `udta`, and
/// in a top-level XMP box.
Uint8List locatedVideo({
  bool largeMdat = false,
  bool mdatToEnd = false,
  bool largeUdta = false,
}) {
  final udta = largeUdta ? largeBox : box;
  final mdat = largeMdat ? largeBox('mdat', mediaData) : box('mdat', mediaData);
  final moov = box('moov', [
    ...box('mvhd', List.filled(20, 1)),
    ...box('trak', [
      ...box('tkhd', List.filled(20, 2)),
      ...box('udta', box('©xyz', latin1.encode(location))),
      ...box(
        'mdia',
        box(
          'minf',
          box('stbl', box('stco', [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 40])),
        ),
      ),
    ]),
    ...udta('udta', box('©xyz', latin1.encode(location))),
    ...box('meta', [
      ...box('hdlr', latin1.encode('mdta')),
      ...box('keys', latin1.encode('mdtacom.apple.quicktime.location.ISO6709')),
      ...box('ilst', box('data', latin1.encode(location))),
    ]),
  ]);
  return Uint8List.fromList([
    ...box('ftyp', latin1.encode('qt  \u0000\u0000\u0000\u0000qt  ')),
    ...box('uuid', [...xmpUuid, ...latin1.encode('<xmp>$location</xmp>')]),
    ...box('wide', []),
    if (!mdatToEnd) ...mdat,
    ...moov,
    if (mdatToEnd) ...[0, 0, 0, 0, ...latin1.encode('mdat'), ...mediaData],
  ]);
}

/// A clean MP4 with no metadata.
Uint8List plainVideo() => Uint8List.fromList([
  ...box('ftyp', latin1.encode('isom\u0000\u0000\u0000\u0000isom')),
  ...box('mdat', mediaData),
  ...box('moov', playbackBoxes),
]);
