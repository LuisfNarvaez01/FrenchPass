import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:home_widget/home_widget.dart';

import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

/// Pushes today's word, and the bits of settings the widget needs, to the
/// Android home-screen widget.
///
/// `home_widget` only moves data across the Flutter/native boundary; the
/// widget's own [AppWidgetProvider] (`WordOfTheDayWidgetProvider.kt`) reads
/// whatever was last written here and redraws independently of the app's
/// lifecycle. A stale value is not a bug by itself -- the widget shows
/// whatever the app last computed, which updates every time the app is
/// opened, same as the lock-screen weather widget pattern most learners
/// already know.
class WidgetService {
  static const _androidProvider = 'WordOfTheDayWidgetProvider';

  static const _months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  Future<void> publishWordOfTheDay(Word word, {DateTime? day}) async {
    final d = day ?? DateTime.now();
    await _guard('publishWordOfTheDay', () async {
      await HomeWidget.saveWidgetData<String>('widget_word_french', word.french);
      await HomeWidget.saveWidgetData<String>('widget_word_ipa', word.ipaBare);
      await HomeWidget.saveWidgetData<String>(
          'widget_word_translation', word.translationEs);
      await HomeWidget.saveWidgetData<String>(
          'widget_word_example', word.exampleFr);
      await HomeWidget.saveWidgetData<String>(
          'widget_word_date', '${d.day} ${_months[d.month - 1]}');
      await HomeWidget.saveWidgetData<String>('widget_word_id', word.id);
      await HomeWidget.updateWidget(androidName: _androidProvider);
    });
  }

  /// The words of the coming days, so the widget can switch to the next
  /// one at midnight on its own, without the app being opened.
  Future<void> publishSchedule(List<(DateTime, Word)> days) =>
      _guard('publishSchedule', () async {
        String key(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';
        await HomeWidget.saveWidgetData<String>(
          'widget_schedule',
          jsonEncode([
            for (final (day, w) in days)
              {
                'd': key(day),
                'f': w.french,
                'i': w.ipaBare,
                't': w.translationEs,
                'e': w.exampleFr,
              },
          ]),
        );
        await HomeWidget.updateWidget(androidName: _androidProvider);
      });

  /// The widget follows the app's own theme choice (not only the system's),
  /// and speaks at the same speed as the app.
  Future<void> publishAppearance({
    required ThemeMode themeMode,
    required int speechRate,
  }) =>
      _guard('publishAppearance', () async {
        await HomeWidget.saveWidgetData<String>('widget_theme', themeMode.name);
        await HomeWidget.saveWidgetData<int>('widget_speech_rate', speechRate);
        await HomeWidget.updateWidget(androidName: _androidProvider);
      });

  Future<void> _guard(String what, Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      // The widget is a convenience surface, not a critical path: a device
      // without launcher-widget support, or a transient platform-channel
      // error, must never take the app down with it.
      debugPrint('WidgetService.$what failed: $e');
    }
  }
}
