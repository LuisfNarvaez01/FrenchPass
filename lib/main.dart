import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:french_pass/core/config/app_channel.dart';
import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/router/app_router.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/features/settings/presentation/bloc/settings_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The Play build keeps its log quiet: error details are for the
  // developer's GitHub build.
  if (AppChannel.isPlay && kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await configureDependencies();

  runApp(const FrenchPassApp());
}

class FrenchPassApp extends StatelessWidget {
  const FrenchPassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SettingsBloc>()..add(const LoadSettingsEvent()),
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settings) {
          // Keep the system bars in step with the resolved theme so the status
          // bar never ends up dark-on-dark.
          final isDark = settings.themeMode == ThemeMode.dark ||
              (settings.themeMode == ThemeMode.system &&
                  MediaQuery.platformBrightnessOf(context) == Brightness.dark);
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
              systemNavigationBarColor:
                  isDark ? AppPalette.dark.surface : AppPalette.light.surface,
              systemNavigationBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
            ),
          );

          return MaterialApp.router(
            title: 'FrenchPass',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: settings.themeMode,
            routerConfig: AppRouter.router,
            locale: Locale(settings.languageCode),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('es'),
              Locale('en'),
              Locale('fr'),
            ],
            builder: (context, child) => MediaQuery.withClampedTextScaling(
              // Keep the Playfair display sizes from overflowing their cards on
              // very large accessibility text settings.
              maxScaleFactor: 1.3,
              child: child!,
            ),
          );
        },
      ),
    );
  }
}
