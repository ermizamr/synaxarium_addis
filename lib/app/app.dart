import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/home_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/pending_screen.dart';
import '../screens/access_blocked_screen.dart';
import '../screens/splash_screen.dart';
import '../theme/app_theme.dart';

class SynaxariumApp extends StatelessWidget {
  const SynaxariumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'ስንክሳር አዲስ',
        debugShowCheckedModeBanner: false,
        locale: const Locale('am'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('am'), Locale('en')],
        theme: AppTheme.lightTheme,
        initialRoute: SplashScreen.routeName,
        routes: {
          SplashScreen.routeName: (_) => const SplashScreen(),
          OnboardingScreen.routeName: (_) => const OnboardingScreen(),
          HomeScreen.routeName: (_) => const HomeScreen(),
          PendingScreen.routeName: (_) => const PendingScreen(),
          AccessBlockedScreen.routeName: (_) => const AccessBlockedScreen(),
        },
      ),
    );
  }
}
