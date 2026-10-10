import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:french_pass/core/services/notification_service.dart';
import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/core/services/tts_service.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

/// Which CEFR levels the daily word and the quiz draw from.
enum LevelFilter { beginner, intermediate, advanced, mixed }

extension LevelFilterExtension on LevelFilter {
  String get labelEs => switch (this) {
        LevelFilter.beginner => 'Principiante · A1–A2',
        LevelFilter.intermediate => 'Intermedio · B1–B2',
        LevelFilter.advanced => 'Avanzado · C1–C2',
        LevelFilter.mixed => 'Todos los niveles',
      };

  Set<CefrLevel> get levels => switch (this) {
        LevelFilter.beginner => {CefrLevel.a1, CefrLevel.a2},
        LevelFilter.intermediate => {CefrLevel.b1, CefrLevel.b2},
        LevelFilter.advanced => {CefrLevel.c1, CefrLevel.c2},
        LevelFilter.mixed => CefrLevel.values.toSet(),
      };

  static LevelFilter parse(String? raw) => LevelFilter.values.firstWhere(
        (f) => f.name == raw,
        orElse: () => LevelFilter.mixed,
      );
}

// ─── State ───────────────────────────────────────────────────────────────────
class SettingsState extends Equatable {
  final ThemeMode themeMode;
  final String languageCode;
  final LevelFilter levelFilter;
  final bool notificationsEnabled;
  final int notificationHour;

  /// TTS rate as a percentage (30–70 is the useful range for learners).
  final int speechRate;

  const SettingsState({
    this.themeMode = ThemeMode.dark,
    this.languageCode = 'es',
    this.levelFilter = LevelFilter.mixed,
    this.notificationsEnabled = false,
    this.notificationHour = 9,
    this.speechRate = 45,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? languageCode,
    LevelFilter? levelFilter,
    bool? notificationsEnabled,
    int? notificationHour,
    int? speechRate,
  }) =>
      SettingsState(
        themeMode: themeMode ?? this.themeMode,
        languageCode: languageCode ?? this.languageCode,
        levelFilter: levelFilter ?? this.levelFilter,
        notificationsEnabled:
            notificationsEnabled ?? this.notificationsEnabled,
        notificationHour: notificationHour ?? this.notificationHour,
        speechRate: speechRate ?? this.speechRate,
      );

  @override
  List<Object?> get props => [
        themeMode,
        languageCode,
        levelFilter,
        notificationsEnabled,
        notificationHour,
        speechRate,
      ];
}

// ─── Events ──────────────────────────────────────────────────────────────────
sealed class SettingsEvent extends Equatable {
  const SettingsEvent();
  @override
  List<Object?> get props => [];
}

class LoadSettingsEvent extends SettingsEvent {
  const LoadSettingsEvent();
}

class ChangeThemeEvent extends SettingsEvent {
  final ThemeMode themeMode;
  const ChangeThemeEvent(this.themeMode);
  @override
  List<Object?> get props => [themeMode];
}

class ChangeLanguageEvent extends SettingsEvent {
  final String languageCode;
  const ChangeLanguageEvent(this.languageCode);
  @override
  List<Object?> get props => [languageCode];
}

class ChangeLevelEvent extends SettingsEvent {
  final LevelFilter levelFilter;
  const ChangeLevelEvent(this.levelFilter);
  @override
  List<Object?> get props => [levelFilter];
}

class ToggleNotificationsEvent extends SettingsEvent {
  final bool enabled;
  const ToggleNotificationsEvent(this.enabled);
  @override
  List<Object?> get props => [enabled];
}

class ChangeNotificationHourEvent extends SettingsEvent {
  final int hour;
  const ChangeNotificationHourEvent(this.hour);
  @override
  List<Object?> get props => [hour];
}

class ChangeSpeechRateEvent extends SettingsEvent {
  final int rate;
  const ChangeSpeechRateEvent(this.rate);
  @override
  List<Object?> get props => [rate];
}

/// Emitted by the UI after wiping progress, so dependent screens rebuild.
class SettingsRefreshedEvent extends SettingsEvent {
  const SettingsRefreshedEvent();
}

// ─── BLoC ────────────────────────────────────────────────────────────────────
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final StorageService _storage;
  final NotificationService _notifications;
  final TtsService _tts;

  SettingsBloc(this._storage, this._notifications, this._tts)
      : super(const SettingsState()) {
    on<LoadSettingsEvent>(_onLoad);
    on<ChangeThemeEvent>(_onChangeTheme);
    on<ChangeLanguageEvent>(_onChangeLanguage);
    on<ChangeLevelEvent>(_onChangeLevel);
    on<ToggleNotificationsEvent>(_onToggleNotifications);
    on<ChangeNotificationHourEvent>(_onChangeHour);
    on<ChangeSpeechRateEvent>(_onChangeSpeechRate);
    on<SettingsRefreshedEvent>((_, emit) => emit(state.copyWith()));
  }

  void _onLoad(LoadSettingsEvent event, Emitter<SettingsState> emit) {
    emit(SettingsState(
      themeMode: _themeFromName(_storage.getString(StorageKeys.themeMode)),
      languageCode: _storage.getString(StorageKeys.language) ?? 'es',
      levelFilter:
          LevelFilterExtension.parse(_storage.getString(StorageKeys.cefrLevel)),
      notificationsEnabled:
          _storage.getBool(StorageKeys.notificationsEnabled) ?? false,
      notificationHour: _storage.getInt(StorageKeys.notificationHour) ?? 9,
      speechRate: _storage.getInt(StorageKeys.speechRate) ?? 45,
    ));
  }

  Future<void> _onChangeTheme(
      ChangeThemeEvent event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(themeMode: event.themeMode));
    await _storage.setString(StorageKeys.themeMode, event.themeMode.name);
  }

  Future<void> _onChangeLanguage(
      ChangeLanguageEvent event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(languageCode: event.languageCode));
    await _storage.setString(StorageKeys.language, event.languageCode);
  }

  Future<void> _onChangeLevel(
      ChangeLevelEvent event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(levelFilter: event.levelFilter));
    await _storage.setString(StorageKeys.cefrLevel, event.levelFilter.name);
  }

  Future<void> _onToggleNotifications(
      ToggleNotificationsEvent event, Emitter<SettingsState> emit) async {
    if (!event.enabled) {
      await _notifications.cancelDaily();
      emit(state.copyWith(notificationsEnabled: false));
      await _storage.setBool(StorageKeys.notificationsEnabled, false);
      return;
    }

    // Only report the toggle as on if the OS actually granted it.
    final scheduled =
        await _notifications.scheduleDaily(hour: state.notificationHour);
    emit(state.copyWith(notificationsEnabled: scheduled));
    await _storage.setBool(StorageKeys.notificationsEnabled, scheduled);
  }

  Future<void> _onChangeHour(
      ChangeNotificationHourEvent event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(notificationHour: event.hour));
    await _storage.setInt(StorageKeys.notificationHour, event.hour);
    if (state.notificationsEnabled) {
      await _notifications.scheduleDaily(hour: event.hour);
    }
  }

  Future<void> _onChangeSpeechRate(
      ChangeSpeechRateEvent event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(speechRate: event.rate));
    await _storage.setInt(StorageKeys.speechRate, event.rate);
    await _tts.setRate(event.rate / 100);
  }

  static ThemeMode _themeFromName(String? name) => switch (name) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };
}
