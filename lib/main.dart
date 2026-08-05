import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/ai_provider.dart';
import 'providers/alert_provider.dart';
import 'providers/audit_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/discord_provider.dart';
import 'providers/layout_provider.dart';
import 'providers/news_provider.dart';
import 'providers/report_studio_provider.dart';
import 'providers/risk_desk_provider.dart';
import 'providers/risk_radar_provider.dart';
import 'providers/subscriber_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'utils/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts ship in assets (see pubspec `google_fonts/`). Fetching them at
  // runtime would leave the UI textless on networks that block Google CDNs,
  // so fail loudly in dev instead of silently depending on the network.
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const VantagePublicSectorApp());
}

class VantagePublicSectorApp extends StatelessWidget {
  const VantagePublicSectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NewsProvider()),
        ChangeNotifierProvider(create: (_) => SubscriberProvider()),
        ChangeNotifierProvider(create: (_) => AlertProvider()),
        ChangeNotifierProvider(create: (_) => AIProvider()),
        ChangeNotifierProvider(create: (_) => DiscordProvider()),
        ChangeNotifierProvider(create: (_) => LayoutProvider()),
        ChangeNotifierProxyProvider<AuthProvider, AuditProvider>(
          create: (_) => AuditProvider(),
          update: (_, auth, audit) =>
              audit!..updateCurrentUser(auth.currentUser),
        ),
        ChangeNotifierProxyProvider2<AuditProvider, AIProvider,
            ReportStudioProvider>(
          create: (_) => ReportStudioProvider(),
          update: (_, audit, ai, studio) =>
              studio!..wire(audit: audit, apiKey: ai.apiKey),
        ),
        ChangeNotifierProxyProvider2<AuditProvider, AIProvider,
            RiskDeskProvider>(
          create: (_) => RiskDeskProvider(),
          update: (_, audit, ai, desk) =>
              desk!..wire(audit: audit, apiKey: ai.apiKey),
        ),
        ChangeNotifierProxyProvider3<AuditProvider, AIProvider,
            RiskDeskProvider, RiskRadarProvider>(
          create: (_) => RiskRadarProvider(),
          update: (context, audit, ai, desk, radar) => radar!
            ..wire(
              audit: audit,
              apiKey: ai.apiKey,
              alerts: context.read<AlertProvider>(),
              discord: context.read<DiscordProvider>(),
              desk: desk,
            ),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'VANTAGE Public Sector',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const _AuthGate(),
          );
        },
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.initialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!auth.isLoggedIn) {
          return const LoginScreen();
        }
        return const HomeScreen();
      },
    );
  }
}
