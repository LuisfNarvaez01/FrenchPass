import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

/// Pushes today's word to the Android home-screen widget.
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

  Future<void> publishWordOfTheDay(Word word) async {
    try {
      await HomeWidget.saveWidgetData<String>('widget_word_french', word.french);
      await HomeWidget.saveWidgetData<String>('widget_word_ipa', word.ipa);
      await HomeWidget.saveWidgetData<String>(
          'widget_word_translation', word.translationEs);
      await HomeWidget.saveWidgetData<String>('widget_word_id', word.id);
      await HomeWidget.updateWidget(androidName: _androidProvider);
    } catch (e) {
      // The widget is a convenience surface, not a critical path: a device
      // without launcher-widget support, or a transient platform-channel
      // error, must never take the app down with it.
      debugPrint('WidgetService.publishWordOfTheDay failed: $e');
    }
  }
}
