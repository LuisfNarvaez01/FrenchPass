import 'dart:async';

import 'package:get_it/get_it.dart';

import 'package:french_pass/core/ai/ai_backend.dart';
import 'package:french_pass/core/config/app_channel.dart';
import 'package:french_pass/core/services/notification_service.dart';
import 'package:french_pass/core/services/reminder_service.dart';
import 'package:french_pass/core/services/speech_service.dart';
import 'package:french_pass/core/services/sound_service.dart';
import 'package:french_pass/features/path/data/path_repository.dart';
import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/core/services/tts_service.dart';
import 'package:french_pass/core/services/update_service.dart';
import 'package:french_pass/core/services/widget_service.dart';
import 'package:french_pass/features/premium/data/billing_service.dart';
import 'package:french_pass/features/premium/data/usage_service.dart';
import 'package:french_pass/features/practice/data/learning_content.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/progress/domain/achievements.dart';
import 'package:french_pass/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:french_pass/features/translator/data/translator_repository.dart';
import 'package:french_pass/features/tutor/data/tutor_repository.dart';
import 'package:french_pass/features/tutor/data/tutor_review_service.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // ─── Services ─────────────────────────────────────────────────────────────
  final storage = await StorageService.create();
  getIt.registerSingleton<StorageService>(storage);
  await AiBackend.init(storage);
  getIt.registerSingleton<TtsService>(TtsService());
  getIt.registerSingleton<SpeechService>(SpeechService());
  getIt.registerSingleton<NotificationService>(NotificationService());
  getIt.registerSingleton<UpdateService>(UpdateService());
  getIt.registerSingleton<WidgetService>(WidgetService());
  getIt.registerSingleton<SoundService>(SoundService(storage));

  // ─── Repositories ─────────────────────────────────────────────────────────
  // The corpus is loaded up front: it is a single bundled asset and every
  // screen needs it, so paying for it once at startup keeps the UI synchronous.
  final words = WordRepository();
  await words.load();
  getIt.registerSingleton<WordRepository>(words);
  final content = LearningContent();
  await content.load();
  getIt.registerSingleton<LearningContent>(content);
  getIt.registerSingleton<ProgressRepository>(ProgressRepository(storage));
  final path = PathRepository(storage);
  await path.load();
  getIt.registerSingleton<PathRepository>(path);
  // Someone who used the app before the journey existed skips the welcome.
  final progress = getIt<ProgressRepository>();
  final usedBefore =
      progress.practiceTotals().values.fold(0, (a, b) => a + b) > 0 ||
          progress.loadCards().isNotEmpty;
  if (storage.getBool(StorageKeys.onboardingDone) == null && usedBefore) {
    await storage.setBool(StorageKeys.onboardingDone, true);
  }
  getIt.registerSingleton<TutorRepository>(TutorRepository(storage));
  getIt.registerSingleton<ReminderService>(ReminderService(
    storage,
    getIt<NotificationService>(),
    getIt<ProgressRepository>(),
  ));
  getIt.registerSingleton<AchievementService>(AchievementService(
    storage,
    getIt<ProgressRepository>(),
    tutorLessons: () => getIt<TutorRepository>().history().length,
  ));
  getIt.registerSingleton<TutorReviewService>(TutorReviewService());
  getIt.registerSingleton<TranslatorRepository>(TranslatorRepository(storage));
  final billing = BillingService(storage);
  getIt.registerSingleton<BillingService>(billing);
  getIt.registerSingleton<UsageService>(
      UsageService(storage, isPremium: () => billing.isPremium.value));
  getIt<ProgressRepository>().isPremium = () => billing.isPremium.value;

  // ─── BLoCs ────────────────────────────────────────────────────────────────
  getIt.registerFactory<SettingsBloc>(
    () => SettingsBloc(getIt<StorageService>(), getIt<NotificationService>(),
        getIt<TtsService>(), getIt<WidgetService>()),
  );

  // Warm the TTS engine so the first "Escuchar" tap is not the one that pays
  // for engine startup.
  final rate = storage.getInt(StorageKeys.speechRate);
  await getIt<TtsService>().init(rate: (rate ?? 38) / 100);

  // Fire-and-forget: a slow or failed network check must never delay the UI
  // or crash startup. MainShell shows the result once it lands, if ever.
  // Play updates the Play build; only the GitHub build updates itself.
  if (AppChannel.isGithub) {
    unawaited(getIt<UpdateService>().checkInBackground());
  }
  // Starts from the cached Premium state and corrects it once Play answers.
  unawaited(billing.init());

  // Push today's word to the home-screen widget as soon as it is known, so
  // a widget placed on the home screen is current even on a launch where
  // the learner never opens the "Hoy" tab (HomeCubit republishes it with the
  // saved level filter once that tab does build).
  final levelFilter =
      LevelFilterExtension.parse(storage.getString(StorageKeys.cefrLevel));
  final today = words.wordOfTheDay(DateTime.now(), levels: levelFilter.levels);
  if (today != null) {
    unawaited(getIt<WidgetService>().publishWordOfTheDay(today));
  }
}
