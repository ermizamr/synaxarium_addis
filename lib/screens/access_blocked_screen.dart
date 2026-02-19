import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/subscription_controller.dart';
import '../data/subscription_state.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class AccessBlockedScreen extends ConsumerWidget {
  const AccessBlockedScreen({super.key});

  static const routeName = '/access-blocked';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(subscriptionProvider).valueOrNull;
    final reason = session?.blockReason ?? AccessBlockReason.paymentRequired;

    final title = switch (reason) {
      AccessBlockReason.paymentRequired => 'Payment required',
      AccessBlockReason.deviceLimit => 'Device limit reached',
      AccessBlockReason.screenshotRequired => 'Screenshot not approved yet',
      _ => 'Access blocked',
    };

    final message = switch (reason) {
      AccessBlockReason.paymentRequired =>
        'Payment is not confirmed for this account. Please complete the one-time payment to continue.',
      AccessBlockReason.deviceLimit =>
        'You have reached the maximum number of devices for your subscription. Contact support to free a device or upgrade.',
      AccessBlockReason.screenshotRequired =>
        'Your screenshot is still waiting for admin approval. We will unlock access once it is approved.',
      _ => 'Access is currently blocked. Please try again later.',
    };

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final updated = await ref
                .read(subscriptionProvider.notifier)
                .refreshProfileAndStatus();

            if (!context.mounted) return;

            if (updated.accessAllowed &&
                updated.status == SubscriptionStatus.active) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
              return;
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  updated.blockReason == AccessBlockReason.paymentRequired
                      ? 'Payment still required'
                      : 'Access still blocked',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFEE2E2), Colors.white],
              ),
            ),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 32),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.block,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style:
                      const TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
                ),
                if (session?.deviceId != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Device ID: ${session!.deviceId}',
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                ],
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(subscriptionProvider.notifier).logout();
                    if (context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const OnboardingScreen(),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
