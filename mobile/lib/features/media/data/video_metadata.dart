import 'dart:convert';
import 'dart:typed_data';

/// Removes metadata, location included, from an MP4 or QuickTime file
/// before it leaves the phone.
///
/// The server stores videos and voice notes as uploaded and recipients get
/// that file, so this is the only place location is removed. The iOS picker
/// hands over the library's original file, which keeps the location the
/// camera wrote in `moov/meta` and `moov/udta/©xyz`.
///
/// Every `udta` and `meta` box in the movie and its tracks, and every XMP
/// `uuid` box, is turned into a `free` box of the same size filled with
/// zeros. Nothing moves, so the chunk offsets into the media data stay valid
/// and the file plays exactly as before, with no re-encoding.
///
/// Not covered: location recorded as a timed-metadata track inside the media
/// data. Phones don't write one in ordinary camera videos.
///
/// Throws [FormatException] if the file is not MP4/QuickTime (it must start
/// with an `ftyp` box, as the server also requires) or its boxes are
/// malformed or has no `moov` box, so a file that could not be cleaned is
/// never uploaded. The input is not modified.
Uint8List stripVideoMetadata(Uint8List bytes) {
  if (bytes.length < 8 || _type(bytes, 4) != 'ftyp') {
    throw const FormatException('Not an MP4 or QuickTime file');
  }
  final blank = <_Box>[];
  final hasMovie = _collect(bytes, 0, bytes.length, blank, insideMovie: false);
  if (!hasMovie) throw const FormatException('No movie box');
  if (blank.isEmpty) return bytes;
  final out = Uint8List.fromList(bytes);
  for (final box in blank) {
    out
      ..setRange(box.start + 4, box.start + 8, _free)
      ..fillRange(box.payload, box.end, 0);
  }
  return out;
}

/// A box: where it starts, where its payload starts (after an 8- or
/// 16-byte header) and where it ends.
typedef _Box = ({int start, int payload, int end});

final Uint8List _free = ascii.encode('free');

/// Boxes walked into to find metadata. Media and sample tables are skipped.
const _containers = {'moov', 'trak', 'mdia', 'minf'};

/// Metadata boxes allowed inside the movie and its tracks.
const _metadata = {'udta', 'meta'};

const _xmpUuid = [
  0xBE, 0x7A, 0xCF, 0xCB, 0x97, 0xA9, 0x42, 0xE8, //
  0x9C, 0x71, 0x99, 0x94, 0x91, 0xE3, 0xAF, 0xAC,
];

String _type(Uint8List bytes, int at) =>
    latin1.decode(Uint8List.sublistView(bytes, at, at + 4));

bool _isXmp(Uint8List bytes, int payload, int end) {
  if (payload + _xmpUuid.length > end) return false;
  for (var i = 0; i < _xmpUuid.length; i++) {
    if (bytes[payload + i] != _xmpUuid[i]) return false;
  }
  return true;
}

/// Walks the boxes in [start, end) and adds the ones to blank to [blank].
/// Returns whether a `moov` box was among them.
bool _collect(
  Uint8List bytes,
  int start,
  int end,
  List<_Box> blank, {
  required bool insideMovie,
}) {
  final data = ByteData.sublistView(bytes);
  var hasMovie = false;
  var i = start;
  while (i < end) {
    if (i + 8 > end) throw const FormatException('Truncated box header');
    var size = data.getUint32(i);
    var header = 8;
    if (size == 1) {
      if (i + 16 > end) throw const FormatException('Truncated box header');
      size = data.getUint64(i + 8);
      header = 16;
    } else if (size == 0) {
      size = end - i; // the box runs to the end of its parent
    }
    if (size < header || i + size > end) {
      throw const FormatException('Box size runs past its parent');
    }
    final type = _type(bytes, i + 4);
    final boxEnd = i + size;
    if (type == 'moov') hasMovie = true;
    final isMetadata =
        (insideMovie && _metadata.contains(type)) ||
        (!insideMovie && type == 'meta') ||
        (type == 'uuid' && _isXmp(bytes, i + header, boxEnd));
    if (isMetadata) {
      blank.add((start: i, payload: i + header, end: boxEnd));
    } else if (_containers.contains(type)) {
      _collect(bytes, i + header, boxEnd, blank, insideMovie: true);
    }
    i = boxEnd;
  }
  return hasMovie;
}
