import 'package:flutter/material.dart';

class AppColors {
  // Primary forensic palette
  static const Color background    = Color(0xFF080B0F);
  static const Color surface       = Color(0xFF0C1018);
  static const Color surfaceCard   = Color(0xFF0D1520);
  static const Color border        = Color(0xFF1C3352);
  static const Color borderLight   = Color(0xFF162838);

  // Accent
  static const Color cyan          = Color(0xFF4DC8F0);
  static const Color cyanLight     = Color(0xFF7ADCF8);
  static const Color green         = Color(0xFF52C488);
  static const Color amber         = Color(0xFFF0A030);
  static const Color red           = Color(0xFFF06060);

  // Text
  static const Color textPrimary   = Color(0xFFDDE4F0);
  static const Color textSecondary = Color(0xFF6A8AAA);
  static const Color textMuted     = Color(0xFF3A6A8A);

  // Evidence confidence colors
  static Color confidenceHigh   = const Color(0xFF4DC8F0); // ≥90%
  static Color confidenceMed    = const Color(0xFFF0A030); // ≥70%
  static Color confidenceLow    = const Color(0xFFF06060); // <70%

  // Categories
  static const Map<String, Color> categoryColors = {
    'WEAPON':             Color(0xFFF06060),
    'BIOLOGICAL':         Color(0xFF52C488),
    'TRACE':              Color(0xFF4DC8F0),
    'IMPRESSION':         Color(0xFFF0A030),
    'DIGITAL':            Color(0xFF9B59B6),
    'DOCUMENT':           Color(0xFFF39C12),
    'FIRE DEBRIS':        Color(0xFFE74C3C),
    'TOOLMARK':           Color(0xFF1ABC9C),
    'CONTROLLED SUBSTANCE': Color(0xFFE91E63),
    'SCENE OVERVIEW':     Color(0xFF607D8B),
    'OTHER':              Color(0xFF9E9E9E),
  };
}