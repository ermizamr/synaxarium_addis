import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:synaxarium_addis/data/subscription_controller.dart';
import 'package:synaxarium_addis/data/mock_data.dart';
import 'package:synaxarium_addis/models/feast.dart';
import 'package:synaxarium_addis/models/user.dart';
import 'package:synaxarium_addis/screens/feast_details_screen.dart';

class FeastsListScreen extends ConsumerWidget {
  const FeastsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(subscriptionProvider).valueOrNull;
    final user = session?.user;

    // DEMO users only see first feast
    final visibleFeasts =
        user?.tier == UserTier.demo ? mockFeasts.take(1).toList() : mockFeasts;
    final hiddenCount = user?.tier == UserTier.demo ? mockFeasts.length - 1 : 0;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref
                .read(subscriptionProvider.notifier)
                .refreshProfileAndStatus();
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
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          const Text('ወደኋላ', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.calendar_today,
                              color: Color(0xFF7C3AED),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'የዛሬ በዓላት',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'ጥር 3, 2018',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${mockFeasts.length} በዓላት',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
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
                      // Visible feasts
                      ...visibleFeasts.map(
                        (feast) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildFeastCard(context, feast, user),
                        ),
                      ),
                      // Locked content for DEMO users
                      if (user?.tier == UserTier.demo && hiddenCount > 0) ...[
                        _buildLockedContent(context, hiddenCount),
                        const SizedBox(height: 16),
                      ],
                      // Demo notice
                      if (user?.tier == UserTier.demo &&
                          visibleFeasts.any((f) => f.isPremium))
                        _buildDemoNotice(),
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

  Widget _buildFeastCard(BuildContext context, Feast feast, User? user) {
    final isLocked = feast.isPremium && user?.tier == UserTier.demo;

    return InkWell(
      onTap: isLocked
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FeastDetailsScreen(feast: feast),
                ),
              );
            },
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: isLocked ? 0.6 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(20),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            feast.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isLocked
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF111827),
                            ),
                          ),
                        ),
                        if (isLocked)
                          const Icon(
                            Icons.lock,
                            size: 16,
                            color: Color(0xFF9CA3AF),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      feast.shortDescription,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          label: Text('${feast.churches.length} ቤተክርስቲያናት'),
                          backgroundColor: const Color(0xFFF5F3FF),
                          labelStyle: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7C3AED),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        if (isLocked)
                          const Chip(
                            label: Text('ተከፍሏል'),
                            backgroundColor: Color(0xFFFED7AA),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFC2410C),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right,
                color: isLocked
                    ? const Color(0xFFD1D5DB)
                    : const Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockedContent(BuildContext context, int hiddenCount) {
    return Stack(
      children: [
        // Blurred preview
        Column(
          children: mockFeasts.skip(1).take(2).map((feast) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Opacity(
                  opacity: 0.5,
                  child: Container(
                    padding: const EdgeInsets.all(20),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feast.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          feast.shortDescription,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Chip(
                          label: Text('${feast.churches.length} ቤተክርስቲያናት'),
                          backgroundColor: const Color(0xFFF5F3FF),
                          labelStyle: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        // Overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.8),
                  Colors.white.withValues(alpha: 0.95),
                ],
              ),
            ),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFFBBF24)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, size: 48, color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      '+$hiddenCount ተጨማሪ በዓላት',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ሁሉንም በዓላት ለማየት የደንበኝነት ደረጃዎን ያሻሽሉ',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'NORMAL',
                            style: TextStyle(fontSize: 14, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'FAMILIAR',
                            style: TextStyle(fontSize: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDemoNotice() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFEF3C7), Color(0xFFFEF9C3)],
        ),
        border: Border.all(color: const Color(0xFFFBBF24), width: 2),
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
                  'አንዳንድ በዓላት ለ FAMILIAR እና NORMAL ደንበኞች ብቻ ናቸው። የደንበኝነት ደረጃዎን ያሻሽሉ።',
                  style: TextStyle(fontSize: 14, color: Color(0xFFC2410C)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
