import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorHandler {
  static String getMessage(dynamic error) {
    String errorStr = error.toString().toLowerCase();

    // Internet and Network issues
    if (error is SocketException || 
        errorStr.contains('socketexception') || 
        errorStr.contains('network') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('failed to connect') ||
        errorStr.contains('unreachable')) {
      return 'No internet connection. Please check your network and try again.';
    }

    // Timeout
    if (errorStr.contains('timeoutexception') || errorStr.contains('timeout')) {
      return 'Connection timeout. Please try again.';
    }

    // Supabase Auth Errors
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials') || msg.contains('invalid claim')) {
        return 'Invalid student number or password.';
      }
      if (msg.contains('too many requests') || msg.contains('rate limit')) {
        return 'Too many attempts. Please try again later.';
      }
      if (msg.contains('network') || msg.contains('connection')) {
        return 'Network error. Please check your connection.';
      }
      // Instead of returning error.message directly, return a generic one if it looks technical
      return 'Authentication failed. Please check your details.';
    }

    // Supabase Database Errors (Postgrest)
    if (error is PostgrestException) {
      // Humanize common database errors
      if (error.code == '23505') return 'This record already exists.';
      if (error.code == '42P01' || error.code == 'P0001') return 'The requested resource is currently unavailable.';
      
      // If the error message from database is technical, hide it
      return 'Database error. Please try again later.';
    }

    // Default fallback for any other errors
    return 'An unexpected error occurred. Please try again.';
  }
}
