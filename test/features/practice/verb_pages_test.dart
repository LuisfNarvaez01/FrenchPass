// Every verb sheet must open, both directly and through the app's router
// (where the verb travels URL-encoded: "s'appeler", "être", "se lever").
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/core/services/tts_service.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/features/conjugation/domain/conjugator.dart';
import 'package:french_pass/features/practice/presentation/pages/conjugation_pages.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    if (!getIt.isRegistered<StorageService>()) {
      getIt.registerSingleton<StorageService>(storage);
    }
    if (!getIt.isRegistered<TtsService>()) {
      getIt.registerSingleton<TtsService>(TtsService());
    }
  });

  testWidgets('every verb sheet renders', (tester) async {
    for (final verb in Verbs.all) {
      await tester.pumpWidget(MaterialApp(
        key: UniqueKey(),
        theme: AppTheme.light,
        home: VerbPage(verb: verb.display),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: verb.display);
      expect(find.text('Verbo no encontrado'), findsNothing,
          reason: verb.display);
    }
  });

  testWidgets('every verb opens through the router', (tester) async {
    for (final verb in Verbs.all) {
      final router = GoRouter(
        initialLocation:
            '/practice/conjugation/${Uri.encodeComponent(verb.display)}',
        routes: [
          GoRoute(
            path: '/practice/conjugation',
            builder: (context, state) => const SizedBox(),
            routes: [
              GoRoute(
                path: ':verb',
                // Exactly as AppRouter builds it.
                builder: (context, state) =>
                    VerbPage(verb: state.pathParameters['verb']!),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(
        key: UniqueKey(),
        theme: AppTheme.light,
        routerConfig: router,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: verb.display);
      expect(find.text('Verbo no encontrado'), findsNothing,
          reason: verb.display);
    }
  });

  testWidgets('tapping each verb in the list opens its sheet', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/practice/conjugation',
      routes: [
        GoRoute(
          path: '/practice/conjugation',
          builder: (context, state) => const ConjugationPage(),
          routes: [
            GoRoute(
              path: ':verb',
              builder: (context, state) =>
                  VerbPage(verb: state.pathParameters['verb']!),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router));
    await tester.pump(const Duration(seconds: 1));
    for (final verb in Verbs.all) {
      // .first: in "dormir" or "venir" the title and translation match.
      final tile = find.widgetWithText(ListTile, verb.display).first;
      await tester.scrollUntilVisible(tile, 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(tile);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull, reason: verb.display);
      expect(find.text(verb.es), findsWidgets, reason: verb.display);
      expect(find.text('Verbo no encontrado'), findsNothing,
          reason: verb.display);
      router.pop();
      await tester.pump(const Duration(seconds: 1));
    }
  });
}
