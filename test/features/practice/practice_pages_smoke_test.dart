// Mounts every practice screen and walks into its exercise, to catch
// layout and wiring errors that only show up at runtime.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/notification_service.dart';
import 'package:french_pass/core/services/reminder_service.dart';
import 'package:french_pass/core/services/widget_service.dart';
import 'package:french_pass/core/services/sound_service.dart';
import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/core/services/tts_service.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/features/path/data/path_repository.dart';
import 'package:french_pass/features/path/presentation/pages/journey_page.dart';
import 'package:french_pass/features/path/presentation/pages/lesson_page.dart';
import 'package:french_pass/features/path/presentation/pages/welcome_page.dart';
import 'package:french_pass/features/practice/data/learning_content.dart';
import 'package:french_pass/features/practice/presentation/widgets/practice_widgets.dart';
import 'package:french_pass/features/practice/presentation/pages/conjugation_pages.dart';
import 'package:french_pass/features/practice/presentation/pages/dictation_page.dart';
import 'package:french_pass/features/practice/presentation/pages/false_friends_page.dart';
import 'package:french_pass/features/practice/presentation/pages/grammar_pages.dart';
import 'package:french_pass/features/practice/presentation/pages/numbers_page.dart';
import 'package:french_pass/features/practice/presentation/pages/order_match_pages.dart';
import 'package:french_pass/features/practice/presentation/pages/placement_page.dart';
import 'package:french_pass/features/practice/presentation/pages/practice_hub_page.dart';
import 'package:french_pass/features/practice/presentation/pages/reading_pages.dart';
import 'package:french_pass/features/categories/presentation/pages/categories_page.dart';
import 'package:french_pass/features/conjugation/domain/conjugator.dart';
import 'package:french_pass/features/premium/data/billing_service.dart';
import 'package:french_pass/features/premium/data/usage_service.dart';
import 'package:french_pass/features/premium/presentation/pages/premium_page.dart';
import 'package:french_pass/features/settings/presentation/pages/settings_page.dart';
import 'package:french_pass/features/tutor/presentation/pages/tutor_page.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/progress/domain/achievements.dart';
import 'package:french_pass/features/progress/presentation/pages/progress_page.dart';
import 'package:french_pass/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:french_pass/features/tutor/data/tutor_repository.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';
import 'package:french_pass/features/word_of_the_day/presentation/pages/home_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late SettingsBloc settings;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    final words = WordRepository();
    await words.load();
    final content = LearningContent();
    await content.load();
    getIt
      ..registerSingleton<StorageService>(storage)
      ..registerSingleton<WordRepository>(words)
      ..registerSingleton<LearningContent>(content)
      ..registerSingleton<TtsService>(TtsService())
      ..registerSingleton<ProgressRepository>(ProgressRepository(storage))
      ..registerSingleton<TutorRepository>(TutorRepository(storage));
    getIt.registerSingleton<AchievementService>(AchievementService(
        storage, getIt<ProgressRepository>(),
        tutorLessons: () => 0));
    final notifications = NotificationService();
    getIt
      ..registerSingleton<NotificationService>(notifications)
      ..registerSingleton<WidgetService>(WidgetService())
      ..registerSingleton<SoundService>(SoundService(storage))
      ..registerSingleton<ReminderService>(
          ReminderService(storage, notifications, getIt<ProgressRepository>()));
    final billing = BillingService(storage);
    getIt
      ..registerSingleton<BillingService>(billing)
      ..registerSingleton<UsageService>(
          UsageService(storage, isPremium: () => billing.isPremium.value));
    final path = PathRepository(storage);
    await path.load();
    getIt.registerSingleton<PathRepository>(path);
    settings = SettingsBloc(storage, notifications, getIt<TtsService>());
  });

  Future<void> mount(WidgetTester tester, Widget page) async {
    // 360 dp wide: one of the narrowest common Android phones.
    tester.view.physicalSize = const Size(990, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(BlocProvider.value(
      value: settings,
      // A fresh app per screen: MaterialApp keeps its first home.
      child: MaterialApp(key: UniqueKey(), theme: AppTheme.light, home: page),
    ));
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    // Lists build lazily: scroll until what we want exists.
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(finder, 300,
          scrollable: find.byType(Scrollable).first);
    }
    await tester.ensureVisible(finder.first);
    await tester.tap(finder.first);
    await tester.pump(const Duration(seconds: 2));
    // flutter_animate starts a zero-length timer for items built in the
    // last frame; one more frame lets it fire.
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('practice hub', (tester) async {
    SoundService.muted = true;
    await mount(tester, const PracticeHubPage());
    expect(find.text('Practicar'), findsOneWidget);
    expect(find.text('RECOMENDADO AHORA'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Conjugación'), 200);
    expect(find.text('Conjugación'), findsWidgets);
    expect(find.text('Lecturas'), findsWidgets);
  });

  testWidgets('grammar: list, rule, first exercise', (tester) async {
    await mount(tester, const GrammarListPage());
    expect(find.text('El género: le, la, un, une'), findsOneWidget);
    await mount(tester, const GrammarTopicPage(topicId: 'gender'));
    await tapText(tester, 'Hacer los 5 ejercicios');
    await tapText(tester, 'La');
    expect(find.text('Siguiente'), findsOneWidget);
  });

  testWidgets('false friends: list and quiz', (tester) async {
    await mount(tester, const FalseFriendsPage());
    await tapText(tester, 'Ponte a prueba');
    expect(find.textContaining('¿Qué significa'), findsOneWidget);
  });

  testWidgets('readings: list, story, word sheet', (tester) async {
    await mount(tester, const ReadingListPage());
    expect(find.text('Le matin de Léa'), findsOneWidget);
    await mount(tester, const ReadingPage(readingId: 'a1-matin'));
    await tapText(tester, 'chat.');
    expect(find.text('Gato'), findsWidgets);
  });

  testWidgets('conjugation: list, verb, drill', (tester) async {
    await mount(tester, const ConjugationPage());
    expect(find.text('aller'), findsOneWidget);
    await mount(tester, const VerbPage(verb: 'aller'));
    expect(find.text('je vais'), findsOneWidget);
    await mount(tester, const ConjugationDrillPage(tenses: [Tense.present]));
    expect(find.text('Comprobar'), findsOneWidget);
  });

  testWidgets('dictation', (tester) async {
    await mount(tester, const DictationPage());
    expect(find.text('Escribe la palabra'), findsOneWidget);
  });

  testWidgets('numbers: menu and a round', (tester) async {
    await mount(tester, const NumbersPage());
    await tapText(tester, 'La hora');
    expect(find.text('Escribe la hora en cifras'), findsOneWidget);
  });

  testWidgets('order and match', (tester) async {
    await mount(tester, const OrderSentencePage());
    expect(
        find.text('Toca las palabras en el orden correcto.'), findsOneWidget);
    await mount(tester, const MatchPairsPage());
    expect(find.text('Ronda 1 de 3'), findsOneWidget);
  });

  testWidgets('placement: intro, then an A1 question, quiet on answer',
      (tester) async {
    await mount(tester, const PlacementPage());
    await tester.runAsync(() async {
      await tester.tap(find.text('Empezar'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('Prueba de nivel · A1'), findsOneWidget);
    expect(find.byType(FeedbackBanner), findsNothing);
  });

  testWidgets('welcome: the promise and the two ways in', (tester) async {
    await mount(tester, const WelcomePage());
    expect(tester.takeException(), isNull);
    expect(find.textContaining('una palabra a la vez'), findsOneWidget);
    expect(find.text('Empiezo desde cero'), findsOneWidget);
    expect(find.text('Ya sé algo de francés'), findsOneWidget);
  });

  testWidgets('journey map: seven stages, the first one open with its stops',
      (tester) async {
    await mount(tester, const JourneyPage());
    expect(tester.takeException(), isNull);
    expect(find.text('Départ'), findsOneWidget);
    expect(find.text('Saludar'), findsOneWidget);
    expect(find.text('SEMANA 1'), findsOneWidget);
  });

  testWidgets('a lesson: learn a word, then answer, then the conversation',
      (tester) async {
    SoundService.muted = true;
    await mount(tester, const LessonPage(stopId: 'depart-1'));
    expect(tester.takeException(), isNull);
    expect(find.text('PALABRA NUEVA'), findsOneWidget);
    expect(find.text('bonjour'), findsOneWidget);
    // Through the three new words.
    for (var i = 0; i < 3; i++) {
      await tapText(tester, 'Entendido');
    }
    expect(tester.takeException(), isNull);
    expect(find.textContaining('saludas a tu profesora'), findsOneWidget);
    await tapText(tester, 'Bonjour, madame !');
    expect(find.text('Correcto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a locked stop says so instead of opening', (tester) async {
    await mount(tester, const LessonPage(stopId: 'depart-5'));
    expect(tester.takeException(), isNull);
    expect(find.text('Todavía no'), findsOneWidget);
  });

  testWidgets('progress shows the achievements once there is practice',
      (tester) async {
    await getIt<ProgressRepository>().recordPractice(PracticeKind.grammar);
    await getIt<AchievementService>().refresh();
    await mount(tester, const ProgressPage());
    expect(find.text('Logros'), findsOneWidget);
    expect(find.text('Primer paso'), findsOneWidget);
  });

  testWidgets('match pairs works starting from the meaning', (tester) async {
    await mount(tester, const MatchPairsPage());
    // Cells are keyed by word id: texts can repeat across the columns
    // ("taxi" reads the same in French and Spanish).
    final ids = tester
        .widgetList(find.byWidgetPredicate((w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('fr-')))
        .map((w) => (w.key! as ValueKey<String>).value.substring(3))
        .toList();
    expect(ids.length, 5);
    for (final id in ids) {
      await tester.tap(find.byKey(ValueKey('es-$id')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(ValueKey('fr-$id')));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Ronda 2 de 3'), findsOneWidget);
  });

  testWidgets('home shows the goal and offers the placement test',
      (tester) async {
    // Home lives inside the tab shell's Scaffold.
    await mount(tester, const Scaffold(body: HomePage()));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('PALABRA DEL DÍA'), findsOneWidget);
    expect(find.text('Empezar la lección'), findsOneWidget);
    expect(find.textContaining('TU VIAJE'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('CONTINÚA'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('CONTINÚA'), findsOneWidget);
    expect(find.textContaining('Meta de hoy'), findsOneWidget);
    expect(find.text('¿Cuál es tu nivel?'), findsOneWidget);
  });

  testWidgets('word catalogue: families, then filters turn it into a list',
      (tester) async {
    await mount(tester, const Scaffold(body: CategoriesPage()));
    expect(tester.takeException(), isNull);
    expect(find.text('Palabras'), findsOneWidget);
    expect(find.text('VIDA DIARIA'), findsOneWidget);
    await tester.tap(find.text('A1'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('palabras'), findsWidgets);
    expect(find.text('VIDA DIARIA'), findsNothing);
  });

  testWidgets('tutor tab, premium and settings', (tester) async {
    await mount(tester, const Scaffold(body: TutorPage()));
    expect(tester.takeException(), isNull);
    expect(find.text('Traductor'), findsOneWidget);
    await mount(tester, const PremiumPage());
    expect(tester.takeException(), isNull);
    expect(find.text('FrenchPass Premium'), findsOneWidget);
    await mount(tester, const SettingsPage());
    expect(tester.takeException(), isNull);
    expect(find.text('Meta diaria'), findsOneWidget);
  });
}
