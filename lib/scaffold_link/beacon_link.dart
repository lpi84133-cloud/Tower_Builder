import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'secret_box.dart';
import 'ua_pack.dart';

// Firebase Messaging bridge + local notification presentation.
//
// Cold-start taps (the app was killed) stash the tapped link so the
// shell opens it on next boot. Warm taps (background/foreground) hand
// the link back live via [onLink] AND stash it as a pending link so
// the shell always has a target to open next — the shell consumes and
// clears the pending link at the top of `_drive()`, so this does not
// leak across sessions the way an unguarded "save on every tap" would.
//
// Foreground behaviour: FCM only auto-displays a system notification
// when the push carries a `notification` block. Data-only pushes
// arrive silently and would be lost, so we display a local
// notification for them too — the visible count on the device then
// matches the send count on the backend.
//
// The Android notification channel id below MUST match the manifest
// meta-data `default_notification_channel_id`. A rename in one place
// without the other silently drops every incoming notification.

const String kAlertsChannel = 'bc.greenfg.notify.brix';
const String kAlertsChannelLabel = 'Updates and highlights';
const String _smallIcon = '@drawable/ic_brix_flame';

@pragma('vm:entry-point')
Future<void> _brixBg(RemoteMessage message) async {
  // Background notifications are drawn by the OS; taps get processed
  // on resume (warm) or boot (cold) — nothing to do here.
}

class BeaconLink {
  BeaconLink(this._box);

  final SecretBox _box;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _fm;
  String? _token;
  bool _ready = false;

  /// Warm push link delivery. Set by the current top-of-stack screen
  /// (typically WebShell) so a tap while the app is open loads the
  /// pushed URL immediately. When it is null the link falls through
  /// to the pending-link stash.
  void Function(String link)? onLink;

  /// Fires when FCM rotates the token → re-POST to the gate.
  void Function(String token)? onTokenRotated;

  String? get token => _token;

  Future<void> boot() async {
    if (_ready) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _fm = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_brixBg);

      await _wireLocal();

      _token = await _fm!.getToken();
      _fm!.onTokenRefresh.listen((String t) {
        _token = t;
        onTokenRotated?.call(t);
      });

      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onWarmTap);

      final RemoteMessage? initial = await _fm!.getInitialMessage();
      // MUST await — stashPendingLink writes to EncryptedStorage and the
      // caller (_drive) reads the pending slot immediately after boot()
      // returns. Without the await, takePendingLink() races the write
      // and returns null, sending the user through the full attribution
      // pipeline instead of the notification URL.
      if (initial != null) await _onColdTap(initial);

      _ready = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BeaconLink] init failed: $e');
      }
      // Firebase not configured yet — push stays dormant.
    }
  }

  Future<void> _wireLocal() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings(_smallIcon);
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        final String? payload = r.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final Map<String, dynamic> data =
              jsonDecode(payload) as Map<String, dynamic>;
          final String? link = _pickLink(data);
          if (link == null) return;
          _dispatch(link);
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? plug = _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await plug?.createNotificationChannel(
        const AndroidNotificationChannel(
          kAlertsChannel,
          kAlertsChannelLabel,
          description: 'Milestones and studio news',
          importance: Importance.high,
        ),
      );
    }
  }

  Future<bool> askPermission() async {
    if (_fm == null) return false;
    final NotificationSettings s = await _fm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final AuthorizationStatus st = s.authorizationStatus;
    final bool granted = st == AuthorizationStatus.authorized ||
        st == AuthorizationStatus.provisional;

    await _box.markPushAllowed(granted);
    if (st == AuthorizationStatus.denied) {
      await _box.markPushBlockedByOs();
    }
    return granted;
  }

  Future<void> _onForeground(RemoteMessage message) async {
    if (!Platform.isAndroid) return;

    final RemoteNotification? n = message.notification;
    final Map<String, dynamic> data = _stringData(message);

    final String? title =
        n?.title ?? data['title'] as String? ?? data['message'] as String?;
    final String? body =
        n?.body ?? data['body'] as String? ?? data['text'] as String?;

    if (kDebugMode) {
      debugPrint('[BeaconLink] foreground push: '
          'title=$title body=$body data=$data');
    }

    // Data-only pushes have no notification block — show one anyway
    // so the user sees every send. Notification-carrying pushes with
    // an image get a BigPicture style.
    AndroidNotificationDetails? details;
    final String? imageUrl = n?.android?.imageUrl ??
        data['image_url'] as String? ??
        data['image'] as String?;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final Uint8List? bytes = await _fetchImage(imageUrl);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          kAlertsChannel,
          kAlertsChannelLabel,
          importance: Importance.high,
          priority: Priority.high,
          icon: _smallIcon,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }

    details ??= const AndroidNotificationDetails(
      kAlertsChannel,
      kAlertsChannelLabel,
      importance: Importance.high,
      priority: Priority.high,
      icon: _smallIcon,
    );

    // Unique id per push, so a rapid second push does not overwrite
    // the first one in the notification tray.
    final int id = message.messageId?.hashCode ??
        DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);

    await _local.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: details),
      payload: data.isNotEmpty ? jsonEncode(data) : null,
    );
  }

  Future<void> _onColdTap(RemoteMessage message) async {
    final Map<String, dynamic> data = _stringData(message);
    if (kDebugMode) {
      debugPrint('[BeaconLink] cold tap: $data');
    }
    final String? link = _pickLink(data);
    if (link != null && link.isNotEmpty) {
      await _box.stashPendingLink(link);
    }
  }

  void _onWarmTap(RemoteMessage message) {
    final Map<String, dynamic> data = _stringData(message);
    if (kDebugMode) {
      debugPrint('[BeaconLink] warm tap: $data');
    }
    final String? link = _pickLink(data);
    if (link == null || link.isEmpty) return;
    _dispatch(link);
  }

  /// Route a live-tap URL either to the open WebShell (when it registered
  /// an `onLink` receiver) or to the pending-stash for the router to
  /// consume on its next drive.
  ///
  /// The two branches are MUTUALLY EXCLUSIVE on purpose: writing the URL
  /// to the stash while a WebShell is already showing means a force-close
  /// leaves the URL dangling. The next cold start would then hand that
  /// stale URL to `takePendingLink()` and open the pushed page again,
  /// even though the user just wanted the base link.
  void _dispatch(String link) {
    final void Function(String)? live = onLink;
    if (live != null) {
      live(link);
      // Clear any leftover stash from before the WebShell was live —
      // the receiver has taken over, no need to persist across kill.
      _box.stashPendingLink(null);
    } else {
      _box.stashPendingLink(link);
    }
  }

  Future<Uint8List?> _fetchImage(String url) async {
    try {
      final dynamic res = await brixHttp
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return res.bodyBytes as Uint8List;
    } catch (_) {}
    return null;
  }

  static Map<String, dynamic> _stringData(RemoteMessage message) {
    return message.data.map<String, dynamic>((String k, dynamic v) =>
        MapEntry<String, dynamic>(k, v));
  }

  // The partner backend uses `url`, but production pushes have been
  // seen carrying `click_url`, `deep_link`, `link` and `open_url`
  // depending on which sender template was used. Accept all of them
  // so QA does not have to configure the backend around us.
  static String? _pickLink(Map<String, dynamic> data) {
    const List<String> keys = <String>[
      'url',
      'click_url',
      'deep_link',
      'deeplink',
      'link',
      'open_url',
    ];
    for (final String k in keys) {
      final dynamic v = data[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }
}
