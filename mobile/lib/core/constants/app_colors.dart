import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF0B4D58);
  static const Color primaryDark = Color(0xFF07333B);
  static const Color primaryLight = Color(0xFFE8F3F5);

  static const Color accent = Color(0xFFB75307);
  static const Color accentDark = Color(0xFF9C4205);
  static const Color accentLight = Color(0xFFFFF7ED);

  static const Color background = Color(0xFFFAF9F5);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderSubtle = Color(0xFFCBD5E1);

  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color success = Color(0xFF15803D);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFB45309);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFB91C1C);
  static const Color dangerLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF0369A1);
  static const Color infoLight = Color(0xFFE0F2FE);

  // Status colors mapping
  static Color getStatusColor(String status) {
    switch (status) {
      case 'Diterima':
        return const Color(0xFF6366F1); // Indigo
      case 'Ditimbang':
        return const Color(0xFF0EA5E9); // Sky
      case 'Dicuci':
        return const Color(0xFF0284C7); // Light Blue
      case 'Disetrika':
        return const Color(0xFF8B5CF6); // Purple
      case 'Siap':
        return const Color(0xFFF59E0B); // Amber
      case 'Diambil':
        return const Color(0xFF14B8A6); // Teal
      case 'Lunas':
      case 'Selesai':
      case 'Disetujui':
        return const Color(0xFF10B981); // Emerald
      case 'Diajukan':
        return const Color(0xFF0284C7); // Light Blue
      case 'Ditinjau':
        return const Color(0xFFF59E0B); // Amber
      case 'Tidak Diambil':
      case 'Dibatalkan':
      case 'Ditolak':
        return const Color(0xFFEF4444); // Red
      default:
        return textSecondary;
    }
  }

  static Color getStatusBgColor(String status) {
    return getStatusColor(status).withValues(alpha: 0.12);
  }
}
