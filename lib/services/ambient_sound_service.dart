import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

class AmbientSound {
  final String id;
  final String name;
  final String emoji;
  final String category;
  final String url;

  const AmbientSound({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.url,
  });
}

class AmbientSoundService {
  static final AmbientSoundService instance = AmbientSoundService._();
  AmbientSoundService._();

  final AudioPlayer _player = AudioPlayer();
  AmbientSound? currentSound;

  static const String _base =
      'https://raw.githubusercontent.com/Ayesha-Khan10/aria-assets/main';

  static const List<AmbientSound> sounds = [
    AmbientSound(
      id: 'rain',
      name: 'Rain',
      emoji: '🌧️',
      category: 'Nature',
      url: '$_base/rain.mp3',
    ),
    AmbientSound(
      id: 'instrumental',
      name: 'Instrumental',
      emoji: '🎵',
      category: 'Music',
      url: '$_base/instrumental.mp3',
    ),
    AmbientSound(
      id: 'minimal',
      name: 'Minimal',
      emoji: '🌿',
      category: 'Nature',
      url: '$_base/minimal.mp3',
    ),
    AmbientSound(
      id: 'silent',
      name: 'Silent',
      emoji: '🔇',
      category: 'None',
      url: '',
    ),
  ];

  bool get isPlaying => _player.playing;

  Future<void> play(AmbientSound sound) async {
    if (sound.url.isEmpty) {
      await stop();
      currentSound = sound;
      return;
    }
    try {
      await _player.stop();
      currentSound = sound;
      final source = AudioSource.uri(Uri.parse(sound.url));
      await _player.setAudioSource(source);
      await _player.setLoopMode(LoopMode.one);
      await _player.setVolume(0.6);
      _player.play();
      debugPrint('🎵 Playing: ${sound.name}');
    } catch (e) {
      debugPrint('❌ Audio error: $e');
    }
  }

  Future<void> stop() async {
    try {
      currentSound = null;
      await _player.stop();
    } catch (e) {
      debugPrint('Audio stop error: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (_) {}
  }

  Future<void> resume() async {
    try {
      await _player.play();
    } catch (_) {}
  }

  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume);
    } catch (_) {}
  }

  void dispose() => _player.dispose();
}