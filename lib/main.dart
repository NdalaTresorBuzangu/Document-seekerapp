import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'firebase_options.dart';
import 'home_page.dart';
import 'new_request_page.dart';
import 'notification_service.dart';
import 'pack_page.dart';
import 'preloss_page.dart';
import 'pending_sync.dart';
import 'seeker_dashboard_page.dart';
import 'session_store.dart';
import 'track_progress_page.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Background notification received: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (kIsWeb) {
      debugPrint('Running on web — Firebase messaging is limited without HTTPS.');
    } else {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  await SessionStore.warmUp();

  try {
    if (!kIsWeb) {
      await NotificationService.instance.init();
    }
  } catch (e) {
    debugPrint('Notification service initialization error: $e');
  }

  runApp(const DocumentSeekerApp());
}

class DocumentSeekerApp extends StatefulWidget {
  const DocumentSeekerApp({super.key});

  @override
  State<DocumentSeekerApp> createState() => _DocumentSeekerAppState();
}

class _DocumentSeekerAppState extends State<DocumentSeekerApp> with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
      _connectivitySub = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final online = results.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn ||
          r == ConnectivityResult.other,
    );
    if (online) {
      unawaited(PendingSync.flushAll());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(PendingSync.flushAll());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final sub = _connectivitySub;
    if (sub != null) {
      unawaited(sub.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Tshijuka Document Seeker',
      debugShowCheckedModeBanner: false,
      theme: buildDocumentSeekerTheme(),
      home: SessionStore.token != null && SessionStore.token!.isNotEmpty
          ? const SeekerDashboardPage()
          : const HomePage(),
      routes: {
        '/seeker/dashboard': (_) => const SeekerDashboardPage(),
        '/seeker/new-request': (_) => const NewRequestPage(),
        '/seeker/pack': (_) => const PackPage(),
        '/seeker/track': (_) => const TrackProgressPage(),
        '/seeker/preloss': (_) => const PrelossPage(),
      },
    );
  }
}
