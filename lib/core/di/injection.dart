import 'package:get_it/get_it.dart';

import 'package:french_pass/core/services/notification_service.dart';
import 'package:french_pass/core/services/speech_service.dart';
import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/core/services/tts_service.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // ─── Services ─────────────────────────────────────────────────────────────
  final storage = await StorageService.create();
  getIt.registerSingleton<StorageService>(storage);
  getIt.registerSingleton<TtsService>(TtsService());
  getIt.registerSingleton<SpeechService>(SpeechService());
  getIt.registerSingleton<NotificationService>(NotificationService());

  // ─── Repositories ─────────────────────────────────────────────────────────
  // The corpus is loaded up front: it is a single bundled asset and every
  // screen needs it, so paying for it once at startup keeps the UI synchronous.
  final words = WordRepository();
  await words.load();
  getIt.registerSingleton<WordRepository>(words);
  getIt.registerSingleton<ProgressRepository>(ProgressRepository(storage));

  // ─── BLoCs ────────────────────────────────────────────────────────────────
  getIt.registerFactory<SettingsBloc>(
    () => SettingsBloc(getIt<StorageService>(), getIt<NotificationService>(),
        getIt<TtsService>()),
  );

  // Warm the TTS engine so the first "Escuchar" tap is not the one that pays
  // for engine startup.
  final rate = storage.getInt(StorageKeys.speechRate);
  await getIt<TtsService>().init(rate: (rate ?? 45) / 100);
}
