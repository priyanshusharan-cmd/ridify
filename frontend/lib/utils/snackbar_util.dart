import 'dart:async';
import 'package:flutter/material.dart';

class SnackbarUtil {
  static Timer? _timer;
  static String? _currentMessage;

  static void show(BuildContext context, String message, {Color? backgroundColor, Duration duration = const Duration(seconds: 4)}) {
    String cleanMessage = cleanErrorText(message);

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    if (_currentMessage == cleanMessage && _timer != null && _timer!.isActive) {
      // Same message, just extend the timer
      _timer!.cancel();
      _timer = Timer(duration, () {
        try {
          messenger.hideCurrentSnackBar();
        } catch (_) {}
        _currentMessage = null;
      });
      return;
    }

    // Different message or no message showing
    _timer?.cancel();
    messenger.clearSnackBars();
    _currentMessage = cleanMessage;

    messenger.showSnackBar(
      SnackBar(
        content: Text(cleanMessage),
        backgroundColor: backgroundColor ?? Colors.grey[800],
        duration: const Duration(days: 1), // Stay open until we close it
      ),
    );

    _timer = Timer(duration, () {
      try {
        messenger.hideCurrentSnackBar();
      } catch (_) {}
      _currentMessage = null;
    });
  }

  static String cleanErrorText(String msg) {
    String cleanMsg = msg.replaceAll('Exception: ', '').trim();
    
    if (cleanMsg.contains('Cast to ObjectId failed') || cleanMsg.contains('CastError')) {
      return "Record not found or invalid.";
    }
    if (cleanMsg.contains('E11000 duplicate key error')) {
      return "This record already exists.";
    }
    if (cleanMsg.contains('jwt expired') || cleanMsg.contains('jwt malformed')) {
      return "Session expired. Please login again.";
    }
    if (cleanMsg.contains('SocketException') || cleanMsg.contains('Connection refused') || cleanMsg.contains('Failed host lookup')) {
      return "Network error. Please check your connection.";
    }
    if (cleanMsg.contains('TimeoutException')) {
      return "Request timed out. Please try again.";
    }
    if (cleanMsg.contains('Unexpected character') || cleanMsg.contains('FormatException')) {
      return "Server error. Please try again later.";
    }
    if (cleanMsg.contains('validation failed')) {
      return "Invalid data provided. Please check your input.";
    }

    if (cleanMsg.contains(RegExp(r'\b[a-fA-F0-9]{24}\b')) || cleanMsg.contains(RegExp(r'0{6,}'))) {
      return "An error occurred with this record.";
    }

    if (cleanMsg.length > 100) {
      return "An unexpected error occurred. Please try again.";
    }
    return cleanMsg;
  }
}
