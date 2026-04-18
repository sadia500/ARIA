import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppBlockerService {
  static const _channel = MethodChannel('com.example.aria/app_blocker');

  // Safe platform check that won't throw on web/emulator
  static bool get _isAndroid {
    try {
      return defaultTargetPlatform == TargetPlatform.android;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasNotificationListenerPermission() async {
    if (!_isAndroid) return true;
    try {
      return await _channel.invokeMethod('hasNotificationListenerPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestNotificationListenerPermission() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('requestNotificationListenerPermission');
    } catch (_) {}
  }

  static Future<void> enableNotificationBlocking() async {
    if (!_isAndroid) {
      debugPrint('🔕 [MOCK] Notification blocking enabled');
      return;
    }
    try {
      await _channel.invokeMethod('enableNotificationBlocking');
    } catch (e) {
      debugPrint('Notification blocking error: $e');
    }
  }

  static Future<void> disableNotificationBlocking() async {
    if (!_isAndroid) {
      debugPrint('🔔 [MOCK] Notification blocking disabled');
      return;
    }
    try {
      await _channel.invokeMethod('disableNotificationBlocking');
    } catch (e) {
      debugPrint('Notification blocking error: $e');
    }
  }

  static Future<bool> hasAccessibilityPermission() async {
    if (!_isAndroid) return true;
    try {
      return await _channel.invokeMethod('hasAccessibilityPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestAccessibilityPermission() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('requestAccessibilityPermission');
    } catch (_) {}
  }

  static Future<void> startAppBlocking() async {
    debugPrint('🔥 startAppBlocking() called');
    if (!_isAndroid) {
      debugPrint('🚫 [MOCK] App blocking started');
      return;
    }
    try {
      debugPrint('🔥 Invoking method channel...');
      await _channel.invokeMethod('startAppBlocking', {
        'blockedApps': [
          'com.discord',
          'com.instagram.android',
          'com.twitter.android',
          'com.facebook.katana',
          'com.zhiliaoapp.musically',
          'com.snapchat.android',
          'com.reddit.frontpage',
          'com.google.android.youtube',
        ],
      });
      debugPrint('🔥 Method channel invoked successfully');
    } catch (e) {
      debugPrint('❌ App blocking error: $e');
    }
  }

  static Future<void> stopAppBlocking() async {
    if (!_isAndroid) {
      debugPrint('✅ [MOCK] App blocking stopped');
      return;
    }
    try {
      await _channel.invokeMethod('stopAppBlocking');
      debugPrint('🔥 startAppBlocking called successfully');
    } catch (e) {
      debugPrint('Stop app blocking error: $e');
    }
  }
}
