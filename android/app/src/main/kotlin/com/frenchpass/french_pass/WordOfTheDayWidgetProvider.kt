package com.frenchpass.french_pass

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget showing today's word without opening the app.
 *
 * Reads whatever [WidgetService] (Dart side) last wrote to the shared
 * `home_widget` preferences -- this class never computes the word itself, it
 * only renders the last value it was handed and redraws on launcher resize
 * or the periodic update window declared in `word_widget_info.xml`.
 */
class WordOfTheDayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_word)
            val french = widgetData.getString("widget_word_french", null)

            if (french.isNullOrEmpty()) {
                views.setTextViewText(R.id.widget_eyebrow, "FRENCHPASS")
                views.setTextViewText(R.id.widget_word, "Abre la app")
                views.setTextViewText(R.id.widget_ipa, "")
                views.setTextViewText(R.id.widget_translation, "para ver tu palabra del día")
            } else {
                views.setTextViewText(R.id.widget_eyebrow, "PALABRA DEL DÍA")
                views.setTextViewText(R.id.widget_word, french)
                views.setTextViewText(R.id.widget_ipa, widgetData.getString("widget_word_ipa", "") ?: "")
                views.setTextViewText(
                    R.id.widget_translation,
                    widgetData.getString("widget_word_translation", "") ?: "",
                )
            }

            val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
