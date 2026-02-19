import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'screenshot_service.dart';

import '../models/user.dart';
import 'device_access_service.dart';
import 'device_service.dart';
import 'subscription_state.dart';

/// Riverpod controller that owns the subscription lifecycle and persistence.
final subscriptionProvider =
    AsyncNotifierProvider<SubscriptionController, SubscriptionState>(
  SubscriptionController.new,
);

final deviceServiceProvider = Provider<DeviceService>((ref) {
  return DeviceService();
});

class AccessDecision {
  const AccessDecision({
    required this.allowed,
    this.blockReason = AccessBlockReason.none,
    this.paymentConfirmed = false,
  });

  final bool allowed;
  final AccessBlockReason blockReason;
  final bool paymentConfirmed;
}

class ActiveSubscriptionExists implements Exception {
  ActiveSubscriptionExists(
      [this.message = 'You already have an active subscription.']);
  final String message;

  @override
  String toString() => message;
}

class InactiveSubscriptionExists implements Exception {
  InactiveSubscriptionExists(this.status,
      [this.message = 'Your subscription is inactive/expired.']);
  final String status;
  final String message;

  @override
  String toString() => '$message (status: $status)';
}

class DemoNotAllowed implements Exception {
  DemoNotAllowed(
      [this.message = 'Demo access is not available for this account.']);
  final String message;

  @override
  String toString() => message;
}

class PhoneAlreadyRegistered implements Exception {
  PhoneAlreadyRegistered(
      [this.message =
          'This phone number is already linked to another account. Contact support to recover access.']);
  final String message;

  @override
  String toString() => message;
}

class PhoneRecoveryFailed implements Exception {
  PhoneRecoveryFailed(this.message);
  final String message;

  @override
  String toString() => message;
}

class SubscriptionController extends AsyncNotifier<SubscriptionState> {
  static const _prefsKey = 'subscription_state_v1';

  @override
  Future<SubscriptionState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return SubscriptionState.loggedOut();
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      var restored = SubscriptionState.fromJson(decoded);

      // Security/consistency guard:
      // Never auto-restore pending/submission sessions for non-demo users.
      // User must re-enter phone and fetch canonical status from backend.
      if (restored.user?.tier != UserTier.demo &&
          (restored.status == SubscriptionStatus.pending ||
              restored.status == SubscriptionStatus.submission)) {
        await prefs.remove(_prefsKey);
        return SubscriptionState.loggedOut();
      }

      final refreshedUser = await _fetchCanonicalProfileUser();
      if (refreshedUser != null) {
        restored = restored.copyWith(
          user: refreshedUser,
          selectedTier: refreshedUser.tier,
        );
      }

      if ((restored.status == SubscriptionStatus.active ||
              restored.status == SubscriptionStatus.pending) &&
          restored.user != null) {
        restored = await _verifyDeviceAccess(restored);
      }

