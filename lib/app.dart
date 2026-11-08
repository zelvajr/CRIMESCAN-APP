import 'package:flutter/material.dart';
import 'core/constants/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/case_init_screen.dart';
import 'screens/live_feed_screen.dart';
import 'screens/capture_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/voice_screen.dart';
import 'screens/sync_screen.dart';
import 'screens/review_screen.dart';
import 'screens/report_screen.dart';

class ForensicApp extends StatelessWidget {
  const ForensicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpiderCam Forensic Suite',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {
        '/':          (_) => const SplashScreen(),
        '/case':      (_) => const CaseInitScreen(),
        '/home':      (_) => const HomeScreen(),
        '/live':      (_) => const LiveFeedScreen(),
        '/capture':   (_) => const CaptureScreen(),
        '/gallery':   (_) => const GalleryScreen(),
        '/voice':     (_) => const VoiceScreen(),
        '/sync':      (_) => const SyncScreen(),
        '/report':    (_) => const ReportScreen(),
        '/review':    (_) => const ReviewScreen(),
      },
    );
  }
}