import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'safe_logger.dart';

/// Helper for secure clipboard operations with an automatic 30-second clearance timeout.
class ClipboardHelper {
  ClipboardHelper._();

  static Timer? _clearTimer;
  static String? _lastCopiedSensitiveText;

  /// Copies sensitive text to clipboard and schedules automatic clearing after 30 seconds.
  static Future<void> copySensitive({
    required BuildContext context,
    required String text,
    String feedbackMessage = 'Password copied to clipboard (clears in 30s)',
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    _lastCopiedSensitiveText = text;

    _clearTimer?.cancel();
    _clearTimer = Timer(const Duration(seconds: 30), () async {
      final currentData = await Clipboard.getData(Clipboard.kTextPlain);
      if (currentData?.text == _lastCopiedSensitiveText) {
        await Clipboard.setData(const ClipboardData(text: ''));
        SafeLogger.info(
          'ClipboardHelper',
          'Sensitive clipboard cleared after 30-second timeout',
        );
      }
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF86F2E4),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  feedbackMessage,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0B1C30),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Copies non-sensitive text (like usernames, URLs) without auto-clear.
  static Future<void> copyPublic({
    required BuildContext context,
    required String text,
    required String label,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label copied to clipboard'),
          backgroundColor: const Color(0xFF0B1C30),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
