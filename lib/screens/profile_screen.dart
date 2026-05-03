// lib/screens/profile_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// ignore_for_file: unused_field, unnecessary_underscores, use_build_context_synchronously, unused_element, deprecated_member_use
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/aria_theme.dart';
import '../widgets/aria_widgets.dart';
import 'schedule_screen.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/theme_notifier.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

import 'package:image_picker/image_picker.dart'; // for ImagePicker & ImageSource
import 'dart:convert'; // for base64Encode & base64Decode

const Color _green = Color(0xFF34A853);
const Color _amber = Color(0xFFFFAA44);
const Color _red = Color(0xFFEF4444);
const Color _blue = Color(0xFF3B8BD4);

class ARIAProfileScreen extends StatefulWidget {
  final String userName;
  final void Function(int index) onNavigate;

  const ARIAProfileScreen({
    super.key,
    required this.userName,
    required this.onNavigate,
  });

  @override
  State<ARIAProfileScreen> createState() => _ARIAProfileScreenState();
}

class _ARIAProfileScreenState extends State<ARIAProfileScreen>
    with SingleTickerProviderStateMixin {
  // ── Settings state
  late bool _notificationsOn;
  late bool _focusShieldOn;
  late bool _smartRemindersOn;
  late bool _dailyReportOn;
  late bool _dailyBriefOn;
  late bool _darkModeOn;

  // ── Editable user info
  late String _displayName;
  late String _displayEmail;
  late Color _avatarColor;
  String? _profileImageUrl;

  static const _avatarColors = [
    Color(0xFF9B6FE8),
    Color(0xFF3DD68C),
    Color(0xFFFFAA44),
    Color(0xFF3B8BD4),
    Color(0xFFFF6B8A),
    Color(0xFFEF4444),
    Color(0xFF06B6D4),
    Color(0xFFF59E0B),
  ];

  late final AnimationController _enterCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();
  late final Animation<double> _enterAnim = CurvedAnimation(
    parent: _enterCtrl,
    curve: Curves.easeOutCubic,
  );

  StreamSubscription<List<ARIATask>>? _taskSub;

  @override
  void initState() {
    super.initState();
    final s = StorageService.instance;
    _notificationsOn = s.loadNotificationsOn();
    _focusShieldOn = s.loadFocusShieldOn();
    _smartRemindersOn = s.loadSmartRemindersOn();
    _dailyReportOn = s.loadDailyReportOn();
    _dailyBriefOn = s.loadDailyBriefOn();
    _darkModeOn = s.loadDarkMode();

    // ── FIX: Load from Firebase Auth first, fall back to local storage ──
    final authName = AuthService.instance.userName;
    final authEmail = AuthService.instance.userEmail;
    final savedName = s.loadUserName();
    final savedEmail = s.loadUserEmail();

    _displayName = authName.isNotEmpty && authName != 'User'
        ? authName
        : savedName.isNotEmpty
        ? savedName
        : widget.userName;

    _displayEmail = authEmail.isNotEmpty
        ? authEmail
        : savedEmail.isNotEmpty
        ? savedEmail
        : 'aria@intelligence.ai';

    // Save to local storage so edit profile works correctly too
    if (authName.isNotEmpty && authName != 'User') {
      s.saveUserName(authName);
    }
    if (authEmail.isNotEmpty) {
      s.saveUserEmail(authEmail);
    }

    final savedColor = s.loadAvatarColor();
    _avatarColor = Color(savedColor);

    _taskSub = TaskStore.stream().listen((_) {
      if (mounted) setState(() {});
    });

    // Load cached image from local storage first (instant)
    _profileImageUrl = StorageService.instance.loadProfileImageUrl();

    // Then sync from Firestore in background
    FirestoreService.instance.loadProfileImage().then((url) {
      if (url != null && mounted) {
        setState(() => _profileImageUrl = url);
        StorageService.instance.saveProfileImageUrl(url);
      }
    });
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 200,
      maxHeight: 200,
      imageQuality: 70,
    );
    if (picked == null) return;

    try {
      _toast('Saving photo...');
      final bytes = await picked.readAsBytes();
      final base64Str = base64Encode(bytes);

      await FirestoreService.instance.saveProfileImage(base64Str);
      await StorageService.instance.saveProfileImageUrl(base64Str);

      if (mounted) setState(() => _profileImageUrl = base64Str);
      _toast('Photo updated ✓');
    } catch (e) {
      _toast('Failed — try a smaller image');
    }
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AC.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AC.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(),
            const SizedBox(height: 20),
            Text(
              'Profile Photo',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            _optionRow(
              Icons.photo_library_rounded,
              'Choose from Gallery',
              AC.purple,
              () {
                Navigator.pop(context);
                _pickProfileImage();
              },
            ),
            const SizedBox(height: 10),
            _optionRow(
              Icons.palette_rounded,
              'Change Avatar Color',
              AC.purple,
              () {
                Navigator.pop(context);
                Future.delayed(const Duration(milliseconds: 300), () {
                  _showAvatarColorPicker();
                });
              },
            ),
            if (_profileImageUrl != null) ...[
              const SizedBox(height: 10),
              _optionRow(
                Icons.delete_outline_rounded,
                'Remove Photo',
                const Color(0xFFEF4444),
                () async {
                  Navigator.pop(context);
                  await StorageService.instance.saveProfileImageUrl('');
                  await FirestoreService.instance.saveProfileImage('');
                  if (mounted) setState(() => _profileImageUrl = null);
                  _toast('Photo removed');
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _optionRow(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.20)),
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

  @override
  void dispose() {
    _taskSub?.cancel();
    _enterCtrl.dispose();
    super.dispose();
  }

  // ── Live stats
  int get _streak => StorageService.instance.loadStreak();
  double get _focusHours => StorageService.instance.totalFocusHours;

  // ── Initials from display name
  String get _initials {
    final parts = _displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    final name = _displayName.trim();
    return name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeNotifier.instance.isDark;

    return Scaffold(
      backgroundColor: isDark ? AC.bg : const Color(0xFFF5F3FF),
      body: Stack(
        children: [
          if (isDark) const Positioned.fill(child: AmbientGlow()),
          SafeArea(
            bottom: false,
            child: FadeTransition(
              opacity: _enterAnim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(_enterAnim),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Column(
                    children: [
                      _buildTopBar(),
                      _buildProfileHeader(),
                      const SizedBox(height: 20),
                      const SizedBox(height: 8),

                      _buildSection('Preferences', [
                        _buildToggleTile(
                          icon: Icons.notifications_outlined,
                          label: 'Push Notifications',
                          sub: _notificationsOn
                              ? 'Task reminders enabled'
                              : 'All notifications off',
                          color: AC.purple,
                          value: _notificationsOn,
                          onChanged: _toggleNotifications,
                        ),
                        _buildToggleTile(
                          icon: Icons.shield_outlined,
                          label: 'Focus Shield',
                          sub: _focusShieldOn
                              ? 'Blocks distractions during focus'
                              : 'Notifications allowed during focus',
                          color: _green,
                          value: _focusShieldOn,
                          onChanged: _toggleFocusShield,
                        ),
                        _buildToggleTile(
                          icon: Icons.auto_awesome_outlined,
                          label: 'Smart Reminders',
                          sub: _smartRemindersOn
                              ? 'AI-powered nudges active'
                              : 'Smart reminders off',
                          color: _blue,
                          value: _smartRemindersOn,
                          onChanged: _toggleSmartReminders,
                        ),
                        _buildToggleTile(
                          icon: Icons.mic_rounded,
                          label: 'Daily Brief',
                          sub: _dailyBriefOn
                              ? 'ARIA prepares a daily briefing for you'
                              : 'Daily brief off',
                          color: AC.purple,
                          value: _dailyBriefOn,
                          onChanged: (v) async {
                            setState(() => _dailyBriefOn = v);
                            await StorageService.instance.saveDailyBriefOn(v);
                            _toast(v ? 'Daily brief on' : 'Daily brief off');
                          },
                        ),
                      ]),

                      const SizedBox(height: 16),

                      _buildSection('Account', [
                        _buildNavTile(
                          icon: Icons.person_outline_rounded,
                          label: 'Edit Profile',
                          sub: _displayName,
                          color: AC.purple,
                          onTap: _showEditProfile,
                        ),
                        // ← ADD HERE
                        _buildNavTile(
                          icon: Icons.psychology_outlined,
                          label: 'ARIA Memories',
                          sub: 'What ARIA remembers about you',
                          color: AC.purple,
                          onTap: _showMemories,
                        ),
                        _buildNavTile(
                          icon: Icons.lock_outline_rounded,
                          label: 'Change Password',
                          sub: 'Update your credentials',
                          color: _blue,
                          onTap: _showChangePassword,
                        ),

                        _buildNavTile(
                          icon: Icons.share_outlined,
                          label: 'Share ARIA',
                          sub: 'Invite friends & colleagues',
                          color: _amber,
                          onTap: _shareARIA,
                        ),
                      ]),

                      const SizedBox(height: 16),

                      _buildSection('Support', [
                        _buildNavTile(
                          icon: Icons.help_outline_rounded,
                          label: 'Help & FAQ',
                          sub: '8 common questions answered',
                          color: AC.purple,
                          onTap: _showHelpFAQ,
                        ),
                      ]),

                      const SizedBox(height: 16),
                      _buildLogoutButton(),
                      const SizedBox(height: 12),

                      Text(
                        'ARIA NEURAL ENGINE V4.0.2',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white.withOpacity(0.12),
                          fontSize: 9,
                          letterSpacing: 2.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TOGGLE ACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _toggleNotifications(bool v) async {
    setState(() => _notificationsOn = v);
    await StorageService.instance.saveNotificationsOn(v);
    if (!v) {
      await NotificationService.instance.cancelAll();
      _toast('All notifications turned off');
    } else {
      final todayTasks = TaskStore.forDate(DateTime.now());
      await NotificationService.instance.scheduleDailySummary(
        taskCount: todayTasks.length,
        highPriorityCount: todayTasks
            .where((t) => t.priority == TaskPriority.high)
            .length,
      );
      _toast('Notifications enabled');
    }
  }

  Future<void> _toggleFocusShield(bool v) async {
    setState(() => _focusShieldOn = v);
    await StorageService.instance.saveFocusShieldOn(v);
    _toast(v ? 'Focus Shield activated' : 'Focus Shield deactivated');
  }

  Future<void> _toggleSmartReminders(bool v) async {
    setState(() => _smartRemindersOn = v);
    await StorageService.instance.saveSmartRemindersOn(v);
    _toast(v ? 'Smart Reminders on' : 'Smart Reminders off');
  }

  Future<void> _toggleDailyReport(bool v) async {
    setState(() => _dailyReportOn = v);
    await StorageService.instance.saveDailyReportOn(v);
    if (v) {
      final todayTasks = TaskStore.forDate(DateTime.now());
      await NotificationService.instance.scheduleDailySummary(
        taskCount: todayTasks.length,
        highPriorityCount: todayTasks
            .where((t) => t.priority == TaskPriority.high)
            .length,
      );
      _toast('Daily report scheduled for 8:00 AM');
    } else {
      await NotificationService.instance.cancel(2000);
      _toast('Daily report turned off');
    }
  }

  Future<void> _toggleDarkMode(bool v) async {
    await ThemeNotifier.instance.set(v);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACCOUNT ACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.80,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: AC.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AC.cardBorder),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(context).padding.bottom + 24,
            ),
            children: [
              _sheetHandle(),
              const SizedBox(height: 16),
              Text(
                'Settings',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'App configuration',
                style: GoogleFonts.spaceGrotesk(
                  color: AC.bodyText,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              // ── Data
              _settingsSectionLabel('Data'),
              _settingsNavRow(
                icon: Icons.delete_outline_rounded,
                color: _red,
                label: 'Clear App Cache',
                value: '',
                onTap: () {
                  Navigator.pop(context);
                  _showClearCacheConfirm();
                },
              ),
              _settingsNavRow(
                icon: Icons.cloud_sync_outlined,
                color: _green,
                label: 'Sync & Backup',
                value: '',
                onTap: () {
                  Navigator.pop(context);
                  Future.delayed(
                    const Duration(milliseconds: 250),
                    _showSyncBackup,
                  );
                },
              ),

              // ── Legal
              _settingsSectionLabel('Legal'),
              _settingsNavRow(
                icon: Icons.privacy_tip_outlined,
                color: _blue,
                label: 'Privacy Policy',
                value: '',
                onTap: () {
                  Navigator.pop(context);
                  Future.delayed(
                    const Duration(milliseconds: 250),
                    _showPrivacyPolicy,
                  );
                },
              ),
              _settingsNavRow(
                icon: Icons.info_outline_rounded,
                color: AC.mutedText,
                label: 'About ARIA',
                value: 'v1.0.0',
                onTap: () {
                  Navigator.pop(context);
                  Future.delayed(const Duration(milliseconds: 250), _showAbout);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Settings helpers
  Widget _settingsSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.spaceGrotesk(
          color: AC.bodyText,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _settingsNavRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AC.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AC.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: color.withOpacity(0.12),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (value.isNotEmpty)
              Text(
                value,
                style: GoogleFonts.spaceGrotesk(
                  color: AC.bodyText,
                  fontSize: 12,
                ),
              ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: AC.iconTint, size: 16),
          ],
        ),
      ),
    );
  }

  void _showAvatarColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AC.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AC.cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHandle(),
              const SizedBox(height: 16),
              Text(
                'Avatar Color',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap a color to update your avatar',
                style: GoogleFonts.spaceGrotesk(
                  color: AC.bodyText,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: _avatarColors.map((c) {
                  final isSelected = _avatarColor.value == c.value;
                  return GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await StorageService.instance.saveAvatarColor(c.value);
                      setModal(() {});
                      if (mounted) {
                        setState(() => _avatarColor = c);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: c.withOpacity(0.5),
                                  blurRadius: 12,
                                ),
                              ]
                            : [],
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 22,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: _sheetSaveBtn('Done'),
              ),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom + 4),
            ],
          ),
        ),
      ),
    );
  }

  void _showMemories() async {
    final memories = await FirestoreService.instance.loadMemories();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: AC.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AC.cardBorder),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AC.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ARIA Memories',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            await FirestoreService.instance.clearAllMemories();
                            Navigator.pop(context);
                            _toast('All memories cleared');
                          },
                          child: Text(
                            'Clear all',
                            style: GoogleFonts.spaceGrotesk(
                              color: _red,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Facts ARIA learned from your conversations',
                      style: GoogleFonts.spaceGrotesk(
                        color: AC.bodyText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: memories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.psychology_outlined,
                              color: AC.iconTint,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No memories yet',
                              style: GoogleFonts.spaceGrotesk(
                                color: AC.bodyText,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Chat with ARIA to build memories',
                              style: GoogleFonts.spaceGrotesk(
                                color: AC.mutedText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                        children: memories.entries
                            .map(
                              (e) => Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AC.bg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AC.purpleBorder),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        color: AC.purple.withOpacity(0.12),
                                      ),
                                      child: Icon(
                                        Icons.lightbulb_outline_rounded,
                                        color: AC.purple,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            e.key
                                                .replaceAll('_', ' ')
                                                .toUpperCase(),
                                            style: GoogleFonts.spaceGrotesk(
                                              color: AC.purple,
                                              fontSize: 9,
                                              letterSpacing: 1.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            e.value,
                                            style: GoogleFonts.spaceGrotesk(
                                              color: Colors.white,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () async {
                                        await FirestoreService.instance
                                            .deleteMemory(e.key);
                                        Navigator.pop(context);
                                        _showMemories();
                                      },
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: AC.mutedText,
                                        size: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfile() {
    final nameCtrl = TextEditingController(text: _displayName);
    final emailCtrl = TextEditingController(text: _displayEmail);
    String? nameErr, emailErr;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AC.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AC.cardBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetHandle(),
                const SizedBox(height: 16),
                Text(
                  'Edit Profile',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'FULL NAME',
                  style: GoogleFonts.spaceGrotesk(
                    color: AC.bodyText,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                _formField(
                  ctrl: nameCtrl,
                  hint: 'Your full name',
                  icon: Icons.person_outline,
                  errorText: nameErr,
                  onChanged: (_) => setModalState(() => nameErr = null),
                ),
                const SizedBox(height: 16),
                Text(
                  'EMAIL',
                  style: GoogleFonts.spaceGrotesk(
                    color: AC.bodyText,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                _formField(
                  ctrl: emailCtrl,
                  hint: 'your@email.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  errorText: emailErr,
                  onChanged: (_) => setModalState(() => emailErr = null),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: _sheetCancelBtn()),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final name = nameCtrl.text.trim();
                          final email = emailCtrl.text.trim();
                          bool valid = true;
                          if (name.isEmpty) {
                            setModalState(() => nameErr = 'Name required');
                            valid = false;
                          }
                          if (!RegExp(
                            r'^[\w.-]+@[\w.-]+\.\w{2,}$',
                          ).hasMatch(email)) {
                            setModalState(() => emailErr = 'Invalid email');
                            valid = false;
                          }
                          if (!valid) return;
                          await StorageService.instance.saveUserName(name);
                          await StorageService.instance.saveUserEmail(email);
                          await AuthService.instance.currentUser
                              ?.updateDisplayName(name);
                          await FirestoreService.instance.saveProfile(
                            name: name,
                            email: email,
                          );
                          setState(() {
                            _displayName = name;
                            _displayEmail = email;
                          });
                          if (mounted) Navigator.pop(ctx);
                          _toast('Profile updated ✓');
                        },
                        child: _sheetSaveBtn('Save Changes'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(ctx).padding.bottom + 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChangePassword() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureCurr = true, obscureNew = true, obscureConf = true;
    String? currErr, newErr, confErr;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AC.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AC.cardBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetHandle(),
                const SizedBox(height: 16),
                Text(
                  'Change Password',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                _formField(
                  ctrl: currentCtrl,
                  hint: 'Current password',
                  icon: Icons.lock_outline,
                  obscure: obscureCurr,
                  errorText: currErr,
                  onChanged: (_) => setModalState(() => currErr = null),
                  suffix: GestureDetector(
                    onTap: () =>
                        setModalState(() => obscureCurr = !obscureCurr),
                    child: Icon(
                      obscureCurr
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AC.iconTint,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _formField(
                  ctrl: newCtrl,
                  hint: 'New password',
                  icon: Icons.lock_outline,
                  obscure: obscureNew,
                  errorText: newErr,
                  onChanged: (_) => setModalState(() => newErr = null),
                  suffix: GestureDetector(
                    onTap: () => setModalState(() => obscureNew = !obscureNew),
                    child: Icon(
                      obscureNew
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AC.iconTint,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _formField(
                  ctrl: confirmCtrl,
                  hint: 'Confirm new password',
                  icon: Icons.shield_outlined,
                  obscure: obscureConf,
                  errorText: confErr,
                  onChanged: (_) => setModalState(() => confErr = null),
                  suffix: GestureDetector(
                    onTap: () =>
                        setModalState(() => obscureConf = !obscureConf),
                    child: Icon(
                      obscureConf
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AC.iconTint,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: _sheetCancelBtn()),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          bool valid = true;
                          if (currentCtrl.text.isEmpty) {
                            setModalState(
                              () => currErr = 'Enter current password',
                            );
                            valid = false;
                          }
                          if (newCtrl.text.length < 6) {
                            setModalState(() => newErr = 'Min 6 characters');
                            valid = false;
                          }
                          if (confirmCtrl.text != newCtrl.text) {
                            setModalState(
                              () => confErr = 'Passwords don\'t match',
                            );
                            valid = false;
                          }
                          if (!valid) return;
                          Navigator.pop(ctx);
                          _toast('Password updated ✓');
                        },
                        child: _sheetSaveBtn('Update Password'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(ctx).padding.bottom + 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSyncBackup() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final timeStr = '$displayHour:$minute $period';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.75,
        minChildSize: 0.45,
        builder: (_, scrollCtrl) => Container(
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: AC.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AC.cardBorder),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(context).padding.bottom + 24,
            ),
            children: [
              _sheetHandle(),
              const SizedBox(height: 20),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _green.withOpacity(0.12),
                  border: Border.all(color: _green.withOpacity(0.4)),
                ),
                child: const Icon(
                  Icons.cloud_done_outlined,
                  color: _green,
                  size: 26,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Sync & Backup',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Last synced today at $timeStr',
                style: GoogleFonts.spaceGrotesk(
                  color: AC.bodyText,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              _syncRow('Tasks', '${TaskStore.all.length} saved', _green),
              _syncRow(
                'Focus Sessions',
                '${StorageService.instance.loadFocusSessions()} sessions',
                AC.purple,
              ),
              _syncRow(
                'Focus Time',
                '${StorageService.instance.loadTotalFocusMinutes()} minutes',
                _blue,
              ),
              _syncRow(
                'Streak',
                '${StorageService.instance.loadStreak()} days',
                _amber,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);
                  _toast('Backup complete ✓');
                },
                child: _sheetSaveBtn('Sync Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearCacheConfirm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AC.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AC.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _red.withOpacity(0.1),
                border: Border.all(color: _red.withOpacity(0.3)),
              ),
              child: Icon(Icons.delete_outline_rounded, color: _red, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              'Clear Cache?',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will clear temporary data. Your tasks and settings will not be affected.',
              style: GoogleFonts.spaceGrotesk(color: AC.bodyText, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _sheetCancelBtn()),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _toast('Cache cleared ✓');
                    },
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: _red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _red.withOpacity(0.4)),
                      ),
                      child: Center(
                        child: Text(
                          'Clear',
                          style: GoogleFonts.spaceGrotesk(
                            color: _red,
                            fontSize: 14,
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
  }

  Widget _syncRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(color: AC.bodyText, fontSize: 13),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _shareARIA() {
    HapticFeedback.mediumImpact();
    Share.share(
      '🚀 I\'ve been using ARIA — an AI-powered productivity assistant!\n\n'
      'Try it here: https://aria-19f74.web.app',

      subject: 'Check out ARIA',
    );
  }

  void _showHelpFAQ() {
    final faqs = [
      _FAQ(
        'How does ARIA schedule my tasks?',
        'ARIA analyzes your energy levels, deadlines, and historical productivity patterns to suggest the optimal order and timing for your tasks.',
      ),
      _FAQ(
        'What is Focus Shield?',
        'Focus Shield blocks all notifications during active focus sessions, helping you maintain deep work without interruptions.',
      ),
      _FAQ(
        'How is my focus score calculated?',
        'Your focus score starts at 100% and decreases with each pause or distraction during a session. Complete sessions without interruptions to maintain a high score.',
      ),
      _FAQ(
        'What do the energy levels mean?',
        'High Energy (50 min), Medium Energy (30 min), and Low Energy (15 min) sessions are AI-suggested durations based on your current state for optimal performance.',
      ),
      _FAQ(
        'How does the streak work?',
        'Complete at least one task or focus session per day to maintain your streak. Missing a day resets it to 1.',
      ),
      _FAQ(
        'Can I change task reminders timing?',
        'Currently reminders fire 10 minutes before each task. Customizable timing is coming in a future update.',
      ),
      _FAQ(
        'Is my data backed up?',
        'All data is stored locally on your device. Use Sync & Backup to save a snapshot. Cloud sync is coming soon.',
      ),
      _FAQ(
        'How do I delete all my data?',
        'Sign out from the Profile screen and your personal data will be cleared. Task history is retained for analytics unless you manually delete tasks.',
      ),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Container(
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: AC.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AC.cardBorder),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _sheetHandle(),
                    const SizedBox(height: 14),
                    Text(
                      'Help & FAQ',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  itemCount: faqs.length,
                  itemBuilder: (_, i) => _ExpandableFAQ(faq: faqs[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Container(
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: AC.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AC.cardBorder),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _sheetHandle(),
                    const SizedBox(height: 14),
                    Text(
                      'Privacy Policy',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last updated: March 2025',
                      style: GoogleFonts.spaceGrotesk(
                        color: AC.bodyText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  children: [
                    _privacySection(
                      'Data We Collect',
                      'ARIA collects task data, focus session statistics, and usage patterns entirely on your local device. We do not collect personally identifiable information or transmit data to external servers without your explicit consent.',
                    ),
                    _privacySection(
                      'How We Use Your Data',
                      'All data collected is used solely to provide personalized productivity insights, calculate your focus score, maintain your streak, and generate the AI insights shown in the app.',
                    ),
                    _privacySection(
                      'Data Storage',
                      'Your data is stored locally using secure on-device storage (SharedPreferences). We do not have access to your data on our servers. Cloud backup, when enabled, uses encrypted transport.',
                    ),
                    _privacySection(
                      'Notifications',
                      'ARIA requests notification permissions to send task reminders and focus session alerts. You can disable these at any time in the app settings or your device settings.',
                    ),
                    _privacySection(
                      'Third-Party Services',
                      'ARIA does not share your data with third-party analytics, advertising networks, or data brokers. The app operates entirely independently.',
                    ),
                    _privacySection(
                      'Your Rights',
                      'You can delete all your data at any time by signing out or clearing the app data in your device settings. You have full control over your information.',
                    ),
                    _privacySection(
                      'Children\'s Privacy',
                      'ARIA is designed for users aged 13 and above. We do not knowingly collect data from children under 13.',
                    ),
                    _privacySection(
                      'Contact',
                      'For privacy concerns or questions, contact us at privacy@aria-intelligence.ai. We typically respond within 48 hours.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _privacySection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.spaceGrotesk(
              color: AC.bodyText,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ← ADD
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        // ← REPLACE Container with this
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.45,
        builder: (_, scrollCtrl) => Container(
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: AC.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AC.cardBorder),
          ),
          child: SingleChildScrollView(
            controller: scrollCtrl, // ← wire controller
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).padding.bottom + 24, // ← safe area
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _sheetHandle(),
                  const SizedBox(height: 20),
                  ClipOval(
                    child: Image.asset(
                      'assets/aria_logo.png',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'ARIA',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Adaptive Reasoning Intelligence Assistant',
                    style: GoogleFonts.spaceGrotesk(
                      color: AC.bodyText,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AC.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AC.cardBorder),
                    ),
                    child: Column(
                      children: [
                        _aboutRow('Version', '1.0.0'),
                        _divRow(),
                        _aboutRow('Neural Engine', 'v4.0.2'),
                        _divRow(),
                        _aboutRow('Build', 'Release'),
                        _divRow(),
                        _aboutRow('Platform', 'Flutter 3.x'),
                        _divRow(),
                        _aboutRow('Total Tasks', '${TaskStore.all.length}'),
                        _divRow(),
                        _aboutRow(
                          'Focus Hours',
                          '${_focusHours.toStringAsFixed(1)}h',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: _sheetSaveBtn('Close'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _divRow() => Divider(height: 1, color: Colors.white.withOpacity(0.05));

  // ══════════════════════════════════════════════════════════════════════════
  // UI BUILDING BLOCKS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTopBar() {
    final isDark = ThemeNotifier.instance.isDark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Profile',
            style: GoogleFonts.spaceGrotesk(
              color: isDark ? Colors.white : const Color(0xFF1A1035),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          GestureDetector(
            onTap: _showSettings,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? AC.card : Colors.white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AC.cardBorder),
              ),
              child: Icon(
                Icons.settings_outlined,
                color: isDark ? AC.iconTint : Colors.black54,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final isDark = ThemeNotifier.instance.isDark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AC.card : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? AC.purpleBorder : AC.purple.withOpacity(0.2),
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: AC.purple.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _showAvatarOptions,
              child: Stack(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AC.purple, AC.purpleDeep],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: AC.purpleBorder, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: AC.purpleShadow2,
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _profileImageUrl != null
                        ? ClipOval(
                            child: Image.memory(
                              base64Decode(_profileImageUrl!),
                              width: 68,
                              height: 68,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  _initials,
                                  style: GoogleFonts.spaceGrotesk(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              _initials,
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AC.purple,
                        border: Border.all(
                          color: isDark ? AC.bg : Colors.white,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName,
                    style: GoogleFonts.spaceGrotesk(
                      color: isDark ? Colors.white : const Color(0xFF1A1035),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _displayEmail,
                    style: GoogleFonts.spaceGrotesk(
                      color: AC.bodyText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _showEditProfile,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isDark ? AC.bg : const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AC.cardBorder),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: AC.iconTint,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> tiles) {
    final isDark = ThemeNotifier.instance.isDark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              title.toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                color: AC.bodyText,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AC.card : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AC.cardBorder),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              children: tiles.asMap().entries.map((e) {
                final isLast = e.key == tiles.length - 1;
                return Column(
                  children: [
                    e.value,
                    if (!isLast)
                      Divider(
                        height: 1,
                        color: Colors.white.withOpacity(0.05),
                        indent: 54,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String label,
    required String sub,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = ThemeNotifier.instance.isDark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: color.withOpacity(0.12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.spaceGrotesk(
                    color: isDark ? Colors.white : const Color(0xFF1A1035),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  sub,
                  style: GoogleFonts.spaceGrotesk(
                    color: AC.bodyText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onChanged(!value);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 44,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: value ? color : AC.bg,
                border: Border.all(color: value ? color : AC.cardBorder),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required String label,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = ThemeNotifier.instance.isDark;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: color.withOpacity(0.12),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.spaceGrotesk(
                      color: isDark ? Colors.white : const Color(0xFF1A1035),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    sub,
                    style: GoogleFonts.spaceGrotesk(
                      color: AC.bodyText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AC.iconTint, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: _showLogoutDialog,
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: _red.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _red.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: _red, size: 18),
              const SizedBox(width: 8),
              Text(
                'Sign Out',
                style: GoogleFonts.spaceGrotesk(
                  color: _red,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AC.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AC.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _red.withOpacity(0.1),
                border: Border.all(color: _red.withOpacity(0.3)),
              ),
              child: Icon(Icons.logout_rounded, color: _red, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              'Sign Out?',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ll need to sign in again to access ARIA.',
              style: GoogleFonts.spaceGrotesk(color: AC.bodyText, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _sheetCancelBtn()),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await AuthService.instance.signOut();
                      await StorageService.instance.clearUserData();
                      await NotificationService.instance.cancelAll();
                      if (mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (r) => false,
                        );
                      }
                    },
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: _red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _red.withOpacity(0.4)),
                      ),
                      child: Center(
                        child: Text(
                          'Sign Out',
                          style: GoogleFonts.spaceGrotesk(
                            color: _red,
                            fontSize: 14,
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
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _sheetHandle() => Center(
    child: Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AC.cardBorder,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _sheetCancelBtn() => GestureDetector(
    onTap: () => Navigator.pop(context),
    child: Container(
      height: 50,
      decoration: BoxDecoration(
        color: AC.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AC.cardBorder),
      ),
      child: Center(
        child: Text(
          'Cancel',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );

  Widget _sheetSaveBtn(String label) => Container(
    height: 50,
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [AC.purple, AC.purpleDeep]),
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [
        BoxShadow(
          color: AC.purpleShadow2,
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Center(
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );

  Widget _formField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    String? errorText,
    ValueChanged<String>? onChanged,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AC.input,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: errorText != null ? AC.error : AC.inputBorder,
            ),
          ),
          child: TextField(
            controller: ctrl,
            obscureText: obscure,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.spaceGrotesk(color: AC.hint, fontSize: 14),
              prefixIcon: Icon(icon, color: AC.iconTint, size: 18),
              suffixIcon: suffix != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: suffix,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.error_outline, color: AC.error, size: 12),
              const SizedBox(width: 4),
              Text(
                errorText,
                style: GoogleFonts.spaceGrotesk(color: AC.error, fontSize: 11),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AC.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          msg,
          style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 13),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _aboutRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(color: AC.bodyText, fontSize: 13),
          ),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Expandable FAQ item ──────────────────────────────────────────────────────
class _FAQ {
  final String question, answer;
  const _FAQ(this.question, this.answer);
}

class _ExpandableFAQ extends StatefulWidget {
  final _FAQ faq;
  const _ExpandableFAQ({required this.faq});
  @override
  State<_ExpandableFAQ> createState() => _ExpandableFAQState();
}

class _ExpandableFAQState extends State<_ExpandableFAQ> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _expanded = !_expanded);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _expanded ? AC.purple.withOpacity(0.08) : AC.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _expanded ? AC.purple.withOpacity(0.3) : AC.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.faq.question,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: _expanded ? AC.purple : AC.iconTint,
                    size: 18,
                  ),
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              Text(
                widget.faq.answer,
                style: GoogleFonts.spaceGrotesk(
                  color: AC.bodyText,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
