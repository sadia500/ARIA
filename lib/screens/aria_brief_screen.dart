// lib/screens/aria_brief_screen.dart
// ignore_for_file: unnecessary_underscores, deprecated_member_use

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

  late AnimationController _auraCtrl;
  late AnimationController _breatheCtrl;
  late AnimationController _enterCtrl;

  late Animation<double> _aura;
  late Animation<double> _breathe;
  late Animation<double> _enter;

  @override
  void initState() {
    super.initState();

    _words = widget.brief.trim().split(RegExp(r'\s+'));
    _lines = _splitLines(_words, 6);

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    _auraCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _enter = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic);
    _aura = CurvedAnimation(parent: _auraCtrl, curve: Curves.linear);
    _breathe = CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut);

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
        .replaceAll('. ', ', ') // period becomes comma — shorter pause
        .replaceAll('!', ',') // exclamation becomes comma pause
        .trim();

    if (processed.isNotEmpty) {
      setState(() {
        _currentWordIndex = 0;
        _isDone = false;
      });
      await _tts.speak(processed);
    }
  }

  Future<void> _speak() async {
    if (widget.brief.isEmpty) return;
    setState(() {
      _currentWordIndex = 0;
      _isDone = false;
    });
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
    _auraCtrl.dispose();
    _breatheCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF05040D),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_auraCtrl, _breatheCtrl]),
            builder: (_, __) => CustomPaint(
              painter: _AuroraBgPainter(
                _aura.value,
                _breathe.value,
                _isSpeaking,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _enter,
              child: Column(
                children: [
                  _buildTopBar(),
                  SizedBox(
                    height: size.height * 0.42,
                    child: Center(child: _buildOrb(size)),
                  ),
                  Expanded(child: _buildLyrics()),
                  _buildControls(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: ClipOval(
                child: Image.asset('assets/aria_logo.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'ARIA',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withOpacity(0.22),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            _tts.stop();
            Navigator.pop(context);
          },
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.04),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Icon(
              Icons.close_rounded,
              color: Colors.white.withOpacity(0.28),
              size: 13,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildOrb(Size size) {
    final orbSize = size.width * 0.82; // bigger orb
    return AnimatedBuilder(
      animation: Listenable.merge([_auraCtrl, _breatheCtrl]),
      builder: (_, __) {
        final scale =
            0.98 +
            0.02 * _breathe.value +
            (_isSpeaking ? 0.02 * math.sin(_breathe.value * math.pi) : 0);
        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: orbSize,
            height: orbSize,
            child: CustomPaint(
              painter: _CrystalOrbPainter(
                _aura.value,
                _breathe.value,
                _isSpeaking,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLyrics() {
    final active = _currentLine;
    final prev = active - 1;
    final next = active + 1;

    String lineText(int idx) {
      if (idx < 0 || idx >= _lines.length) return '';
      return _lines[idx];
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: prev >= 0 ? 0.25 : 0.0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 6),
            child: Text(
              lineText(prev),
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: Padding(
            key: ValueKey(active),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            child: Text(
              lineText(active),
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                height: 1.45,
                letterSpacing: -0.2,
                shadows: [
                  Shadow(
                    color: const Color(0xFF9B6FE8).withOpacity(0.90),
                    blurRadius: 24,
                  ),
                  Shadow(
                    color: const Color(0xFF9B6FE8).withOpacity(0.45),
                    blurRadius: 48,
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: next < _lines.length ? 0.25 : 0.0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 6),
            child: Text(
              lineText(next),
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControls() => Column(
    children: [
      GestureDetector(
        onTap: _toggleSpeech,
        child: AnimatedBuilder(
          animation: _breatheCtrl,
          builder: (_, __) => Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
              border: Border.all(
                color: const Color(0xFF8A6CD1).withOpacity(
                  _isSpeaking ? 0.45 + 0.15 * _breathe.value : 0.18,
                ),
                width: 1.0,
              ),
              boxShadow: _isSpeaking
                  ? [
                      BoxShadow(
                        color: const Color(
                          0xFF8A6CD1,
                        ).withOpacity(0.22 + 0.10 * _breathe.value),
                        blurRadius: 24,
                        spreadRadius: -2,
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              _isSpeaking ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white.withOpacity(0.65),
              size: 22,
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        _isSpeaking
            ? 'Tap to pause'
            : _isDone
            ? 'Tap to replay'
            : 'Tap to play',
        style: GoogleFonts.spaceGrotesk(
          color: Colors.white.withOpacity(0.14),
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    ],
  );
}

class _CrystalOrbPainter extends CustomPainter {
  final double t;
  final double breathe;
  final bool speaking;

  _CrystalOrbPainter(this.t, this.breathe, this.speaking);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final a = t * math.pi * 2;

    // Core center glow
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.55,
      Paint()
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          speaking ? r * 0.45 + r * 0.08 * breathe : r * 0.42,
        )
        ..color = const Color(
          0xFF9B6FE8,
        ).withOpacity(speaking ? 0.75 + 0.12 * breathe : 0.50),
    );

    // Petal 1 — top right
    final p1x = cx + r * 0.38 * math.sin(a * 0.4 + 0.0);
    final p1y = cy - r * 0.30 * math.cos(a * 0.3 + 0.5);
    canvas.drawCircle(
      Offset(p1x, p1y),
      r * 0.48,
      Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.52)
        ..color = const Color(
          0xFF7B4FD8,
        ).withOpacity(speaking ? 0.55 + 0.10 * breathe : 0.32),
    );

    // Petal 2 — bottom left
    final p2x = cx - r * 0.35 * math.cos(a * 0.35 + 1.5);
    final p2y = cy + r * 0.32 * math.sin(a * 0.28 + 2.0);
    canvas.drawCircle(
      Offset(p2x, p2y),
      r * 0.45,
      Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.48)
        ..color = const Color(
          0xFF6040C8,
        ).withOpacity(speaking ? 0.50 + 0.08 * breathe : 0.28),
    );

    // Petal 3 — top left
    final p3x = cx - r * 0.28 * math.sin(a * 0.45 + 3.0);
    final p3y = cy - r * 0.25 * math.cos(a * 0.38 + 1.2);
    canvas.drawCircle(
      Offset(p3x, p3y),
      r * 0.40,
      Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.44)
        ..color = const Color(
          0xFF8A5CE8,
        ).withOpacity(speaking ? 0.45 + 0.10 * breathe : 0.25),
    );

    // Petal 4 — bottom right
    final p4x = cx + r * 0.30 * math.cos(a * 0.32 + 4.2);
    final p4y = cy + r * 0.28 * math.sin(a * 0.40 + 3.8);
    canvas.drawCircle(
      Offset(p4x, p4y),
      r * 0.42,
      Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.46)
        ..color = const Color(
          0xFF5030B8,
        ).withOpacity(speaking ? 0.42 + 0.08 * breathe : 0.22),
    );

    // Mint accent
    final mx = cx + r * 0.20 * math.sin(a * 0.22 + 5.0);
    final my = cy - r * 0.18 * math.cos(a * 0.18 + 4.5);
    canvas.drawCircle(
      Offset(mx, my),
      r * 0.35,
      Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.40)
        ..color = const Color(
          0xFF3DD68C,
        ).withOpacity(speaking ? 0.18 + 0.07 * breathe : 0.06),
    );

    // Rose — speaking only
    if (speaking) {
      final rx = cx + r * 0.15 * math.cos(a * 0.50 + 2.5);
      final ry = cy + r * 0.20 * math.sin(a * 0.42 + 1.8);
      canvas.drawCircle(
        Offset(rx, ry),
        r * 0.30,
        Paint()
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35)
          ..color = const Color(0xFFFF6B8A).withOpacity(0.14 + 0.06 * breathe),
      );
    }

    // Bright white core — creates illusion of light source
    canvas.drawCircle(
      Offset(cx - r * 0.06, cy - r * 0.08),
      r * 0.18,
      Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.22)
        ..color = Colors.white.withOpacity(
          speaking ? 0.28 + 0.08 * breathe : 0.14,
        ),
    );
  }

  @override
  bool shouldRepaint(_CrystalOrbPainter old) =>
      old.t != t || old.breathe != breathe || old.speaking != speaking;
}

class _AuroraBgPainter extends CustomPainter {
  final double t;
  final double breathe;
  final bool speaking;

  _AuroraBgPainter(this.t, this.breathe, this.speaking);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF05040D),
    );

    final cx = size.width / 2;

    canvas.drawCircle(
      Offset(cx, size.height * 0.26),
      size.width * 0.65,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90)
        ..color = const Color(
          0xFF4A20A0,
        ).withOpacity(speaking ? 0.22 + 0.07 * breathe : 0.08 + 0.02 * breathe),
    );

    canvas.drawCircle(
      Offset(cx * 0.55, size.height * 0.20),
      size.width * 0.35,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70)
        ..color = const Color(
          0xFF3518A0,
        ).withOpacity(speaking ? 0.12 + 0.04 * breathe : 0.04),
    );

    if (speaking) {
      canvas.drawCircle(
        Offset(cx, size.height * 0.90),
        size.width * 0.45,
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70)
          ..color = const Color(0xFF6040C0).withOpacity(0.08 + 0.04 * breathe),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraBgPainter old) =>
      old.t != t || old.breathe != breathe || old.speaking != speaking;
}
