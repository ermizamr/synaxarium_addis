import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;

  static const Duration _requestTimeout = Duration(seconds: 20);

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _client.auth
          .signInWithPassword(email: email, password: password)
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception('Login timed out. Check your connection and try again.');
    }
  }

  Future<String> upsertChurchByCoordinates({
    required String name,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final existing = await _client
          .from('churches')
          .select('id')
          .eq('latitude', latitude)
          .eq('longitude', longitude)
          .limit(1)
          .maybeSingle()
          .timeout(_requestTimeout);

      if (existing != null) {
        await _client
            .from('churches')
            .update({'name': name})
            .eq('id', existing['id'])
            .timeout(_requestTimeout);
        return 'Existing church updated.';
      }

      await _client
          .from('churches')
          .insert({'name': name, 'latitude': latitude, 'longitude': longitude})
          .timeout(_requestTimeout);

      return 'Church added successfully.';
    } on TimeoutException {
      throw Exception(
        'Request timed out. Your data was not confirmed by server.',
      );
    }
  }
}
