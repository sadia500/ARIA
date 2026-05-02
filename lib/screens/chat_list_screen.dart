// lib/screens/chat_list_screen.dart
// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'AI_chat_screen.dart';

const Color _bg          = Color(0xFF0E0B1E);
const Color _glass       = Color(0x14FFFFFF);
const Color _glassBorder = Color(0x28FFFFFF);
const Color _violet      = Color(0xFF8A6CD1);
const Color _violetGlow  = Color(0xFF4D3385);
const Color _mint        = Color(0xFF3DD68C);
const Color _rose        = Color(0xFFFF6B8A);
const Color _cardBg      = Color(0xFF13102A);

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {

  late final AnimationController _enterCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 700),
  )..forward();
  late final Animation<double> _enter = CurvedAnimation(
    parent: _enterCtrl, curve: Curves.easeOutCubic,
  );

  bool   _searchMode  = false;
  String _searchQuery = '';
  final  _searchCtrl  = TextEditingController();
  final  _searchFocus = FocusNode();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference? get _chatsRef {
    if (_uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users').doc(_uid).collection('chats');
  }

  Future<void> _deleteChat(String chatId) async {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Container(width: 52, height: 52,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _rose.withOpacity(0.10), border: Border.all(color: _rose.withOpacity(0.30))),
            child: Icon(Icons.delete_outline_rounded, color: _rose, size: 24)),
          const SizedBox(height: 14),
          Text('Delete Chat?', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('This conversation will be permanently deleted.',
            style: GoogleFonts.spaceGrotesk(color: Colors.white.withOpacity(0.40), fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(height: 50,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: _glassBorder)),
                child: Center(child: Text('Cancel', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)))),
            )),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                final msgs = await _chatsRef!.doc(chatId).collection('messages').get();
                for (final m in msgs.docs) await m.reference.delete();
                await _chatsRef!.doc(chatId).delete();
              },
              child: Container(height: 50,
                decoration: BoxDecoration(color: _rose.withOpacity(0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: _rose.withOpacity(0.40))),
                child: Center(child: Text('Delete', style: GoogleFonts.spaceGrotesk(color: _rose, fontSize: 14, fontWeight: FontWeight.w600)))),
            )),
          ]),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
        ]),
      ),
    );
  }

  Future<String> _createNewChat() async {
    final ref = await _chatsRef!.add({
      'title': 'New Chat',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'preview': '',
    });
    return ref.id;
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt  = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
    } else if (diff.inDays == 1) return 'Yesterday';
    else if (diff.inDays < 7) return ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][dt.weekday - 1];
    return '${dt.day}/${dt.month}';
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [
        // Background gradient
        Container(decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1A1035), Color(0xFF0E0B1E), Color(0xFF160E2E)],
        ))),

        // Nebula blobs
        CustomPaint(painter: _NebulaPainter(), child: const SizedBox.expand()),

        SafeArea(
          child: FadeTransition(
            opacity: _enter,
            child: Column(children: [
              _buildTopBar(),
              if (_searchMode) _buildSearchBar(),
              Expanded(child: _buildChatList()),
            ]),
          ),
        ),
      ]),

      floatingActionButton: GestureDetector(
        onTap: () async {
          HapticFeedback.mediumImpact();
          final chatId = await _createNewChat();
          if (!mounted) return;
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => AriaAIScreen(chatId: chatId),
          ));
        },
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [_violet, _violetGlow], begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [BoxShadow(color: _violet.withOpacity(0.45), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }

  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Chats', style: GoogleFonts.spaceGrotesk(
            color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5,
          )),
          Text('with ARIA', style: GoogleFonts.spaceGrotesk(
            color: Colors.white.withOpacity(0.30), fontSize: 12,
          )),
        ]),
        // Search icon only — no redundant new chat button
        GestureDetector(
          onTap: () {
            setState(() => _searchMode = !_searchMode);
            if (_searchMode) {
              Future.delayed(const Duration(milliseconds: 100), () => _searchFocus.requestFocus());
            } else {
              _searchCtrl.clear();
              _searchQuery = '';
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _searchMode ? _violet.withOpacity(0.20) : Colors.white.withOpacity(0.06),
              border: Border.all(color: _searchMode ? _violet.withOpacity(0.50) : Colors.white.withOpacity(0.10)),
            ),
            child: Icon(
              _searchMode ? Icons.close_rounded : Icons.search_rounded,
              color: _searchMode ? _violet : Colors.white.withOpacity(0.45),
              size: 18,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.07),
        border: Border.all(color: _violet.withOpacity(0.35)),
      ),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search conversations...',
          hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.25), fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: _violet.withOpacity(0.60), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
      ),
    ),
  );

  Widget _buildChatList() {
    if (_chatsRef == null) {
      return Center(child: Text('Not signed in', style: GoogleFonts.spaceGrotesk(color: Colors.white38)));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _chatsRef!.orderBy('updatedAt', descending: true).snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _violet, strokeWidth: 1.5));
        }

        var docs = snap.data?.docs ?? [];

        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          docs = docs.where((d) {
            final data    = d.data() as Map<String, dynamic>;
            final title   = (data['title'] as String? ?? '').toLowerCase();
            final preview = (data['preview'] as String? ?? '').toLowerCase();
            return title.contains(_searchQuery) || preview.contains(_searchQuery);
          }).toList();
        }

        if (docs.isEmpty) {
          return _searchQuery.isNotEmpty ? _buildNoResults() : _buildEmptyState();
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc     = docs[i];
            final data    = doc.data() as Map<String, dynamic>;
            final chatId  = doc.id;
            final title   = data['title'] as String? ?? 'New Chat';
            final preview = data['preview'] as String? ?? '';
            final ts      = data['updatedAt'] as Timestamp?;

            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 300 + i * 60),
              curve: Curves.easeOutCubic,
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
              ),
              child: _buildChatTile(chatId, title, preview, ts),
            );
          },
        );
      },
    );
  }

  Widget _buildChatTile(String chatId, String title, String preview, Timestamp? ts) {
    final isNew = title == 'New Chat' && preview.isEmpty;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => AriaAIScreen(chatId: chatId),
      )),
      onLongPress: () => _deleteChat(chatId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            // Avatar
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _violet.withOpacity(0.40),
                  _violetGlow.withOpacity(0.25),
                ]),
                border: Border.all(color: _violet.withOpacity(0.25)),
              ),
              child: ClipOval(child: Image.asset('assets/aria_logo.png', fit: BoxFit.cover)),
            ),
            const SizedBox(width: 14),

            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    color: isNew ? Colors.white.withOpacity(0.40) : Colors.white,
                    fontSize: 14, fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                )),
                const SizedBox(width: 8),
                Text(_formatTime(ts), style: GoogleFonts.spaceGrotesk(
                  color: Colors.white.withOpacity(0.22), fontSize: 10,
                )),
              ]),
              const SizedBox(height: 4),
              Text(
                preview.isEmpty ? 'Tap to start chatting' : preview,
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(preview.isEmpty ? 0.18 : 0.40),
                  fontSize: 12, height: 1.4,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ])),

            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.15), size: 16),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _violet.withOpacity(0.08),
          border: Border.all(color: _violet.withOpacity(0.18)),
        ),
        child: ClipOval(child: Image.asset('assets/aria_logo.png', fit: BoxFit.cover)),
      ),
      const SizedBox(height: 20),
      Text('No conversations yet', style: GoogleFonts.spaceGrotesk(
        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700,
      )),
      const SizedBox(height: 8),
      Text('Tap + to start chatting with ARIA', style: GoogleFonts.spaceGrotesk(
        color: Colors.white.withOpacity(0.30), fontSize: 13,
      )),
    ]),
  );

  Widget _buildNoResults() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.search_off_rounded, color: Colors.white.withOpacity(0.15), size: 44),
      const SizedBox(height: 14),
      Text('No chats found', style: GoogleFonts.spaceGrotesk(
        color: Colors.white.withOpacity(0.50), fontSize: 16, fontWeight: FontWeight.w600,
      )),
      const SizedBox(height: 6),
      Text('Try a different search term', style: GoogleFonts.spaceGrotesk(
        color: Colors.white.withOpacity(0.25), fontSize: 12,
      )),
    ]),
  );
}

// ── Subtle nebula background ──────────────────────────────────────────────────
class _NebulaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.20),
      size.width * 0.55,
      Paint()..shader = RadialGradient(colors: [
        const Color(0xFF8A6CD1).withOpacity(0.10),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: Offset(size.width * 0.15, size.height * 0.20), radius: size.width * 0.55)),
    );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.70),
      size.width * 0.45,
      Paint()..shader = RadialGradient(colors: [
        const Color(0xFF4D3385).withOpacity(0.12),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: Offset(size.width * 0.85, size.height * 0.70), radius: size.width * 0.45)),
    );
  }
  @override
  bool shouldRepaint(_) => false;
}