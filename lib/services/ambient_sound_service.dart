import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

class AmbientSoundService {
  static final AmbientSoundService instance = AmbientSoundService._();
  AmbientSoundService._();

  final AudioPlayer _player = AudioPlayer();

  // Free, loopable ambient sound URLs
  static const _soundUrls = [
    'https://raw.githubusercontent.com/Ayesha-Khan10/aria-assets/main/rain.mp3',
    'https://raw.githubusercontent.com/Ayesha-Khan10/aria-assets/main/instrumental.mp3',
    'https://raw.githubusercontent.com/Ayesha-Khan10/aria-assets/main/minimal.mp3',
    '', // Silent
  ];

  bool get isPlaying => _player.playing;

  Future<void> play(int soundIndex) async {
    if (soundIndex == 3 || _soundUrls[soundIndex].isEmpty) {
      await stop();
      return;
    }

    try {
      await _player.stop();
      debugPrint('🎵 Attempting to play: ${_soundUrls[soundIndex]}');
      final source = AudioSource.uri(Uri.parse(_soundUrls[soundIndex]));
      await _player.setAudioSource(source);
      await _player.setLoopMode(LoopMode.one);
      await _player.setVolume(0.6);
      _player.play();
      debugPrint('🎵 Play called successfully');
    } catch (e) {
      debugPrint('❌ Audio error: $e'); // tell me what this prints
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('Audio stop error: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('Audio pause error: $e');
    }
  }

  Future<void> resume() async {
    try {
      await _player.play();
    } catch (e) {
      debugPrint('Audio resume error: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }

  Future<void> setVolume(double volume) async {
  try {
    await _player.setVolume(volume);
  } catch (e) {
    debugPrint('Set volume error: $e');
  }
}
}
