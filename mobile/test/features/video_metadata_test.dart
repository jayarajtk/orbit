import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/media/data/video_metadata.dart';

import '../helpers/video_bytes.dart';

String _latin1(Uint8List bytes) => latin1.decode(bytes);

void main() {
  test('removes location from every place cameras write it', () {
    final text = _latin1(stripVideoMetadata(locatedVideo()));

    expect(text, isNot(contains(location)));
    expect(text, isNot(contains('ISO6709')));
    expect(text, isNot(contains('<xmp>')));
    expect(text, isNot(contains('udta')));
    expect(text, isNot(contains('meta')));
  });

  test('moves no bytes, so offsets into the media data stay valid', () {
    final original = locatedVideo();
    final stripped = stripVideoMetadata(original);

    expect(stripped.length, original.length);
    final at = _latin1(
      original,
    ).indexOf(_latin1(Uint8List.fromList(mediaData)));
    expect(
      stripped.sublist(at, at + mediaData.length),
      mediaData,
    );
    expect(_latin1(stripped), contains('stco'));
    expect(_latin1(stripped), contains('free'));
  });

  test('handles 64-bit and to-the-end box sizes', () {
    for (final video in [
      locatedVideo(largeMdat: true),
      locatedVideo(mdatToEnd: true),
    ]) {
      final stripped = stripVideoMetadata(video);

      expect(_latin1(stripped), isNot(contains(location)));
      expect(stripped.length, video.length);
    }
  });

  test('a blanked box with a 64-bit size keeps that size', () {
    final original = locatedVideo(largeUdta: true);
    final at = _latin1(original).indexOf('\u0000\u0000\u0000\u0001udta');
    final stripped = stripVideoMetadata(original);
    final data = ByteData.sublistView(stripped);

    expect(at, greaterThan(0));
    expect(data.getUint32(at), 1, reason: 'still marks a 64-bit size');
    expect(_latin1(stripped).substring(at + 4, at + 8), 'free');
    expect(
      data.getUint64(at + 8),
      ByteData.sublistView(original).getUint64(at + 8),
    );
    expect(_latin1(stripped), isNot(contains(location)));
  });

  test('a video without metadata is unchanged', () {
    expect(stripVideoMetadata(plainVideo()), plainVideo());
  });

  test("does not change the caller's bytes", () {
    final original = locatedVideo();
    final copy = Uint8List.fromList(original);

    stripVideoMetadata(original);

    expect(original, copy);
  });

  test('refuses a file whose box sizes run past its end', () {
    final cut = locatedVideo().sublist(0, 110);

    expect(() => stripVideoMetadata(cut), throwsFormatException);
  });

  test('refuses a file with no movie box', () {
    final original = locatedVideo();
    final noMovie = original.sublist(0, _latin1(original).indexOf('moov') - 4);

    expect(() => stripVideoMetadata(noMovie), throwsFormatException);
  });

  test('refuses a file that is not MP4 or QuickTime', () {
    expect(
      () => stripVideoMetadata(Uint8List.fromList(utf8.encode('RIFF....AVI '))),
      throwsFormatException,
    );
  });
}
