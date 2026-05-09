// lib/screens/aria_brief_screen.dart
// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ARIABriefScreen extends StatefulWidget {
  final String brief;
  const ARIABriefScreen({super.key, required this.brief});

  @override
  State<ARIABriefScreen> createState() => _ARIABriefScreenState();
}

class _ARIABriefScreenState extends State<ARIABriefScreen>
    with TickerProviderStateMixin {
  final FlutterTts _tts = FlutterTts();

  bool _isSpeaking = false;
  bool _isDone = false;
  int _currentWordIndex = -1;

  late List<String> _words;
  late List<String> _lines;

  int get _currentLine {
    if (_currentWordIndex < 0) return 0;
    int count = 0;
    for (int i = 0; i < _lines.length; i++) {
      final n = _lines[i].trim().split(RegExp(r'\s+')).length;
      count += n;
      if (_currentWordIndex < count) return i;
    }
    return _lines.length - 1;
  }

  late AnimationController _bgCtrl;
  late AnimationController _breatheCtrl;
  late AnimationController _enterCtrl;
  late AnimationController _waveCtrl;

  late Animation<double> _bg;
  late Animation<double> _breathe;
  late Animation<double> _enter;
  late Animation<double> _wave;

  @override
  void initState() {
    super.initState();

    _words = widget.brief.trim().split(RegExp(r'\s+'));
    _lines = _splitLines(_words, 6);

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _enter   = CurvedAnimation(parent: _enterCtrl,   curve: Curves.easeOutCubic);
    _bg      = CurvedAnimation(parent: _bgCtrl,      curve: Curves.easeInOut);
    _breathe = CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut);
    _wave    = CurvedAnimation(parent: _waveCtrl,    curve: Curves.linear);

    _initTts();
  }

  List<String> _splitLines(List<String> words, int perLine) {
    final lines = <String>[];
    for (int i = 0; i < words.length; i += perLine) {
      final end = math.min(i + perLine, words.length);
      lines.add(words.sublist(i, end).join(' '));
    }
    return lines;
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setVolume(0.88);
    await _tts.setSpeechRate(0.36);
    await _tts.setPitch(0.74);
    await _tts.awaitSpeakCompletion(true);
    await _tts.setQueueMode(1);

    try {
      final voices = await _tts.getVoices;
      if (voices != null) {
        final voiceList = voices as List;
        final preferred = voiceList.firstWhere((v) {
          final name = v['name'].toString().toLowerCase();
          return name.contains('en-us-x-sfg') ||
              name.contains('en-us-x-iol') ||
              name.contains('en-us-x-tpf') ||
              name.contains('neural') ||
              name.contains('wavenet') ||
              name.contains('female') ||
              name.contains('journey') ||
              name.contains('studio');
        }, orElse: () => voiceList.first);
        await _tts.setVoice({
          'name': preferred['name'],
          'locale': preferred['locale'],
        });
      }
    } catch (_) {}

    _tts.setStartHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = true);
    });

    _tts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _isDone = true;
        _currentWordIndex = _words.length;
      });
    });

    _tts.setCancelHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
    });

    _tts.setProgressHandler((text, start, end, word) {
      if (!mounted) return;
      final clean = word.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
      for (int i = math.max(0, _currentWordIndex); i < _words.length; i++) {
        if (_words[i].replaceAll(RegExp(r'[^\w]'), '').toLowerCase() == clean) {
          if (i != _currentWordIndex) setState(() => _currentWordIndex = i);
          break;
        }
      }
    });

    await Future.delayed(const Duration(milliseconds: 400));

    String processed = widget.brief
        .replaceAll('...', ' ')
        .replaceAll('..', ' ')
        .replaceAll('—', ', ')
        .replaceAll('. ', ', ')
        .replaceAll('!', ',')
        .trim();

    if (processed.isNotEmpty) {
      setState(() { _currentWordIndex = 0; _isDone = false; });
      await _tts.speak(processed);
    }
  }

  Future<void> _speak() async {
    if (widget.brief.isEmpty) return;
    setState(() { _currentWordIndex = 0; _isDone = false; });
    await _tts.speak(widget.brief);
  }

  Future<void> _toggleSpeech() async {
    HapticFeedback.lightImpact();
    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
    } else {
      await _speak();
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _enterCtrl.dispose();
    _bgCtrl.dispose();
    _breatheCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF06050F),
      body: Stack(children: [
        // Full screen aurora background
        AnimatedBuilder(
          animation: Listenable.merge([_bgCtrl, _breatheCtrl]),
          builder: (_, __) => CustomPaint(
            painter: _FullBgPainter(_bg.value, _breathe.value, _isSpeaking),
            child: const SizedBox.expand(),
          ),
        ),

        SafeArea(
          child: FadeTransition(
            opacity: _enter,
            child: Column(children: [
              _buildTopBar(),
              const Spacer(flex: 2),
              // Visual indicator — small elegant waveform
              _buildVisualIndicator(size),
              const SizedBox(height: 48),
              // Text takes center stage
              _buildLyrics(),
              const Spacer(flex: 3),
              _buildControls(),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: ClipOval(child: Image.asset('assets/aria_logo.png', fit: BoxFit.cover)),
          ),
          const SizedBox(width: 8),
          Text('Daily Brief', style: GoogleFonts.spaceGrotesk(
            color: Colors.white.withOpacity(0.30),
            fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5,
          )),
        ]),
        GestureDetector(
          onTap: () { _tts.stop(); Navigator.pop(context); },
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Icon(Icons.close_rounded,
                color: Colors.white.withOpacity(0.30), size: 13),
          ),
        ),
      ],
    ),
  );

  // Small waveform bars — elegant and minimal
  Widget _buildVisualIndicator(Size size) {
    return AnimatedBuilder(
      animation: Listenable.merge([_waveCtrl, _breatheCtrl]),
      builder: (_, __) {
        return SizedBox(
          width: 80, height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(9, (i) {
              final phase = (i / 9) * math.pi * 2;
              final t = _wave.value * math.pi * 2 + phase;
              final h = _isSpeaking
                  ? 8.0 + 24.0 * ((math.sin(t) + 1) / 2)
                  : 4.0 + 4.0 * ((math.sin(t * 0.5) + 1) / 2) * _breathe.value;

              final isCenter = i == 4;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: isCenter ? 3.5 : 2.5,
                height: h.clamp(3.0, 32.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isCenter
                      ? const Color(0xFF9B6FE8).withOpacity(_isSpeaking ? 0.90 : 0.40)
                      : Colors.white.withOpacity(_isSpeaking ? 0.50 : 0.18),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildLyrics() {
    final active = _currentLine;
    final prev   = active - 1;
    final next   = active + 1;

    String lineText(int idx) {
      if (idx < 0 || idx >= _lines.length) return '';
      return _lines[idx];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // Previous line
          AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: prev >= 0 ? 0.22 : 0.0,
            child: Text(lineText(prev),
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Active line — large and prominent
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: Text(lineText(active),
              key: ValueKey(active),
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.40,
                letterSpacing: -0.3,
                shadows: [
                  Shadow(
                    color: const Color(0xFF8A6CD1).withOpacity(0.80),
                    blurRadius: 20,
                  ),
                  Shadow(
                    color: const Color(0xFF8A6CD1).withOpacity(0.40),
                    blurRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Next line
          AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: next < _lines.length ? 0.22 : 0.0,
            child: Text(lineText(next),
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() => Column(children: [
    GestureDetector(
      onTap: _toggleSpeech,
      child: AnimatedBuilder(
        animation: _breatheCtrl,
        builder: (_, __) => Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isSpeaking
                ? const Color(0xFF8A6CD1).withOpacity(0.15 + 0.05 * _breathe.value)
                : Colors.white.withOpacity(0.05),
            border: Border.all(
              color: _isSpeaking
                  ? const Color(0xFF8A6CD1).withOpacity(0.50 + 0.15 * _breathe.value)
                  : Colors.white.withOpacity(0.12),
              width: 1.2,
            ),
            boxShadow: _isSpeaking ? [BoxShadow(
              color: const Color(0xFF8A6CD1).withOpacity(0.20 + 0.10 * _breathe.value),
              blurRadius: 24, spreadRadius: -2,
            )] : [],
          ),
          child: Icon(
            _isSpeaking ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white.withOpacity(_isSpeaking ? 0.90 : 0.55),
            size: 24,
          ),
        ),
      ),
    ),
    const SizedBox(height: 10),
    Text(
      _isSpeaking ? 'Tap to pause' : _isDone ? 'Tap to replay' : 'Tap to play',
      style: GoogleFonts.spaceGrotesk(
        color: Colors.white.withOpacity(0.16),
        fontSize: 10, letterSpacing: 0.5,
      ),
    ),
  ]);
}

// Full screen background — immersive aurora
class _FullBgPainter extends CustomPainter {
  final double t;
  final double breathe;
  final bool speaking;
  _FullBgPainter(this.t, this.breathe, this.speaking);

  @override
  void paint(Canvas canvas, Size size) {
    // Base
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF06050F));

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Large violet bloom — top, shifts slowly
    canvas.drawCircle(
      Offset(cx + 30 * math.sin(t * math.pi), cy * 0.38),
      size.width * 0.75,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80)
        ..color = const Color(0xFF5820A8).withOpacity(
            speaking ? 0.22 + 0.08 * breathe : 0.10 + 0.03 * breathe),
    );

    // Offset violet — left
    canvas.drawCircle(
      Offset(size.width * 0.15, cy * 0.60),
      size.width * 0.50,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 65)
        ..color = const Color(0xFF4015A0).withOpacity(
            speaking ? 0.16 + 0.06 * breathe : 0.06),
    );

    // Mint accent — bottom right, very subtle
    canvas.drawCircle(
      Offset(size.width * 0.85, cy * 1.45),
      size.width * 0.40,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60)
        ..color = const Color(0xFF1A8060).withOpacity(
            speaking ? 0.08 + 0.04 * breathe : 0.03),
    );

    // Centre glow — behind text area, intensifies when speaking
    canvas.drawCircle(
      Offset(cx, cy * 1.10),
      size.width * 0.45,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70)
        ..color = const Color(0xFF6830C0).withOpacity(
            speaking ? 0.14 + 0.06 * breathe : 0.04),
    );
  }

  @override
  bool shouldRepaint(_FullBgPainter old) =>
      old.t != t || old.breathe != breathe || old.speaking != speaking;
}