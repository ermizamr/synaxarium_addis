import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

class ScreenshotUploadResult {
  ScreenshotUploadResult({
    required this.filePath,
    required this.signedUrl,
  });

  final String filePath; // storage path
  final String signedUrl; // temporary download URL
}

class ScreenshotService {
  ScreenshotService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  static const _bucket = 'screenshots';

  /// Pick an image from gallery.
  Future<File?> pickScreenshot() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Uploads the screenshot, returns storage path and a signed URL for preview.
  Future<ScreenshotUploadResult> uploadScreenshot({
    required String userId,
    required File file,
  }) async {
    final client = supa.Supabase.instance.client;

    // Ensure we have an auth session (needed for RLS on screenshots/storage).
    await _ensureAuthUser();
    final fileName = file.uri.pathSegments.last;
    final objectPath = '$userId/$fileName';

    // Upload to storage (private bucket). Overwrite if same name exists.
    await client.storage.from(_bucket).uploadBinary(
          objectPath,
          await file.readAsBytes(),
          fileOptions: const supa.FileOptions(upsert: true),
        );

    // Get a signed URL for preview (1 hour expiry).
    final signedUrl = await client.storage.from(_bucket).createSignedUrl(
          objectPath,
          const Duration(hours: 1).inSeconds,
        );

    // Insert DB row
    await client.from('screenshots').insert({
      'user_id': userId,
      'file_path': objectPath,
    });

    return ScreenshotUploadResult(
      filePath: objectPath,
      signedUrl: signedUrl,
    );
  }

  Future<supa.User?> _ensureAuthUser() async {
    final auth = supa.Supabase.instance.client.auth;
    final current = auth.currentUser;
    if (current != null) return current;
    final response = await auth.signInAnonymously();
    return response.user;
  }
}
