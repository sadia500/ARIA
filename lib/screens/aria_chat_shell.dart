// lib/screens/aria_chat_shell.dart
// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'AI_chat_screen.dart';

const Color _bg = Color(0xFF0E0B1E);
const Color _glass = Color(0x14FFFFFF);
const Color _glassBorder = Color(0x28FFFFFF);
const Color _violet = Color(0xFF8A6CD1);
const Color _violetGlow = Color(0xFF4D3385);
const Color _rose = Color(0xFFFF6B8A);

class AriaChatShell extends StatefulWidget {
  const AriaChatShell({super.key});

  @override
  State<AriaChatShell> createState() => _AriaChatShellState();
}

class _AriaChatShellState extends State<AriaChatShell>
    with SingleTickerProviderStateMixin {
  String? _activeChatId;
  String? _pendingMessage; // message to send after chat is created
  bool _drawerOpen = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  late final AnimationController _drawerCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final Animation<double> _drawerAnim = CurvedAnimation(
    parent: _drawerCtrl,
    curve: Curves.easeOutCubic,
  );

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference? get _chatsRef {
    if (_uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('chats');
  }

  void _openDrawer() {
    HapticFeedback.lightImpact();
    setState(() => _drawerOpen = true);
    _drawerCtrl.forward();
  }

  void _closeDrawer() {
    _drawerCtrl.reverse().then((_) {
      if (mounted) setState(() => _drawerOpen = false);
    });
  }

  Future<String> _createNewChat({String title = 'New Chat'}) async {
    final ref = await _chatsRef!.add({
      'title': title,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'preview': '',
    });
    return ref.id;
  }

  void _selectChat(String chatId) {
    _closeDrawer();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _activeChatId = chatId);
    });
  }

  void _newChat() async {
    final chatId = await _createNewChat();
    _closeDrawer();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _activeChatId = chatId);
    });
  }

  // Called from AriaAIScreen when user taps a suggestion with no chatId
  Future<String> _newChatWithMessage(String message) async {
    final title = message.split(' ').take(5).join(' ');
    final chatId = await _createNewChat(title: title);
    if (mounted) {
      setState(() {
        _activeChatId = chatId;
        _pendingMessage = message;
      });
    }
    return chatId;
  }

  Future<void> _deleteChat(String chatId) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1035),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _glassBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _rose.withOpacity(0.10),
                border: Border.all(color: _rose.withOpacity(0.30)),
              ),
              child: Icon(Icons.delete_outline_rounded, color: _rose, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              'Delete Chat?',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This will permanently delete this conversation.',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withOpacity(0.38),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _glassBorder),
                      ),
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: _rose.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _rose.withOpacity(0.35)),
                      ),
                      child: Center(
                        child: Text(
                          'Delete',
                          style: GoogleFonts.spaceGrotesk(
                            color: _rose,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final msgs = await _chatsRef!.doc(chatId).collection('messages').get();
      for (final m in msgs.docs) await m.reference.delete();
      await _chatsRef!.doc(chatId).delete();
      if (_activeChatId == chatId && mounted) {
        setState(() => _activeChatId = null);
      }
    }
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
    } else if (diff.inDays == 1)
      return 'Yesterday';
    else if (diff.inDays < 7)
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dt.weekday - 1];
    return '${dt.day}/${dt.month}';
  }

  @override
  void dispose() {
    _drawerCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final drawerW = screenW * 0.78;

    return Stack(
      children: [
        // Main chat — ValueKey forces full rebuild on chat change
        AriaAIScreen(
          key: ValueKey(_activeChatId ?? 'new'),
          chatId: _activeChatId,
          initialMessage: _pendingMessage,
          onOpenDrawer: _openDrawer,
          onNewChatWithMessage: _newChatWithMessage,
          onInitialMessageConsumed: () {
            if (mounted) setState(() => _pendingMessage = null);
          },
        ),

        // Scrim
        if (_drawerOpen)
          AnimatedBuilder(
            animation: _drawerAnim,
            builder: (_, __) => GestureDetector(
              onTap: _closeDrawer,
              child: Container(
                color: Colors.black.withOpacity(0.55 * _drawerAnim.value),
              ),
            ),
          ),

        // Drawer
        if (_drawerOpen)
          AnimatedBuilder(
            animation: _drawerAnim,
            builder: (_, __) => Positioned(
              left: -drawerW * (1 - _drawerAnim.value),
              top: 0,
              bottom: 0,
              width: drawerW,
              child: _buildDrawer(),
            ),
          ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Container(
      color: _bg,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DrawerNebula())),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 1, color: Colors.white.withOpacity(0.05)),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildDrawerHeader(),
                _buildDrawerSearch(),
                Expanded(child: _buildDrawerChatList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
    child: Row(
      children: [
        ClipOval(
          child: Image.asset(
            'assets/aria_logo.png',
            width: 26,
            height: 26,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'ARIA',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white.withOpacity(0.80),
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: _newChat,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _violet.withOpacity(0.12),
              border: Border.all(color: _violet.withOpacity(0.30)),
            ),
            child: const Icon(Icons.add_rounded, color: _violet, size: 16),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _closeDrawer,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _glass,
              border: Border.all(color: _glassBorder),
            ),
            child: Icon(
              Icons.close_rounded,
              color: Colors.white.withOpacity(0.35),
              size: 15,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildDrawerSearch() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Container(
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: _glass,
        border: Border.all(color: _glassBorder),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          hintText: 'Search chats...',
          hintStyle: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.20),
            fontSize: 12,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.white.withOpacity(0.20),
            size: 15,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
      ),
    ),
  );

  Widget _buildDrawerChatList() {
    if (_chatsRef == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _chatsRef!.orderBy('updatedAt', descending: true).snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _violet, strokeWidth: 1.2),
          );
        }

        var docs = snap.data?.docs ?? [];

        if (_searchQuery.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final title = (data['title'] as String? ?? '').toLowerCase();
            final preview = (data['preview'] as String? ?? '').toLowerCase();
            return title.contains(_searchQuery) ||
                preview.contains(_searchQuery);
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(
            child: Text(
              _searchQuery.isNotEmpty
                  ? 'No chats found'
                  : 'No conversations yet\nTap + to start',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withOpacity(0.22),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        final today = <QueryDocumentSnapshot>[];
        final yesterday = <QueryDocumentSnapshot>[];
        final older = <QueryDocumentSnapshot>[];
        final now = DateTime.now();

        for (final d in docs) {
          final data = d.data() as Map<String, dynamic>;
          final ts = data['updatedAt'] as Timestamp?;
          if (ts == null) {
            older.add(d);
            continue;
          }
          final diff = now.difference(ts.toDate()).inDays;
          if (diff == 0)
            today.add(d);
          else if (diff == 1)
            yesterday.add(d);
          else
            older.add(d);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 20),
          children: [
            if (today.isNotEmpty) ...[
              _sectionLabel('Today'),
              ...today.map(_buildDrawerTile),
            ],
            if (yesterday.isNotEmpty) ...[
              _sectionLabel('Yesterday'),
              ...yesterday.map(_buildDrawerTile),
            ],
            if (older.isNotEmpty) ...[
              _sectionLabel('Earlier'),
              ...older.map(_buildDrawerTile),
            ],
          ],
        );
      },
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 12, 8, 3),
    child: Text(
      label,
      style: GoogleFonts.spaceGrotesk(
        color: Colors.white.withOpacity(0.20),
        fontSize: 9,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _buildDrawerTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final chatId = doc.id;
    final title = data['title'] as String? ?? 'New Chat';
    final preview = data['preview'] as String? ?? '';
    final ts = data['updatedAt'] as Timestamp?;
    final isActive = chatId == _activeChatId;

    return GestureDetector(
      onTap: () => _selectChat(chatId),
      onLongPress: () => _deleteChat(chatId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isActive ? _violet.withOpacity(0.12) : Colors.transparent,
          border: Border.all(
            color: isActive ? _violet.withOpacity(0.25) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withOpacity(0.70),
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.25),
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _formatTime(ts),
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withOpacity(0.16),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerNebula extends CustomPainter {
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

    final b1 = Offset(cx * 0.3, cy * 0.4 + 22);
    canvas.drawCircle(
      b1,
      size.width * 0.75,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0x458A6CD1), const Color(0x008A6CD1)],
        ).createShader(Rect.fromCircle(center: b1, radius: size.width * 0.75)),
    );

    final b2 = Offset(cx * 1.65 - 22, cy * 0.85);
    canvas.drawCircle(
      b2,
      size.width * 0.60,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0x386B4DA8), const Color(0x006B4DA8)],
        ).createShader(Rect.fromCircle(center: b2, radius: size.width * 0.60)),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
