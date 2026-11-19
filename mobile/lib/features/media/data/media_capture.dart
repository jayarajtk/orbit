import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

/// Media captured or picked on the device, ready to upload.
class PickedMedia {
  /// Creates picked media.
  const PickedMedia({
    required this.bytes,
    required this.contentType,
    this.durationMs,
  });

  /// File contents.
  final Uint8List bytes;

  /// MIME type the server is told.
  final String contentType;

  /// Length of video or audio.
  final int? durationMs;
}

/// Picks photos and videos. Abstracted so screens can be tested.
abstract interface class MediaPicker {
  /// A photo from the library or the camera, resized to at most 2048 px.
  /// It may still hold metadata, location included (the iOS picker keeps
  /// it); `MediaRepository.upload` strips that. Null if the user cancels.
  Future<PickedMedia?> pickPhoto({required bool camera});

  /// Up to [limit] photos from the library, in the order they were picked.
  /// Resized and left with metadata exactly as [pickPhoto] leaves them.
  /// Empty if the user cancels.
  Future<List<PickedMedia>> pickPhotos({int limit = 10});

  /// A video of up to [maxDuration] from the library, as the library holds
  /// it: location included (`MediaRepository.upload` strips that). Null if
  /// cancelled.
  Future<PickedMedia?> pickVideo({required Duration maxDuration});
}

/// Records voice notes. Abstracted so screens can be tested.
abstract interface class VoiceRecorder {
  /// Starts recording; false when microphone access is denied.
  Future<bool> start();

  /// Stops and returns the recording, or null if nothing was recorded.
  Future<PickedMedia?> stop();

  /// Stops and throws the recording away.
  Future<void> cancel();
}

/// The device's picker.
final mediaPickerProvider = Provider<MediaPicker>(
  (ref) => ImagePickerMediaPicker(),
);

/// A new recorder for each use; disposed with the provider.
final Provider<VoiceRecorder> voiceRecorderProvider =
    Provider.autoDispose<VoiceRecorder>((ref) {
      final recorder = RecordVoiceRecorder();
      ref.onDispose(recorder.dispose);
      return recorder;
    });

/// [MediaPicker] on `image_picker`.
class ImagePickerMediaPicker implements MediaPicker {
  /// Creates the picker; [picker] replaces the device's in tests.
  ImagePickerMediaPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Longest side sent for photos; the server keeps at most this too.
  static const maxPhotoSide = 2048.0;

  static const _photoQuality = 85;

  @override
  Future<PickedMedia?> pickPhoto({required bool camera}) async {
    final file = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: maxPhotoSide,
      maxHeight: maxPhotoSide,
      imageQuality: _photoQuality,
      requestFullMetadata: false,
    );
    return file == null ? null : _photo(file);
  }

  @override
  Future<List<PickedMedia>> pickPhotos({int limit = 10}) async {
    final files = await _picker.pickMultiImage(
      maxWidth: maxPhotoSide,
      maxHeight: maxPhotoSide,
      imageQuality: _photoQuality,
      limit: limit,
      requestFullMetadata: false,
    );
    return [for (final file in files.take(limit)) await _photo(file)];
  }

  Future<PickedMedia> _photo(XFile file) async => PickedMedia(
    bytes: await file.readAsBytes(),
    contentType: file.name.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg',
  );

  @override
  Future<PickedMedia?> pickVideo({required Duration maxDuration}) async {
    final file = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: maxDuration,
    );
    if (file == null) return null;
    final controller = VideoPlayerController.file(File(file.path));
    final Duration duration;
    try {
      await controller.initialize();
      duration = controller.value.duration;
    } finally {
      await controller.dispose();
    }
    return PickedMedia(
      bytes: await file.readAsBytes(),
      contentType: file.name.toLowerCase().endsWith('.mov')
          ? 'video/quicktime'
          : 'video/mp4',
      durationMs: duration.inMilliseconds,
    );
  }
}

/// [VoiceRecorder] on `record`: mono AAC in an M4A file, deleted after it
/// is read.
class RecordVoiceRecorder implements VoiceRecorder {
  final _recorder = AudioRecorder();
  final _clock = Stopwatch();
  String? _path;

  @override
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    final path =
        '${Directory.systemTemp.path}/voice-'
        '${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(bitRate: 64000, numChannels: 1),
      path: path,
    );
    _path = path;
    _clock
      ..reset()
      ..start();
    return true;
  }

  @override
  Future<PickedMedia?> stop() async {
    _clock.stop();
    final path = await _recorder.stop() ?? _path;
    _path = null;
    if (path == null) return null;
    final file = File(path);
    try {
      final bytes = await file.readAsBytes();
      return bytes.isEmpty
          ? null
          : PickedMedia(
              bytes: bytes,
              contentType: 'audio/mp4',
              durationMs: _clock.elapsedMilliseconds,
            );
    } finally {
      if (file.existsSync()) await file.delete();
    }
  }

  @override
  Future<void> cancel() async {
    _clock.stop();
    final path = _path;
    _path = null;
    await _recorder.cancel();
    if (path != null && File(path).existsSync()) await File(path).delete();
  }

  /// Releases the recorder.
  void dispose() => unawaited(_recorder.dispose());
}