      return restored;
    } catch (_) {
      return SubscriptionState.loggedOut();
    }
  }

  Future<void> selectTier(UserTier tier) async {
    final current = state.requireValue;
    final next = current.copyWith(
      status: SubscriptionStatus.selection,
      selectedTier: tier,
    );
    state = AsyncValue.data(next);
    await _persist(next);
  }

  /// Submits credentials + screenshot metadata (stored as user info only).
  /// Moves state from `submission` to `pending` without opening the app.
  Future<void> submit({
    required String name,
    required String phone,
    String? promoCode,
    required UserTier tier,
    required String screenshotPath,
  }) async {
    final current = state.requireValue;

    final authUser = await _ensureAuthUser();
    if (authUser == null) {
      return;
    }

    final recovered = await _recoverOrValidatePhoneForCurrentUser(
      phone: phone,
      currentUserId: authUser.id,
    );

    if (recovered) {
      await refreshProfileAndStatus();
      return;
    }

    final user = User(
      id: authUser.id,
      name: name,
      phone: phone,
      tier: tier,
      promoCode: promoCode?.isEmpty == true ? null : promoCode,
    );

    try {
      await _syncProfileAndSubscription(user, createSubscription: false);
    } on ActiveSubscriptionExists {
      await refreshProfileAndStatus();
      return;
    }

    // Upload screenshot as part of submission (mandatory proof).
    final screenshot = await _uploadScreenshot(user.id!, screenshotPath);

    await _recordSubmission(user, screenshot?.filePath);

    final submitting = current.copyWith(
      status: SubscriptionStatus.submission,
      user: user,
      selectedTier: tier,
    );
    state = AsyncValue.data(submitting);
    await _persist(submitting);

    final pending = submitting.copyWith(
      status: SubscriptionStatus.pending,
      submittedAt: DateTime.now(),
    );
    state = AsyncValue.data(pending);
    await _persist(pending);
  }

  /// Login/recover existing account by phone without requiring a new screenshot upload.
  Future<void> loginWithPhone({required String phone}) async {
    final normalized = phone.trim();
    if (normalized.isEmpty) {
      throw PhoneRecoveryFailed('Please enter your phone number.');
    }

    final authUser = await _ensureAuthUser();
    if (authUser == null) {
      throw PhoneRecoveryFailed('Unable to start session. Please try again.');
    }

    final client = supa.Supabase.instance.client;
    final existingUserId = await client.rpc('get_user_id_by_phone', params: {
      'p_phone': normalized,
    });

    if (existingUserId is! String || existingUserId.isEmpty) {
      throw PhoneRecoveryFailed(
          'No account found for this phone number. Please register and upload payment proof.');
    }

    final recovered = await _recoverOrValidatePhoneForCurrentUser(
      phone: normalized,
      currentUserId: authUser.id,
    );

    var canonicalUserId = existingUserId;
    if (recovered) {
      final resolvedUserId = await client.rpc('get_user_id_by_phone', params: {
        'p_phone': normalized,
      });

      if (resolvedUserId is String && resolvedUserId.isNotEmpty) {
        canonicalUserId = resolvedUserId;
      } else {
        canonicalUserId = authUser.id;
      }
    }

    await _restoreStateForKnownPhoneUser(
      userId: canonicalUserId,
      phone: normalized,
    );
  }

  Future<void> _restoreStateForKnownPhoneUser({
    required String userId,
    required String phone,
  }) async {
    final client = supa.Supabase.instance.client;

    Map<String, dynamic>? profile;
    Map<String, dynamic>? submission;
    try {
      profile = await client
          .from('user_profiles')
          .select('name, phone, tier, promo_code')
          .eq('user_id', userId)
          .maybeSingle();
    } catch (e) {
      debugPrint('Profile snapshot fetch failed: $e');
    }

    try {
      submission = await client
          .from('submissions')
          .select('name, phone, tier, promo_code, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
    } catch (e) {
      debugPrint('Submission snapshot fetch failed: $e');
    }

    final rawTier = ((profile?['tier'] as String?) ??
            (submission?['tier'] as String?) ??
            'normal')
        .toLowerCase();
    final tierName = rawTier == 'vip' ? 'familiar' : rawTier;
    final tier = UserTier.values.firstWhere(
      (t) => t.name == tierName,
      orElse: () => UserTier.normal,
    );

    final user = User(
      id: userId,
      name: (profile?['name'] as String?) ??
          (submission?['name'] as String?) ??
          '',
      phone: (profile?['phone'] as String?) ??
          (submission?['phone'] as String?) ??
          phone,
      tier: tier,
      promoCode: (profile?['promo_code'] as String?) ??
          (submission?['promo_code'] as String?),
    );

    final subscriptionStatus = await _fetchLatestSubscriptionStatus(userId);
    final hasSubmission = submission != null;

    SubscriptionState next;
    if (subscriptionStatus == 'active') {
      next = SubscriptionState(
        status: SubscriptionStatus.active,
        user: user,
        selectedTier: user.tier,
        approvedAt: DateTime.now(),
      );
      next = await _verifyDeviceAccess(next);
    } else if (subscriptionStatus == 'expired' ||
        subscriptionStatus == 'cancelled') {
      next = SubscriptionState(
        status: SubscriptionStatus.active,
        user: user,
        selectedTier: user.tier,
        accessAllowed: false,
        blockReason: AccessBlockReason.paymentRequired,
      );
    } else if (hasSubmission) {
      next = SubscriptionState(
        status: SubscriptionStatus.pending,
        user: user,
        selectedTier: user.tier,
        submittedAt: DateTime.now(),
        accessAllowed: false,
        blockReason: AccessBlockReason.screenshotRequired,
      );
    } else {
      next = SubscriptionState(
        status: SubscriptionStatus.selection,
        user: user,
        selectedTier: user.tier,
        accessAllowed: false,
        blockReason: AccessBlockReason.none,
      );
    }

    state = AsyncValue.data(next);
    await _persist(next);
  }

  /// Admin approval should call this (no backend wiring yet).
  Future<void> approve() async {
    final current = state.requireValue;
    if (current.user == null) return;

    // Ensure backend subscription exists before approving locally.
    await _syncProfileAndSubscription(current.user!);

    final now = DateTime.now();
    final next = current.copyWith(
      status: SubscriptionStatus.active,
      approvedAt: now,
    );
    final verified = await _verifyDeviceAccess(next);
    state = AsyncValue.data(verified);
    await _persist(verified);
  }

  /// Demo access is allowed without approval (kept for existing UI).
  Future<void> activateDemo() async {
    final current = state.valueOrNull;
    // Allow demo unless we are already active and allowed.
    if (current != null &&
        current.status == SubscriptionStatus.active &&
        current.accessAllowed) {
      throw DemoNotAllowed(
          'Demo is unavailable while your subscription is active.');
    }

    final now = DateTime.now();
    final demo = SubscriptionState(
      status: SubscriptionStatus.active,
      user: User.demo(),
      selectedTier: UserTier.demo,
      approvedAt: now,
      accessAllowed: true,
      blockReason: AccessBlockReason.none,
    );
    state = AsyncValue.data(demo);
    await _persist(demo);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    state = AsyncValue.data(SubscriptionState.loggedOut());
  }

  Future<void> _persist(SubscriptionState value,
      [SharedPreferences? prefs]) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    await store.setString(_prefsKey, jsonEncode(value.toJson()));
  }

  Future<SubscriptionState> _verifyDeviceAccess(
      SubscriptionState current) async {
    final user = current.user;
    if (user == null) return current.copyWith(accessAllowed: false);

    final deviceId = await ref.read(deviceServiceProvider).getDeviceId();

    // Supabase device binding.
    final decision = await _supabaseDecision(user, deviceId);

    var next = current.copyWith(
      deviceId: deviceId,
      accessAllowed: decision.allowed,
      blockReason: decision.blockReason,
      paymentConfirmed: decision.paymentConfirmed,
    );

    final backendStatus =
        user.id == null ? null : await _fetchLatestSubscriptionStatus(user.id!);
    final backendActive = backendStatus == 'active';

    if (!backendActive) {
      final isExpiredOrCancelled =
          backendStatus == 'expired' || backendStatus == 'cancelled';

      final downgradedStatus = next.status == SubscriptionStatus.active
          ? SubscriptionStatus.pending
          : next.status;

      return next.copyWith(
        status: downgradedStatus,
        accessAllowed: false,
        blockReason: isExpiredOrCancelled
            ? AccessBlockReason.paymentRequired
            : AccessBlockReason.screenshotRequired,
      );
    }

    if (decision.allowed &&
        next.status != SubscriptionStatus.active &&
        backendActive) {
      next = next.copyWith(
        status: SubscriptionStatus.active,
        approvedAt: next.approvedAt ?? DateTime.now(),
      );
      // Persist promotion to active
      await _persist(next);
    }
    return next;
  }

  Future<String?> _fetchLatestSubscriptionStatus(String userId) async {
    final client = supa.Supabase.instance.client;

    try {
      final row = await client
          .from('subscriptions')
          .select('status')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return row == null ? null : row['status'] as String?;
    } catch (e) {
      debugPrint('Subscription status fetch failed: $e');
      return null;
    }
  }

  /// Re-fetch device access/approval status while pending or active.
  Future<SubscriptionState> refreshStatus() async {
    final current = state.requireValue;

    // Only meaningful when user exists and status is pending/submission/active.
    if (current.user == null ||
        (current.status != SubscriptionStatus.pending &&
            current.status != SubscriptionStatus.submission &&
            current.status != SubscriptionStatus.active)) {
      return current;
    }

    final updated = await _verifyDeviceAccess(current);
    state = AsyncValue.data(updated);
    await _persist(updated);
    return updated;
  }

  /// Refresh profile (name/phone/tier) from Supabase then re-run access check.
  Future<SubscriptionState> refreshProfileAndStatus() async {
    final refreshedUser = await _fetchCanonicalProfileUser();

    final current = state.requireValue;
    if (refreshedUser == null &&
        current.user?.tier != UserTier.demo &&
        (current.status == SubscriptionStatus.pending ||
            current.status == SubscriptionStatus.submission)) {
      final reset = SubscriptionState.loggedOut();
      state = AsyncValue.data(reset);
      await _persist(reset);
      return reset;
    }

    final mergedUser = refreshedUser ?? current.user;
    var next = current.copyWith(
      user: mergedUser,
      selectedTier: mergedUser?.tier ?? current.selectedTier,
    );

    next = await _verifyDeviceAccess(next);
    state = AsyncValue.data(next);
    await _persist(next);
    return next;
  }

  Future<User?> _fetchCanonicalProfileUser() async {
    final authUser = await _ensureAuthUser();
    if (authUser == null) return null;

    final client = supa.Supabase.instance.client;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final profile = await client
            .from('user_profiles')
            .select('name, phone, tier, promo_code')
            .eq('user_id', authUser.id)
            .maybeSingle();

        if (profile == null) return null;

        final rawTierName =
            ((profile['tier'] as String?) ?? 'normal').toLowerCase();
        final tierName = rawTierName == 'vip' ? 'familiar' : rawTierName;
        final tier = UserTier.values.firstWhere(
          (t) => t.name == tierName,
          orElse: () => UserTier.normal,
        );

        return User(
          id: authUser.id,
          name: profile['name'] as String? ?? '',
          phone: profile['phone'] as String? ?? '',
          tier: tier,
          promoCode: profile['promo_code'] as String?,
        );
      } catch (e) {
        final isLastAttempt = attempt == 1;
        final transient = _isTransientNetworkError(e);
        debugPrint('Profile fetch failed (attempt ${attempt + 1}): $e');

        if (isLastAttempt || !transient) {
          return null;
        }

        await Future<void>.delayed(const Duration(milliseconds: 450));
      }
    }

    return null;
  }

  bool _isTransientNetworkError(Object error) {
    if (error is SocketException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('connection reset by peer') ||
        text.contains('connection reset') ||
        text.contains('failed host lookup') ||
        text.contains('timeout');
  }

  Future<AccessDecision> _supabaseDecision(User user, String deviceId) async {
    final authUser = await _ensureAuthUser();
    if (authUser == null || user.id == null) {
      return const AccessDecision(
        allowed: false,
        blockReason: AccessBlockReason.paymentRequired,
      );
    }

    final result = await checkDeviceAccess(
      userId: user.id!,
      deviceId: deviceId,
      phone: user.phone,
    );

    final reason = switch (result.reason) {
      'device_limit' => AccessBlockReason.deviceLimit,
      'payment_required' => AccessBlockReason.paymentRequired,
      'no_active_subscription' => AccessBlockReason.paymentRequired,
      'phone_mismatch' => AccessBlockReason.paymentRequired,
      'phone_required' => AccessBlockReason.paymentRequired,
      'screenshot_not_approved' => AccessBlockReason.screenshotRequired,
      'device_limit_reached' => AccessBlockReason.deviceLimit,
      _ => AccessBlockReason.none,
    };

    return AccessDecision(
      allowed: result.allowed,
      blockReason: reason,
      paymentConfirmed: state.value?.paymentConfirmed ?? false,
    );
  }

  Future<supa.User?> _ensureAuthUser() async {
    final auth = supa.Supabase.instance.client.auth;
    final current = auth.currentUser;

    if (current != null) {
      try {
        final refreshed = await auth.getUser();
        final refreshedUser = refreshed.user;
        if (refreshedUser != null) {
          return refreshedUser;
        }
      } catch (e) {
        debugPrint(
            'Current auth user is invalid or expired, creating a fresh anonymous user: $e');
        try {
          await auth.signOut();
        } catch (_) {}
      }
    }

    final response = await auth.signInAnonymously();
    return response.user;
  }

  Future<bool> _recoverOrValidatePhoneForCurrentUser({
    required String phone,
    required String currentUserId,
  }) async {
    final normalized = phone.trim();
    if (normalized.isEmpty) return false;

    final client = supa.Supabase.instance.client;
    final existingUserId = await client.rpc('get_user_id_by_phone', params: {
      'p_phone': normalized,
    });

    if (existingUserId is String &&
        existingUserId.isNotEmpty &&
        existingUserId != currentUserId) {
      final deviceId = await ref.read(deviceServiceProvider).getDeviceId();
      final result = await client.rpc('claim_account_by_phone', params: {
        'p_phone': normalized,
        'p_device_id': deviceId,
        'p_device_info': <String, dynamic>{
          'source': 'mobile_recovery',
        },
      });

      final map = Map<String, dynamic>.from(result as Map);
      final recovered = map['recovered'] == true;
      if (recovered) {
        return true;
      }

      final reason = (map['reason'] as String?) ?? 'phone_in_use';
      switch (reason) {
        case 'device_limit_reached':
          throw PhoneRecoveryFailed(
              'This phone is already active on the maximum number of devices. Contact support to reset devices.');
        case 'device_blocked':
          throw PhoneRecoveryFailed(
              'This device is blocked for the account linked to this phone number.');
        case 'no_active_subscription':
          throw PhoneRecoveryFailed(
              'This phone is linked to an account without an active subscription.');
        case 'screenshot_not_approved':
          throw PhoneRecoveryFailed(
              'This phone is linked to an account still pending screenshot approval.');
        default:
          throw PhoneAlreadyRegistered();
      }
    }

    return false;
  }

  Future<void> _syncProfileAndSubscription(User user,
      {bool createSubscription = true}) async {
    if (user.id == null) return;
    final client = supa.Supabase.instance.client;

    final effectivePromoCode =
        await _resolveLockedPromoCode(user.id!, user.promoCode);

    // Ensure session alive for RLS
    final authUser = await _ensureAuthUser();
    if (authUser == null || authUser.id != user.id) {
      debugPrint('Supabase auth missing or mismatched before sync');
      return;
    }

    try {
      await client.from('users').upsert({'id': user.id});

      await client.from('user_profiles').upsert({
        'user_id': user.id,
        'name': user.name,
        'phone': user.phone,
        'tier': user.tier.name,
        'promo_code': effectivePromoCode,
      });

      if (createSubscription) {
        await _ensureSubscription(user.id!, user.tier);
      }
    } on ActiveSubscriptionExists {
      rethrow;
    } on InactiveSubscriptionExists {
      rethrow;
    } on supa.PostgrestException catch (e) {
      if (e.code == '23505') {
        throw PhoneAlreadyRegistered();
      }
      debugPrint('Supabase sync failed: $e');
      rethrow;
    } catch (e) {
      debugPrint('Supabase sync failed: $e');
      rethrow;
    }
  }

  Future<ScreenshotUploadResult?> _uploadScreenshot(
      String userId, String path) async {
    try {
      final file = File(path);
      final svc = ScreenshotService();
      return await svc.uploadScreenshot(userId: userId, file: file);
    } catch (e) {
      debugPrint('Screenshot upload failed: $e');
      return null;
    }
  }

  Future<void> _recordSubmission(User user, String? screenshotPath) async {
    if (user.id == null) return;
    final client = supa.Supabase.instance.client;

    final effectivePromoCode =
        await _resolveLockedPromoCode(user.id!, user.promoCode);

    try {
      // Upsert to keep a single submission per user until admin reviews.
      await client.from('submissions').upsert({
        'user_id': user.id,
        'name': user.name,
        'phone': user.phone,
        'tier': user.tier.name,
        'promo_code': effectivePromoCode,
        'screenshot_path': screenshotPath,
      }, onConflict: 'user_id');
    } on supa.PostgrestException catch (e) {
      if (e.code == '23505') {
        throw PhoneAlreadyRegistered();
      }
      debugPrint('Submission record insert failed: $e');
      rethrow;
    } catch (e) {
      debugPrint('Submission record insert failed: $e');
      rethrow;
    }
  }

  Future<String?> _resolveLockedPromoCode(
      String userId, String? incomingPromoCode) async {
    final client = supa.Supabase.instance.client;

    try {
      final profile = await client
          .from('user_profiles')
          .select('promo_code')
          .eq('user_id', userId)
          .maybeSingle();

      final submission = await client
          .from('submissions')
          .select('promo_code')
          .eq('user_id', userId)
          .maybeSingle();

      final hasProfileRow = profile != null;
      final hasSubmissionRow = submission != null;

      // Promo code is immutable after first registration footprint exists.
      if (hasProfileRow || hasSubmissionRow) {
        return (profile?['promo_code'] as String?) ??
            (submission?['promo_code'] as String?);
      }

      final trimmed = incomingPromoCode?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    } catch (e) {
      debugPrint('Promo lock resolution failed: $e');
      final trimmed = incomingPromoCode?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    }
  }

  Future<void> _ensureSubscription(String userId, UserTier tier) async {
    final client = supa.Supabase.instance.client;

    final existing = await client
        .from('subscriptions')
        .select('id, status')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      final status = (existing['status'] as String?) ?? '';
      if (status == 'active') {
        throw ActiveSubscriptionExists();
      } else {
        throw InactiveSubscriptionExists(status.isEmpty ? 'unknown' : status,
            'Subscription is not active. Contact support to renew.');
      }
    }

    await client.from('subscriptions').insert({
      'user_id': userId,
      'status': 'active',
      'current_period_end': null,
    });
  }
}
