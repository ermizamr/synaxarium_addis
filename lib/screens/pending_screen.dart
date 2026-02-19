import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/subscription_controller.dart';
import '../data/subscription_state.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';
import 'access_blocked_screen.dart';

class PendingScreen extends ConsumerStatefulWidget {
  const PendingScreen({super.key});

  static const routeName = '/pending';

  @override
  ConsumerState<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends ConsumerState<PendingScreen> {
  bool _checking = false;
  String? _statusMessage;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(hours: 1), (_) async {
      await _checkApproval();
    });
    // Immediate first check
    _checkApproval();
  }

  Future<void> _checkApproval() async {
    if (_checking) return;
    setState(() => _checking = true);

    final notifier = ref.read(subscriptionProvider.notifier);
    final updated = await notifier.refreshProfileAndStatus();

    if (!mounted) return;
    setState(() => _checking = false);

    if (updated.status == SubscriptionStatus.active) {
      if (updated.accessAllowed) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AccessBlockedScreen()),
        );
      }
      return;
    }

    if (updated.blockReason == AccessBlockReason.screenshotRequired) {
      setState(() => _statusMessage = 'እየተጠበቀ ነው፤ ስክሪንሾቱ እስካልተፈቀደ ድረስ ይጠብቁ');
    } else if (updated.blockReason == AccessBlockReason.deviceLimit) {
      setState(() => _statusMessage = 'የመሣሪያ ገደብ ሞልቷል፤ ድጋፍ ያግኙ');
    } else {
      setState(() => _statusMessage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(subscriptionProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _checkApproval,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF5F3FF), Colors.white],
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
                      colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.hourglass_top,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'በመጠባበቅ ላይ',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                const Text(
                  'መረጃዎን ተቀብለናል። አስተዳደር ስክሪንሾቱን እስኪፈቅድ ድረስ እዚህ ይጠብቁ።',
                  style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _statusMessage!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _checking ? null : _checkApproval,
                  icon: const Icon(Icons.refresh),
                  label: Text(_checking ? 'እየተመለከተ ነው...' : 'ሁኔታ አድስ'),
                ),
                const SizedBox(height: 12),
                if (session?.status == SubscriptionStatus.pending &&
                    session?.user != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ተመዝግቧል',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('ስም፡ ${session!.user!.name}'),
                        Text('ስልክ፡ ${session.user!.phone}'),
                        Text('ደረጃ፡ ${session.user!.tier.name.toUpperCase()}'),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
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
                  label: const Text('ውጣ'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
