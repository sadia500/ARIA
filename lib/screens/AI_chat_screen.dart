// ignore_for_file: unnecessary_underscores, curly_braces_in_flow_control_structures, avoid_print, unused_element, unused_field, file_names, deprecated_member_use
import '../services/aria_ai_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/storage_service.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'schedule_screen.dart';
import 'dart:convert';
import '../services/firestore_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const Color _bg = Color(0xFF0E0B1E);
const Color _glass = Color(0x14FFFFFF);
const Color _glassBorder = Color(0x28FFFFFF);
const Color _violet = Color(0xFF8A6CD1);
const Color _violetGlow = Color(0xFF4D3385);
const Color _mint = Color(0xFF3DD68C);
const Color _rose = Color(0xFFFF6B8A);

class AriaAIScreen extends StatefulWidget {
  final String? initialMessage;
  final String? chatId;
  final VoidCallback? onOpenDrawer;
  final Future<String> Function(String)? onNewChatWithMessage;
  final VoidCallback? onInitialMessageConsumed;
  const AriaAIScreen({
    super.key,
    this.initialMessage,
    this.chatId,
    this.onOpenDrawer,
    this.onNewChatWithMessage, // ← ADD THIS
    this.onInitialMessageConsumed,
  });

  @override
  State<AriaAIScreen> createState() => _AriaAIScreenState();
}

