import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:synaxarium_addis/data/subscription_controller.dart';
import 'package:synaxarium_addis/data/subscription_state.dart';
import 'package:synaxarium_addis/data/mock_data.dart';
import 'package:synaxarium_addis/models/user.dart';
import 'package:synaxarium_addis/screens/about_screen.dart';
import 'package:synaxarium_addis/screens/access_blocked_screen.dart';
import 'package:synaxarium_addis/screens/churches_list_screen.dart';
import 'package:synaxarium_addis/screens/feasts_list_screen.dart';
import 'package:synaxarium_addis/screens/onboarding_screen.dart';
import 'package:synaxarium_addis/screens/pending_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const routeName = '/home';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(subscriptionProvider);
    if (sessionAsync.isLoading) {
      return const SizedBox.shrink();
    }
    final session = sessionAsync.valueOrNull;
    final user = session?.user;
    final nearbyChurches = mockChurches.where((c) => c.distance <= 3).toList();

    // Guard: render only when explicitly allowed; otherwise show appropriate gate screen.
    if (session == null || session.status != SubscriptionStatus.active) {
      if (session?.status == SubscriptionStatus.pending ||
          session?.status == SubscriptionStatus.submission) {
        return const PendingScreen();
      }
      return const OnboardingScreen();
    }

    if (session.accessAllowed != true) {
      if (session.blockReason == AccessBlockReason.screenshotRequired ||
          session.blockReason == AccessBlockReason.paymentRequired) {
        return const PendingScreen();
      }
      return const AccessBlockedScreen();
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final updated = await ref
                .read(subscriptionProvider.notifier)
                .refreshProfileAndStatus();

            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  updated.accessAllowed ? 'ሁኔታ ተዘምኗል' : 'መዳረሻ ተከልክሏል',
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
                colors: [Color(0xFFF5F3FF), Colors.white],
              ),
            ),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // Header
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ስንክሳር አዲስ',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'እንኳን ደህና መጡ',
                              style: TextStyle(
                                fontSize: 20,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            if (user != null && user.name.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              Text(
                                user.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              if (user.phone.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  user.phone,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ],
                            // Register button for DEMO users
                            if (user?.tier == UserTier.demo) ...[
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () {
                                  ref
                                      .read(subscriptionProvider.notifier)
                                      .logout();
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => const OnboardingScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.logout, size: 20),
                                label: const Text('መመዝገብ'),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFED7AA),
                                  foregroundColor: const Color(0xFFC2410C),
                                  side: BorderSide.none,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Right side
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AboutView(
                                    previousRoute: HomeScreen.routeName,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.info, size: 20),
                            label: const Text('ስለ መተግበሪያው'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFF3F4F6),
                              foregroundColor: const Color(0xFF374151),
                              side: BorderSide.none,
                            ),
                          ),
                          if (user != null) ...[
                            const SizedBox(height: 32),
                            _buildTierBadge(user.tier),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Today's Feasts Card
                      _buildFeastsCard(context, mockFeasts.length),
                      const SizedBox(height: 20),
                      // Nearby Churches Card
                      _buildChurchesCard(context, nearbyChurches.length),
                      const SizedBox(height: 20),
                      // Demo notice
                      if (user?.tier == UserTier.demo)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFEF3C7), Color(0xFFFEF9C3)],
                            ),
                            border: Border.all(
                              color: const Color(0xFFFBBF24),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lock, color: Color(0xFFF97316)),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'የማሳያ ደረጃ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF78350F),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'ሁሉንም ይዘቶች ለማግኘት የደንበኝነት ደረጃዎን ያሻሽሉ',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFFC2410C),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTierBadge(UserTier tier) {
    LinearGradient gradient;
    String label;

    switch (tier) {
      case UserTier.demo:
        gradient = const LinearGradient(
          colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)],
        );
        label = 'DEMO';
        break;
      case UserTier.normal:
        gradient = const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
        );
        label = 'REGULAR';
        break;
      case UserTier.familiar:
        gradient = const LinearGradient(
          colors: [Color(0xFFFBBF24), Color(0xFFF97316)],
        );
        label = 'FAMILIAR';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildFeastsCard(BuildContext context, int count) {
    return InkWell(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const FeastsListScreen()));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.calendar_today,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'የዛሬ በዓላት',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'ጥር 3, 2018',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$count በዓላት',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 24,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFDCEEFE), Color(0xFFF5F3FF)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: const Text(
                'በዛሬው ቀን የሚከበሩ የቤተክርስቲያን በዓላትን ይመልከቱ',
                style: TextStyle(fontSize: 14, color: Color(0xFF374151)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChurchesCard(BuildContext context, int count) {
    return InkWell(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ChurchesListScreen()));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF14B8A6)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.church,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'አቅራቢያዎ ያሉ ቤተክርስቲያናት',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'በ3 ኪ.ሜ ራዲየስ',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$count ቤ/ክ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 24,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFECFDF5), Color(0xFFCFFAFE)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: const Text(
                'በአቅራቢያዎ ያሉ ቤተክርስቲያናትን ያግኙ',
                style: TextStyle(fontSize: 14, color: Color(0xFF374151)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
