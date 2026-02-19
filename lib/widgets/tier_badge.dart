import 'package:flutter/material.dart';

import '../models/user.dart';
import '../theme/app_theme.dart';

class TierBadge extends StatelessWidget {
  const TierBadge({super.key, required this.tier});

  final UserTier tier;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final gradients = {
      UserTier.demo: TierColors.demoGradient,
      UserTier.normal: TierColors.normalGradient,
      UserTier.familiar: TierColors.vipGradient,
    };
    final labels = {
      UserTier.demo: 'DEMO',
      UserTier.normal: 'NORMAL',
      UserTier.familiar: 'FAMILIAR',
    };
    final colors = gradients[tier]!;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.surface, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          labels[tier]!,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
