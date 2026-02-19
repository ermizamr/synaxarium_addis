import '../models/user.dart';

/// Represents the subscription/session lifecycle.
///
/// Stages are explicit to keep selection/submission/pending/active/loggedOut
/// clearly separated as requested.
enum SubscriptionStatus {
  loggedOut,
  selection,
  submission,
  pending,
  active,
}

enum AccessBlockReason {
  none,
  paymentRequired,
  deviceLimit,
  screenshotRequired,
}

class SubscriptionState {
  const SubscriptionState({
    required this.status,
    this.user,
    this.selectedTier,
    this.submittedAt,
    this.approvedAt,
    this.deviceId,
    this.accessAllowed = false,
    this.blockReason = AccessBlockReason.none,
    this.paymentConfirmed,
  });

  final SubscriptionStatus status;
  final User? user;
  final UserTier? selectedTier;
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final String? deviceId;
  final bool accessAllowed;
  final AccessBlockReason blockReason;
  final bool? paymentConfirmed;

  factory SubscriptionState.loggedOut() {
    return const SubscriptionState(status: SubscriptionStatus.loggedOut);
  }

  bool get isActive => status == SubscriptionStatus.active;

  SubscriptionState copyWith({
    SubscriptionStatus? status,
    User? user,
    UserTier? selectedTier,
    DateTime? submittedAt,
    DateTime? approvedAt,
    String? deviceId,
    bool? accessAllowed,
    AccessBlockReason? blockReason,
    bool? paymentConfirmed,
  }) {
    return SubscriptionState(
      status: status ?? this.status,
      user: user ?? this.user,
      selectedTier: selectedTier ?? this.selectedTier,
      submittedAt: submittedAt ?? this.submittedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      deviceId: deviceId ?? this.deviceId,
      accessAllowed: accessAllowed ?? this.accessAllowed,
      blockReason: blockReason ?? this.blockReason,
      paymentConfirmed: paymentConfirmed ?? this.paymentConfirmed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.name,
      'user': user?.toJson(),
      'selectedTier': selectedTier?.name,
      'submittedAt': submittedAt?.toIso8601String(),
      'approvedAt': approvedAt?.toIso8601String(),
      'deviceId': deviceId,
      'accessAllowed': accessAllowed,
      'blockReason': blockReason.name,
      'paymentConfirmed': paymentConfirmed,
    };
  }

  factory SubscriptionState.fromJson(Map<String, dynamic> json) {
    return SubscriptionState(
      status: _statusFromString(json['status'] as String?),
      user: json['user'] == null
          ? null
          : User.fromJson(json['user'] as Map<String, dynamic>),
      selectedTier: _tierFromString(json['selectedTier'] as String?),
      submittedAt: _dateFromString(json['submittedAt'] as String?),
      approvedAt: _dateFromString(json['approvedAt'] as String?),
      deviceId: json['deviceId'] as String?,
      accessAllowed: json['accessAllowed'] as bool? ?? false,
      blockReason: _blockReasonFromString(json['blockReason'] as String?),
      paymentConfirmed: json['paymentConfirmed'] as bool?,
    );
  }

  static DateTime? _dateFromString(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static SubscriptionStatus _statusFromString(String? value) {
    return SubscriptionStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => SubscriptionStatus.loggedOut,
    );
  }

  static UserTier? _tierFromString(String? value) {
    if (value == null || value.isEmpty) return null;
    return UserTier.values.firstWhere(
      (tier) => tier.name == value,
      orElse: () => UserTier.normal,
    );
  }

  static AccessBlockReason _blockReasonFromString(String? value) {
    return AccessBlockReason.values.firstWhere(
      (reason) => reason.name == value,
      orElse: () => AccessBlockReason.none,
    );
  }
}
