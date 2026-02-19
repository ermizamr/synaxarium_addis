import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Global client (avoid re-initializing; Supabase.initialize is done in main.dart)
final supabase = Supabase.instance.client;

/// Riverpod provider for DI
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
