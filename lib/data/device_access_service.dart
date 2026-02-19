import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceAccessResult {
  const DeviceAccessResult({
    required this.allowed,
    required this.reason,
  });

  final bool allowed;
  final String
      reason; // e.g. device_limit, payment_required, no_active_subscription
}

Future<DeviceAccessResult> checkDeviceAccess({
  required String userId,
  required String deviceId,
  String? phone,
}) async {
  final client = Supabase.instance.client;

  final resp = await client.rpc(
    'allow_device_login',
    params: {
      'p_user_id': userId,
      'p_device_id': deviceId,
      'p_device_info': {
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
    },
  );

  final map = Map<String, dynamic>.from(resp as Map);
  return DeviceAccessResult(
    allowed: map['allowed'] == true,
    reason: (map['reason'] as String?) ?? 'none',
  );
}