class _AriaAIScreenState extends State<AriaAIScreen>
    with TickerProviderStateMixin {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  final AriaAIService _aiService = AriaAIService();
  String? _profileImageUrl;
  bool _initialMessageSent = false;

  bool _isTyping = false;
  bool _isThinking = false;
  bool _showScrollBtn = false;
  bool _isLoadingHistory = false;

  String? _localChatId;

  // ── Firestore ─────────────────────────────────────────────────────────────
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  bool get _hasChatId =>
      (widget.chatId != null || _localChatId != null) && _uid != null;

  CollectionReference? get _msgsRef {
    final chatId = widget.chatId ?? _localChatId;
    if (chatId == null || _uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages');
  }

  DocumentReference? get _chatRef {
    final chatId = widget.chatId ?? _localChatId;
    if (chatId == null || _uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('chats')
        .doc(widget.chatId);
  }

  // ── Speech & TTS ──────────────────────────────────────────────────────────
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _speechAvailable = false;
  bool _voiceMode = false;
  bool _micActive = false;
  bool _isSpeaking = false;
  bool _ttsEnabled = true;
  String _voiceText = '';

  // ── Search ────────────────────────────────────────────────────────────────
  bool _searchMode = false;
  String _searchQuery = '';
  final _searchQueryCtrl = TextEditingController();

  // ── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _nebulaCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat(reverse: true);
  late final AnimationController _breathCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);
  late final AnimationController _dotCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();
  late final AnimationController _micCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..repeat(reverse: true);

  late final Animation<double> _nebula = CurvedAnimation(
    parent: _nebulaCtrl,
    curve: Curves.easeInOut,
  );
  late final Animation<double> _breath = CurvedAnimation(
    parent: _breathCtrl,
    curve: Curves.easeInOut,
  );

  static const _suggestions = [
    ('🧩', 'Help me solve a problem I\'m stuck on'),
    ('📝', 'Summarize something for me'),
    ('🎯', 'Help me set a goal and make a plan'),
  ];

  final List<_Msg> _msgs = [];
  final Map<int, bool?> _feedback = {};

  // ── Title editing ─────────────────────────────────────────────────────────
  String _chatTitle = 'New Chat';
  bool _titleGenerated = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _initSpeechAndTts();
    _loadProfileImage();

    if (_hasChatId) {
      _loadHistory();
    }
    final VoidCallback? onInitialMessageConsumed;

    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        if (_initialMessageSent) return; // ← ADD THIS
        _initialMessageSent = true; // ← ADD THIS
        _send(widget.initialMessage!);
        widget.onInitialMessageConsumed?.call();
      });
    }
    print('INITIAL MESSAGE TRIGGER: ${widget.initialMessage}');
  }

  void _loadProfileImage() {
    _profileImageUrl = StorageService.instance.loadProfileImageUrl();
    FirestoreService.instance.loadProfileImage().then((url) {
      if (url != null && mounted) {
        setState(() => _profileImageUrl = url);
        StorageService.instance.saveProfileImageUrl(url);
      }
    });
  }

  Future<void> _loadHistory() async {
    if (_msgsRef == null) return;
    if (_msgs.isNotEmpty) return;

    // If initialMessage exists this is a brand new chat — skip loading history
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty)
      return;
    setState(() => _isLoadingHistory = true);

    try {
      // Load chat title
      final chatSnap = await _chatRef!.get();
      if (chatSnap.exists) {
        final data = chatSnap.data() as Map<String, dynamic>;
        _chatTitle = data['title'] as String? ?? 'New Chat';
        if (_chatTitle != 'New Chat') _titleGenerated = true;
      }

      // Load messages ordered by time
      final snap = await _msgsRef!
          .orderBy('timestamp', descending: false)
          .get();

      final loaded = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        final isAria = data['isAria'] as bool? ?? false;
        final text = data['text'] as String? ?? '';
        final time = data['time'] as String? ?? '';
        return isAria
            ? _Msg.aria(text, time, showSender: true)
            : _Msg.user(text, time);
      }).toList();

      if (mounted) {
        setState(() {
          _msgs.addAll(loaded);
          _isLoadingHistory = false;
        });
        // Restore history to AI service
        for (final m in loaded) {
          if (!m.isDivider && !m.isCard) {
            _aiService.restoreMessage(m.text, m.isAria);
          }
        }
        _scrollLater();
      }
    } catch (e) {
      print('History load error: $e');
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _saveMessage(_Msg msg) async {
    if (_msgsRef == null) return;
    try {
      await _msgsRef!.add({
        'isAria': msg.isAria,
        'text': msg.text,
        'time': msg.time,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update chat preview + updatedAt
      await _chatRef!.update({
        'preview': msg.text.length > 80
            ? '${msg.text.substring(0, 80)}...'
            : msg.text,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Save message error: $e');
    }
  }

  Future<void> _generateTitle(String firstUserMsg) async {
    if (_titleGenerated || _chatRef == null) return;
    _titleGenerated = true;
    try {
      // Use first user message to generate a short title
      final title = firstUserMsg.length > 40
          ? firstUserMsg.substring(0, 40)
          : firstUserMsg;
      final shortTitle = title.split(' ').take(5).join(' ');
      await _chatRef!.update({'title': shortTitle});
      if (mounted) setState(() => _chatTitle = shortTitle);
    } catch (e) {
      print('Title gen error: $e');
    }
  }

  // ── Init speech + TTS ─────────────────────────────────────────────────────
  Future<void> _initSpeechAndTts() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) {
        if (mounted) setState(() => _micActive = false);
      },
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') &&
            _voiceMode &&
            !_isThinking &&
            !_isSpeaking &&
            mounted) {
          if (_voiceText.isEmpty) {
            Future.delayed(const Duration(milliseconds: 400), _startListening);
          }
        }
      },
    );

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
      if (_voiceMode && !_isThinking) {
        Future.delayed(const Duration(milliseconds: 600), _startListening);
      }
    });

    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final atBottom =
        _scrollCtrl.position.maxScrollExtent - _scrollCtrl.offset < 100;
    if (atBottom != !_showScrollBtn) setState(() => _showScrollBtn = !atBottom);
  }

  // ── Voice mode ────────────────────────────────────────────────────────────
  Future<void> _toggleVoiceMode() async {
    HapticFeedback.mediumImpact();
    if (!_speechAvailable) {
      _toast('Microphone not available');
      return;
    }
    if (_voiceMode) {
      await _stopVoiceMode();
    } else {
      setState(() => _voiceMode = true);
      _toast('Voice mode on 🎤');
      await Future.delayed(const Duration(milliseconds: 600));
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!mounted || !_voiceMode || !_speechAvailable) return;
    if (_isThinking || _isSpeaking) return;
    await _speech.stop();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted || !_voiceMode) return;
    setState(() {
      _micActive = true;
      _voiceText = '';
      _inputCtrl.clear();
      _isTyping = false;
    });
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _voiceText = result.recognizedWords;
          _inputCtrl.text = _voiceText;
          _isTyping = _voiceText.isNotEmpty;
        });
        if (result.finalResult && _voiceText.trim().isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_voiceText.trim().isNotEmpty) _autoSendVoice(_voiceText.trim());
          });
        }
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
      cancelOnError: false,
      partialResults: true,
    );
  }

  Future<void> _autoSendVoice(String text) async {
    if (!mounted || text.isEmpty) return;
    await _speech.stop();
    setState(() {
      _micActive = false;
      _voiceText = '';
      _inputCtrl.clear();
      _isTyping = false;
    });
    HapticFeedback.lightImpact();
    final userMsg = _Msg.user(text, _now());
    setState(() {
      _msgs.add(userMsg);
      _isThinking = true;
    });
    await _saveMessage(userMsg);
    if (!_titleGenerated) await _generateTitle(text);
    _scrollLater();
    final reply = await _aiService.sendMessage(
      text,
      onTaskCreate: _handleTaskCreate,
    );
    if (!mounted) return;
    final ariaMsg = _Msg.aria(reply, _now(), showSender: true);
    setState(() {
      _isThinking = false;
      _msgs.add(ariaMsg);
    });
    await _saveMessage(ariaMsg);
    _scrollLater();
    if (_voiceMode) {
      if (_ttsEnabled)
        await _speakThenListen(reply);
      else {
        await Future.delayed(const Duration(milliseconds: 400));
        await _startListening();
      }
    }
  }

  Future<void> _speakThenListen(String text) async {
    if (!mounted) return;
    await _speech.stop();
    setState(() {
      _isSpeaking = true;
      _micActive = false;
      _voiceText = '';
      _inputCtrl.clear();
      _isTyping = false;
    });
    await _tts.speak(text);
  }

  Future<void> _stopVoiceMode() async {
    await _speech.stop();
    await _tts.stop();
    if (!mounted) return;
    setState(() {
      _voiceMode = false;
      _micActive = false;
      _isSpeaking = false;
      _voiceText = '';
      _inputCtrl.clear();
      _isTyping = false;
    });
    _toast('Voice mode off');
  }

  // ── Task create handler ───────────────────────────────────────────────────
  Future<void> _handleTaskCreate(Map<String, dynamic> taskData) async {
    final dateParts = (taskData['date'] as String).split('-');
    final taskDate = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );
    await TaskStore.add(
      ARIATask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: taskData['title'] ?? 'New Task',
        subtitle: 'Added by ARIA',
        startTime: taskData['startTime'] ?? '9:00 AM',
        endTime: taskData['endTime'] ?? '10:00 AM',
        priority: TaskPriority.values.firstWhere(
          (p) => p.name == (taskData['priority'] ?? 'medium'),
          orElse: () => TaskPriority.medium,
        ),
        category: TaskCategory.values.firstWhere(
          (c) => c.name == (taskData['category'] ?? 'work'),
          orElse: () => TaskCategory.work,
        ),
        date: taskDate,
      ),
    );
    HapticFeedback.mediumImpact();
  }

  // ── Text send ─────────────────────────────────────────────────────────────
  void _send([String? prefilled]) async {
    final text = prefilled ?? _inputCtrl.text.trim();
    print('SEND CALLED: $text');
    print(StackTrace.current);
    if (text.isEmpty) return;
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();

    // Auto-create chat on first message if no chatId
    if (widget.chatId == null && _localChatId == null && _uid != null) {
      try {
        final ref = await FirebaseFirestore.instance
            .collection('users')
            .doc(_uid!)
            .collection('chats')
            .add({
              'title': text.split(' ').take(5).join(' '),
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
              'preview': '',
            });
        if (!mounted) return;
        setState(() => _localChatId = ref.id);
      } catch (e) {
        debugPrint('Chat create error: $e');
      }
    }

    if (!mounted) return;

    final userMsg = _Msg.user(text, _now());
    setState(() {
      _msgs.add(userMsg);
      _inputCtrl.clear();
      _isTyping = false;
      _isThinking = true;
    });
    await _saveMessage(userMsg);
    if (!mounted) return;

    if (!_titleGenerated) await _generateTitle(text);
    _scrollLater();
    final reply = await _aiService.sendMessage(
      text,
      onTaskCreate: _handleTaskCreate,
    );
    if (!mounted) return;
    final ariaMsg = _Msg.aria(reply, _now(), showSender: true);
    setState(() {
      _isThinking = false;
      _msgs.add(ariaMsg);
    });
    await _saveMessage(ariaMsg);
    _scrollLater();
    if (_ttsEnabled && _voiceMode) await _speakThenListen(reply);
  }

  void _regenerate() async {
    if (_msgs.isEmpty || _isThinking) return;
    String? lastUserMsg;
    for (int i = _msgs.length - 1; i >= 0; i--) {
      if (!_msgs[i].isAria && !_msgs[i].isDivider) {
        lastUserMsg = _msgs[i].text;
        break;
      }
    }
    if (lastUserMsg == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      if (_msgs.isNotEmpty && _msgs.last.isAria) _msgs.removeLast();
      _isThinking = true;
    });
    _aiService.clearHistory();
    final reply = await _aiService.sendMessage(lastUserMsg);
    if (!mounted) return;

    final ariaMsg = _Msg.aria(reply, _now(), showSender: true);
    setState(() {
      _isThinking = false;
      _msgs.add(ariaMsg);
    });
    await _saveMessage(ariaMsg);
    if (!mounted) return;

    _scrollLater();
    if (_ttsEnabled && _voiceMode) await _speakThenListen(reply);
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1035),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clear Chat',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Delete all messages in this conversation?',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.spaceGrotesk(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _msgs.clear();
                _feedback.clear();
              });
              _aiService.clearHistory();
              // Delete from Firestore
              if (_msgsRef != null) {
                final snap = await _msgsRef!.get();
                for (final d in snap.docs) await d.reference.delete();
                await _chatRef?.update({
                  'preview': '',
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              }
              _toast('Chat cleared');
            },
            child: Text(
              'Clear',
              style: GoogleFonts.spaceGrotesk(
                color: _rose,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    _toast('Copied ✓');
  }

  void _shareMessage(String text) {
    Clipboard.setData(ClipboardData(text: 'ARIA says:\n\n$text'));
    HapticFeedback.lightImpact();
    _toast('Copied to share ✓');
  }

  void _giveFeedback(int idx, bool liked) {
    HapticFeedback.lightImpact();
    setState(() => _feedback[idx] = liked);
    _toast(liked ? 'Thanks! 👍' : 'We\'ll improve that 👎');
  }

  void _showMessageOptions(_Msg msg, int index) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1035),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _violet.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _optionTile(Icons.copy_rounded, 'Copy message', _violet, () {
              Navigator.pop(context);
              _copyMessage(msg.text);
            }),
            _optionTile(Icons.share_rounded, 'Share message', _mint, () {
              Navigator.pop(context);
              _shareMessage(msg.text);
            }),
            if (msg.isAria) ...[
              _optionTile(
                Icons.refresh_rounded,
                'Regenerate',
                const Color(0xFFFFB347),
                () {
                  Navigator.pop(context);
                  _regenerate();
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _feedbackBtn(
                      Icons.thumb_up_rounded,
                      'Helpful',
                      _feedback[index] == true ? _mint : Colors.white24,
                      () {
                        Navigator.pop(context);
                        _giveFeedback(index, true);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _feedbackBtn(
                      Icons.thumb_down_rounded,
                      'Not helpful',
                      _feedback[index] == false ? _rose : Colors.white24,
                      () {
                        Navigator.pop(context);
                        _giveFeedback(index, false);
                      },
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _optionTile(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedbackBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTextChanged(String v) => setState(() => _isTyping = v.isNotEmpty);

  void _scrollLater() => Future.delayed(const Duration(milliseconds: 120), () {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  });

  void _scrollToBottom() {
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: const Color(0xFF1A1535),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _now() {
    final n = DateTime.now();
    final h = n.hour % 12 == 0 ? 12 : n.hour % 12;
    final m = n.minute.toString().padLeft(2, '0');
    return '$h:$m ${n.hour >= 12 ? 'PM' : 'AM'}';
  }

  bool get _hasMessages => _msgs.any((m) => !m.isDivider);

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _searchQueryCtrl.dispose();
    _nebulaCtrl.dispose();
    _breathCtrl.dispose();
    _dotCtrl.dispose();
    _micCtrl.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  void _showUserInfo() {
    final user = FirebaseAuth.instance.currentUser;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1035),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _violet.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [_violet, Color(0xFF3A2470)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: _violet.withOpacity(0.5), width: 2),
              ),
              child: Center(
                child: Text(
                  (user?.displayName ?? 'U')[0].toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user?.displayName ?? 'User',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user?.email ?? '',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_violet, _violetGlow],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'Close',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _nebula,
              builder: (_, __) => CustomPaint(
                painter: _NebulaPainter(_nebula.value),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned.fill(child: CustomPaint(painter: _GrainPainter())),
            Column(
              children: [
                SafeArea(bottom: false, child: _buildTopBar()),
                if (!_hasMessages && !_isLoadingHistory) _buildLogoHeader(),
                Expanded(
                  child: Stack(
                    children: [
                      _isLoadingHistory
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: _violet,
                                strokeWidth: 1.5,
                              ),
                            )
                          : _searchMode
                          ? _buildSearchResults()
                          : _hasMessages
                          ? _buildMessageList()
                          : _buildEmptyState(),
                      if (_showScrollBtn && _hasMessages)
                        Positioned(
                          bottom: 12,
                          right: 16,
                          child: GestureDetector(
                            onTap: _scrollToBottom,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _violet.withOpacity(0.9),
                                boxShadow: [
                                  BoxShadow(
                                    color: _violet.withOpacity(0.4),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _buildBottomArea(),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Search results ────────────────────────────────────────────────────────
  Widget _buildSearchResults() {
    final q = _searchQuery.toLowerCase();
    final results = _msgs
        .where(
          (m) => !m.isDivider && !m.isCard && m.text.toLowerCase().contains(q),
        )
        .toList();
    if (_searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_rounded,
              color: Colors.white.withOpacity(0.2),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'Search your conversation',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withOpacity(0.3),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              color: Colors.white.withOpacity(0.2),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'No messages found',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withOpacity(0.3),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      itemCount: results.length,
      itemBuilder: (_, i) {
        final msg = results[i];
        final idx = msg.text.toLowerCase().indexOf(q);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: _glass,
            border: Border.all(
              color: msg.isAria ? _violet.withOpacity(0.3) : _glassBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    msg.isAria
                        ? Icons.auto_awesome_rounded
                        : Icons.person_rounded,
                    color: msg.isAria ? _violet : Colors.white.withOpacity(0.5),
                    size: 12,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    msg.isAria ? 'ARIA' : 'You',
                    style: GoogleFonts.spaceGrotesk(
                      color: msg.isAria
                          ? _violet
                          : Colors.white.withOpacity(0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    msg.time,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white.withOpacity(0.2),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  children: [
                    if (idx > 0)
                      TextSpan(
                        text: msg.text.substring(0, idx),
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    TextSpan(
                      text: msg.text.substring(idx, idx + q.length),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.5,
                        backgroundColor: _violet.withOpacity(0.35),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (idx + q.length < msg.text.length)
                      TextSpan(
                        text: msg.text.substring(idx + q.length),
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _searchMode
              ? Expanded(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _glass,
                      border: Border.all(color: _violet.withOpacity(0.4)),
                    ),
                    child: TextField(
                      controller: _searchQueryCtrl,
                      autofocus: true,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search messages...',
                        hintStyle: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: _violet,
                          size: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                )
              : widget.onOpenDrawer != null
              ? _iconBtn(Icons.menu_rounded, widget.onOpenDrawer!)
              : Navigator.canPop(context)
              ? _iconBtn(
                  Icons.arrow_back_ios_new_rounded,
                  () => Navigator.pop(context),
                )
              : const SizedBox(width: 36),
          if (_searchMode) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() {
                _searchMode = false;
                _searchQuery = '';
                _searchQueryCtrl.clear();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _glass,
                  border: Border.all(color: _glassBorder),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.spaceGrotesk(
                    color: _violet,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                _iconBtn(
                  Icons.search_rounded,
                  () => setState(() => _searchMode = true),
                ),
                const SizedBox(width: 8),
                if (_hasMessages) ...[
                  _iconBtn(Icons.delete_outline_rounded, _clearChat),
                  const SizedBox(width: 8),
                ],
                GestureDetector(
                  onTap: () {
                    setState(() => _ttsEnabled = !_ttsEnabled);
                    if (!_ttsEnabled) _tts.stop();
                    _toast(
                      _ttsEnabled
                          ? '🔊 Voice replies on'
                          : '🔇 Voice replies off',
                    );
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      color: _ttsEnabled ? _violet.withOpacity(0.2) : _glass,
                      border: Border.all(
                        color: _ttsEnabled
                            ? _violet.withOpacity(0.5)
                            : _glassBorder,
                      ),
                    ),
                    child: Icon(
                      _isSpeaking
                          ? Icons.stop_rounded
                          : _ttsEnabled
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      color: _ttsEnabled
                          ? _violet
                          : Colors.white.withOpacity(0.3),
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showUserInfo,
                  child: Stack(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [_violet, Color(0xFF3A2470)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: _violet.withOpacity(0.45),
                            width: 1.5,
                          ),
                        ),
                        child: _profileImageUrl != null
                            ? ClipOval(
                                child: Image.memory(
                                  base64Decode(_profileImageUrl!),
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Text(
                                      'A',
                                      style: GoogleFonts.spaceGrotesk(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  (FirebaseAuth
                                              .instance
                                              .currentUser
                                              ?.displayName ??
                                          'U')[0]
                                      .toUpperCase(),
                                  style: GoogleFonts.spaceGrotesk(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                      ),
                      Positioned(
                        bottom: 1,
                        right: 1,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _mint,
                            border: Border.all(color: _bg, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: _glass,
        border: Border.all(color: _glassBorder),
      ),
      child: Icon(icon, color: Colors.white.withOpacity(0.5), size: 16),
    ),
  );

  Widget _buildLogoHeader() {
    return AnimatedBuilder(
      animation: _breath,
      builder: (_, __) => Column(
        children: [
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _violet.withOpacity(0.3 + 0.15 * _breath.value),
                      _violet.withOpacity(0.08 + 0.06 * _breath.value),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _violet.withOpacity(0.4 + 0.25 * _breath.value),
                      blurRadius: 30 + 15 * _breath.value,
                    ),
                  ],
                ),
              ),
              ClipOval(
                child: Image.asset(
                  'assets/aria_logo.png',
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ARIA AI',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white.withOpacity(0.80),
              fontSize: 12,
              letterSpacing: 3.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Color(0x208A6CD1),
                  Color(0x388A6CD1),
                  Color(0x208A6CD1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final h = DateTime.now().hour;
    final greeting = h < 12
        ? 'Good Morning ☀️'
        : h < 17
        ? 'Good Afternoon 🎯'
        : 'Good Evening 🌙';
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
        child: Column(
          children: [
            Text(
              greeting,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withOpacity(0.9),
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'How can I help you focus today?',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ..._suggestions.map((s) => _buildStartCard(s.$1, s.$2)),
          ],
        ),
      ),
    );
  }

  Widget _buildStartCard(String emoji, String text) {
    return GestureDetector(
      onTap: () async {
        if (!_hasChatId && widget.onNewChatWithMessage != null) {
          await widget.onNewChatWithMessage!(text);
          return;
        }
        _send(text);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _glass,
          border: Border.all(color: _glassBorder),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withOpacity(0.2),
              size: 13,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollCtrl,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: _msgs.length + 1,
      itemBuilder: (_, i) {
        if (i == _msgs.length) {
          return AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _isThinking
                ? _buildTypingIndicator()
                : const SizedBox.shrink(),
          );
        }
        return _buildMsgItem(_msgs[i], i);
      },
    );
  }

  Widget _buildMsgItem(_Msg msg, int index) {
    if (msg.isDivider) return _buildDivider(msg.dividerLabel!);
    if (msg.isCard) return _buildTaskCard(msg.card!);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(msg.isAria ? -12 * (1 - t) : 12 * (1 - t), 0),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: msg.isAria
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (msg.isAria) _ariaMiniAvatar(),
            Flexible(
              child: Column(
                crossAxisAlignment: msg.isAria
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  if (msg.isAria && msg.showSender)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 5),
                      child: Text(
                        'ARIA',
                        style: GoogleFonts.spaceGrotesk(
                          color: _violet.withOpacity(0.55),
                          fontSize: 9,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  GestureDetector(
                    onLongPress: () => _showMessageOptions(msg, index),
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(msg.isAria ? 4 : 20),
                        bottomRight: Radius.circular(msg.isAria ? 20 : 4),
                      ),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(msg.isAria ? 4 : 20),
                              bottomRight: Radius.circular(msg.isAria ? 20 : 4),
                            ),
                            color: msg.isAria
                                ? Colors.white.withOpacity(0.08)
                                : _violet.withOpacity(0.28),
                            border: Border.all(
                              color: Colors.white.withOpacity(
                                msg.isAria ? 0.10 : 0.18,
                              ),
                            ),
                          ),
                          child: Text(
                            msg.text,
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.90),
                              fontSize: 14,
                              height: 1.6,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        msg.time,
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white.withOpacity(0.18),
                          fontSize: 9,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (msg.isAria) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _copyMessage(msg.text),
                          child: Icon(
                            Icons.copy_rounded,
                            color: Colors.white.withOpacity(0.2),
                            size: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (index == _msgs.lastIndexWhere((m) => m.isAria))
                          GestureDetector(
                            onTap: _regenerate,
                            child: Icon(
                              Icons.refresh_rounded,
                              color: Colors.white.withOpacity(0.2),
                              size: 12,
                            ),
                          ),
                        const SizedBox(width: 8),
                        if (_feedback[index] != null)
                          Icon(
                            _feedback[index]!
                                ? Icons.thumb_up_rounded
                                : Icons.thumb_down_rounded,
                            color: _feedback[index]!
                                ? _mint.withOpacity(0.6)
                                : _rose.withOpacity(0.6),
                            size: 11,
                          ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Container(height: 1, color: Colors.white.withOpacity(0.05)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withOpacity(0.2),
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: Container(height: 1, color: Colors.white.withOpacity(0.05)),
          ),
        ],
      ),
    );
  }

  Widget _ariaMiniAvatar() => Container(
    width: 26,
    height: 26,
    margin: const EdgeInsets.only(right: 8, bottom: 20),
    child: ClipOval(
      child: Image.asset(
        'assets/aria_logo.png',
        width: 26,
        height: 26,
        fit: BoxFit.cover,
      ),
    ),
  );

  Widget _buildTaskCard(_TaskSuggestion s) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Transform.scale(
        scale: 0.92 + 0.08 * t,
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _ariaMiniAvatar(),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(20),
                ),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(20),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _violet.withOpacity(0.55),
                          _violetGlow.withOpacity(0.70),
                        ],
                      ),
                      border: Border.all(color: Colors.white.withOpacity(0.14)),
                      boxShadow: [
                        BoxShadow(
                          color: _violet.withOpacity(0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.title,
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.subtitle,
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _ariaMiniAvatar(),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(20),
            ),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(20),
                  ),
                  color: Colors.white.withOpacity(0.08),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: AnimatedBuilder(
                  animation: _dotCtrl,
                  builder: (_, __) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final phase = ((_dotCtrl.value * 3) - i).clamp(0.0, 1.0);
                      final pulse = math.sin(phase * math.pi);
                      return Container(
                        margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                        width: 6,
                        height: 6 + 4 * pulse,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: _violet.withOpacity(0.4 + 0.55 * pulse),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomArea() =>
      Column(mainAxisSize: MainAxisSize.min, children: [_buildInputBar()]);

  Widget _buildInputBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: _isTyping
                            ? Colors.white.withOpacity(0.10)
                            : Colors.white.withOpacity(0.07),
                        border: Border.all(
                          color: _isTyping
                              ? _violet.withOpacity(0.50)
                              : Colors.white.withOpacity(0.12),
                          width: _isTyping ? 1.5 : 1,
                        ),
                        boxShadow: _isTyping
                            ? [
                                BoxShadow(
                                  color: _violet.withOpacity(0.12),
                                  blurRadius: 20,
                                ),
                              ]
                            : [],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _inputCtrl,
                              focusNode: _focusNode,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              onChanged: _onTextChanged,
                              onSubmitted: (_) => _send(),
                              textInputAction: TextInputAction.send,
                              maxLines: null,
                              decoration: InputDecoration(
                                hintText: 'Ask ARIA anything...',
                                hintStyle: GoogleFonts.inter(
                                  color: Colors.white.withOpacity(0.22),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _toggleVoiceMode,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: AnimatedBuilder(
                                animation: _micCtrl,
                                builder: (_, __) {
                                  if (_voiceMode && _isSpeaking)
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.volume_up_rounded,
                                          color: _violet,
                                          size: 18,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Speaking...',
                                          style: GoogleFonts.spaceGrotesk(
                                            color: _violet.withOpacity(0.7),
                                            fontSize: 7,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    );
                                  if (_voiceMode && _micActive)
                                    return SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          TweenAnimationBuilder<double>(
                                            tween: Tween(begin: 0.8, end: 1.3),
                                            duration: const Duration(
                                              milliseconds: 900,
                                            ),
                                            builder: (_, scale, __) =>
                                                Transform.scale(
                                                  scale: scale,
                                                  child: Container(
                                                    width: 36,
                                                    height: 36,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: _rose
                                                            .withOpacity(
                                                              (1.3 - scale) *
                                                                  0.5,
                                                            ),
                                                        width: 1.5,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                          ),
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _rose,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: _rose.withOpacity(0.6),
                                                  blurRadius: 10,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.mic_rounded,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  if (_voiceMode && _isThinking)
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.hourglass_top_rounded,
                                          color: _mint.withOpacity(0.7),
                                          size: 18,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Thinking...',
                                          style: GoogleFonts.spaceGrotesk(
                                            color: _mint.withOpacity(0.7),
                                            fontSize: 7,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    );
                                  if (_voiceMode)
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.mic_rounded,
                                          color: _rose,
                                          size: 18,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Tap to stop',
                                          style: GoogleFonts.spaceGrotesk(
                                            color: _rose.withOpacity(0.7),
                                            fontSize: 7,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    );
                                  return Icon(
                                    _speechAvailable
                                        ? Icons.mic_none_rounded
                                        : Icons.mic_off_rounded,
                                    color: Colors.white.withOpacity(0.25),
                                    size: 20,
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _send,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _isTyping
                            ? LinearGradient(
                                colors: [_violet, _violetGlow],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: _isTyping
                            ? null
                            : Colors.white.withOpacity(0.07),
                        border: _isTyping
                            ? null
                            : Border.all(color: Colors.white.withOpacity(0.12)),
                        boxShadow: _isTyping
                            ? [
                                BoxShadow(
                                  color: _violet.withOpacity(0.5),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: _isTyping
                            ? Colors.white
                            : Colors.white.withOpacity(0.22),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Data models ──────────────────────────────────────────────────────────────
class _Msg {
  final bool isAria, isCard, isDivider, showSender;
  final String text, time;
  final String? dividerLabel;
  final _TaskSuggestion? card;

  const _Msg({
    required this.isAria,
    required this.text,
    required this.time,
    this.isCard = false,
    this.isDivider = false,
    this.showSender = false,
    this.dividerLabel,
    this.card,
  });

  factory _Msg.aria(String t, String time, {bool showSender = false}) =>
      _Msg(isAria: true, text: t, time: time, showSender: showSender);
  factory _Msg.user(String t, String time) =>
      _Msg(isAria: false, text: t, time: time);
  factory _Msg.card(_TaskSuggestion c) =>
      _Msg(isAria: true, text: '', time: c.time, isCard: true, card: c);
  factory _Msg.divider(String label) => _Msg(
    isAria: false,
    text: '',
    time: '',
    isDivider: true,
    dividerLabel: label,
  );
}

class _TaskSuggestion {
  final String badge, title, subtitle, priority, duration, time;
  final Color priorityColor;
  const _TaskSuggestion({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.priority,
    required this.priorityColor,
    required this.duration,
    required this.time,
  });
}

// ─── Painters ─────────────────────────────────────────────────────────────────
class _NebulaPainter extends CustomPainter {
  final double t;
  _NebulaPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1035), Color(0xFF0E0B1E), Color(0xFF160E2E)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawCircle(
      Offset(
        cx * 0.3 + 35 * math.sin(t * math.pi),
        cy * 0.4 + 22 * math.cos(t * math.pi),
      ),
      size.width * 0.75,
      Paint()
        ..shader =
            RadialGradient(
              colors: [const Color(0x458A6CD1), const Color(0x008A6CD1)],
            ).createShader(
              Rect.fromCircle(
                center: Offset(cx * 0.3, cy * 0.4),
                radius: size.width * 0.75,
              ),
            ),
    );
    canvas.drawCircle(
      Offset(
        cx * 1.65 - 22 * math.cos(t * math.pi),
        cy * 0.85 + 18 * math.sin(t * math.pi),
      ),
      size.width * 0.60,
      Paint()
        ..shader =
            RadialGradient(
              colors: [const Color(0x386B4DA8), const Color(0x006B4DA8)],
            ).createShader(
              Rect.fromCircle(
                center: Offset(cx * 1.65, cy * 0.85),
                radius: size.width * 0.60,
              ),
            ),
    );
  }

  @override
  bool shouldRepaint(_NebulaPainter old) => old.t != t;
}

class _GrainPainter extends CustomPainter {
  final _rng = math.Random(42);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.015);
    for (int i = 0; i < 1000; i++) {
      canvas.drawCircle(
        Offset(_rng.nextDouble() * size.width, _rng.nextDouble() * size.height),
        _rng.nextDouble() * 0.7,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_GrainPainter _) => false;
}

class _WaveformPainter extends CustomPainter {
  final double t;
  final Color color;
  _WaveformPainter(this.t, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    const bars = 5;
    final barW = size.width / (bars * 2 - 1);
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barW;
    for (int i = 0; i < bars; i++) {
      final phase = math.sin((t * 2 * math.pi) + i * 0.8);
      final h = size.height * (0.3 + 0.55 * ((phase + 1) / 2));
      final x = i * barW * 2 + barW / 2;
      final cy = size.height / 2;
      canvas.drawLine(Offset(x, cy - h / 2), Offset(x, cy + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.t != t;
}
