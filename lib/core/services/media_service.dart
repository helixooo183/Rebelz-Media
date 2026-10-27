import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Seçilen/sıkıştırılmış görsel.
class PickedImage {
  const PickedImage({
    required this.bytes,
    required this.mime,
  });

  final Uint8List bytes;
  final String mime;

  String get base64 => base64Encode(bytes);

  int get sizeKb => (bytes.length / 1024).round();
}

/// Kaydedilen sesli mesaj.
class RecordedVoice {
  const RecordedVoice({
    required this.base64,
    required this.durationMs,
    required this.mime,
  });

  final String base64;
  final int durationMs;
  final String mime;
}

/// Fotoğraf seçme, ses kaydetme ve oynatma işleri.
///
/// Medya Firebase Storage'a değil, Firestore dokümanına base64 olarak yazılır
/// (bkz. `docs/medya-ve-kanallar.md`). Bu yüzden seçim sırasında boyut
/// küçültülür: görsel en fazla 1200 px / %62 kalite, ses mono 32 kHz.
class MediaService {
  MediaService();

  static final MediaService instance = MediaService();

  final ImagePicker _picker = ImagePicker();
  final AudioPlayer _player = AudioPlayer();

  AudioRecorder? _recorder;
  final Stopwatch _stopwatch = Stopwatch();
  String? _recordingPath;

  // ------------------------------------------------------------------ görsel

  Future<PickedImage?> pickImage({bool fromCamera = false}) async {
    final file = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 62,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    return PickedImage(
      bytes: bytes,
      mime: file.mimeType ?? _guessMime(file.name),
    );
  }

  String _guessMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  // -------------------------------------------------------------------- ses

  AudioRecorder get _recorderInstance => _recorder ??= AudioRecorder();

  Future<bool> ensureMicPermission() async {
    try {
      return await _recorderInstance.hasPermission();
    } catch (_) {
      return false;
    }
  }

  bool get isRecording => _stopwatch.isRunning;

  /// Kaydı başlatır. İzin yoksa `false` döner.
  Future<bool> startRecording() async {
    if (isRecording) return true;
    if (!await ensureMicPermission()) return false;

    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/rebelz_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorderInstance.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 48000,
        sampleRate: 32000,
        numChannels: 1,
      ),
      path: _recordingPath!,
    );

    _stopwatch
      ..reset()
      ..start();
    return true;
  }

  /// Kaydı bitirir ve base64 sesli mesajı döndürür.
  Future<RecordedVoice?> stopRecording() async {
    if (!isRecording) return null;
    _stopwatch.stop();

    final path = await _recorderInstance.stop();
    final durationMs = _stopwatch.elapsedMilliseconds;

    final target = path ?? _recordingPath;
    if (target == null) return null;

    try {
      final bytes = await File(target).readAsBytes();
      try {
        await File(target).delete();
      } catch (_) {
        // Geçici dosya silinemezse sorun değil.
      }
      if (bytes.isEmpty) return null;
      return RecordedVoice(
        base64: base64Encode(bytes),
        durationMs: durationMs,
        mime: 'audio/mp4',
      );
    } catch (_) {
      return null;
    }
  }

  /// Kaydı iptal eder.
  Future<void> cancelRecording() async {
    if (!isRecording) return;
    _stopwatch.stop();
    try {
      await _recorderInstance.cancel();
    } catch (_) {
      await _recorderInstance.stop();
    }
  }

  // ---------------------------------------------------------------- oynatma

  Future<void> playVoice(String base64, String mime) async {
    await _player.stop();
    await _player.play(
      BytesSource(
        base64Decode(base64),
        mimeType: mime.isEmpty ? 'audio/mp4' : mime,
      ),
    );
  }

  Future<void> stopPlayback() async {
    await _player.stop();
  }

  Stream<Duration> get positionStream => _player.onPositionChanged;

  /// Oynatma bittiğinde haber verir.
  Stream<void> get finishedStream => _player.onPlayerComplete;

  void dispose() {
    _player.dispose();
    _recorder?.dispose();
  }
}

/// Süreyi "0:07" biçiminde yazar.
String formatDuration(int milliseconds) {
  final totalSeconds = (milliseconds / 1000).round();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
