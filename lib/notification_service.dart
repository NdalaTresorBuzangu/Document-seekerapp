import 'dart:typed_data';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Same pattern as the WasteJustice template [`fluutter app/lib/notification.dart`]:
/// FCM + local notifications + strong haptics (including channel vibration on Android).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();

  int _localNotifIdSeq = 1;

  static const String _androidChannelId = 'document_seeker_channel';

  Future<void> init() async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    final token = await _fcm.getToken();
    debugPrint('FCM Token: $token');

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotif.initialize(initSettings);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _localNotif.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _androidChannelId,
          'Tshijuka Document Seeker',
          description: 'Document requests, payments, and status updates',
          importance: Importance.high,
        ),
      );
      await androidPlugin?.requestNotificationsPermission();
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _localNotif
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    FirebaseMessaging.onMessage.listen(_onRemoteMessage);
  }

  void _onRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final isPayment = data['type'] == 'payment_completed' ||
        data['event'] == 'payment_completed' ||
        data['event'] == 'payment';

    if (isPayment) {
      final title = data['title']?.toString().trim().isNotEmpty == true
          ? data['title']!.toString()
          : 'Payment received';
      final body = data['body']?.toString().trim().isNotEmpty == true
          ? data['body']!.toString()
          : 'Your retrieval payment was processed.';
      final parsed = int.tryParse(data['paymentID']?.toString() ?? '');
      final id = parsed ?? _localNotifIdSeq++;
      showLocalAlert(title: title, body: body, notificationId: id);
      return;
    }

    if (message.notification != null) {
      showLocalAlert(
        title: message.notification!.title ?? 'Tshijuka Document Seeker',
        body: message.notification!.body ?? '',
      );
    } else if (data['title'] != null || data['body'] != null) {
      showLocalAlert(
        title: data['title']?.toString() ?? 'Tshijuka Document Seeker',
        body: data['body']?.toString() ?? '',
      );
    }
  }

  Future<void> showLocalAlert({
    required String title,
    required String body,
    int? notificationId,
  }) async {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();

    final androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      'Tshijuka Document Seeker',
      channelDescription: 'Document requests and institution updates',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 450, 140, 450, 140, 600]),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notifDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    final id = notificationId ?? _localNotifIdSeq++;
    await _localNotif.show(id, title, body, notifDetails);
  }

  /// After a successful document submit (same idea as `notifyWasteSubmissionSent` in the template).
  Future<void> notifyDocumentRequestSubmitted({required List<String> documentIds}) async {
    final body = documentIds.isEmpty
        ? 'Your request was transmitted to the institution.'
        : 'Document ID(s): ${documentIds.join(', ')}';
    final id = DateTime.now().millisecondsSinceEpoch & 0x3FFFFFFF;
    await showLocalAlert(
      title: 'Request submitted',
      body: body,
      notificationId: id,
    );
  }

  /// When the request is queued offline (optional reassurance).
  Future<void> notifyDocumentRequestQueued() async {
    final id = DateTime.now().millisecondsSinceEpoch & 0x3FFFFFFF;
    await showLocalAlert(
      title: 'Request saved',
      body: 'You are offline — the request will sync when you are back online.',
      notificationId: id,
    );
  }
}
