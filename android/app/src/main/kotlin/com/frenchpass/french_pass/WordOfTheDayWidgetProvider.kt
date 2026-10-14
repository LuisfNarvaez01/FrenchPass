package com.frenchpass.french_pass

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import java.util.Calendar
import java.util.Locale

/**
 * Home-screen widget showing today's word without opening the app.
 *
 * Reads what [WidgetService] (Dart side) wrote to the shared `home_widget`
 * preferences: a schedule of the next 60 days' words, from which it picks
 * today's on every redraw -- so the word changes after midnight even if the
 * app isn't opened (the periodic update in `word_widget_info.xml` is 30
 * minutes). Without a schedule it falls back to the single word last
 * written.
 *
 * The speaker button plays the word with Android's own text-to-speech right
 * here in the receiver, so hearing it never has to start the Flutter app.
 */
class WordOfTheDayWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            appWidgetManager.updateAppWidget(id, render(context, widgetData, speaking = false))
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_SPEAK) {
            speak(context)
            return
        }
        super.onReceive(context, intent)
    }

    // ── Today's word ──────────────────────────────────────────────────────

    private class Entry(
        val french: String,
        val ipa: String,
        val translation: String,
        val example: String,
        val date: String,
    )

    private val months = arrayOf(
        "ene", "feb", "mar", "abr", "may", "jun",
        "jul", "ago", "sep", "oct", "nov", "dic",
    )

    /** Today's entry from the schedule, else the last single word written. */
    private fun today(data: SharedPreferences): Entry? {
        val now = Calendar.getInstance()
        val key = String.format(
            Locale.ROOT, "%04d-%02d-%02d",
            now.get(Calendar.YEAR), now.get(Calendar.MONTH) + 1, now.get(Calendar.DAY_OF_MONTH),
        )
        try {
            val schedule = JSONArray(data.getString("widget_schedule", "[]") ?: "[]")
            for (i in 0 until schedule.length()) {
                val day = schedule.getJSONObject(i)
                if (day.optString("d") == key) {
                    return Entry(
                        day.optString("f"), day.optString("i"), day.optString("t"),
                        day.optString("e"),
                        "${now.get(Calendar.DAY_OF_MONTH)} ${months[now.get(Calendar.MONTH)]}",
                    )
                }
            }
        } catch (_: Exception) {
            // A malformed schedule falls through to the single word.
        }
        val french = data.getString("widget_word_french", null)
        if (french.isNullOrEmpty()) return null
        return Entry(
            french,
            data.getString("widget_word_ipa", "") ?: "",
            data.getString("widget_word_translation", "") ?: "",
            data.getString("widget_word_example", "") ?: "",
            data.getString("widget_word_date", "") ?: "",
        )
    }

    // ── Rendering ─────────────────────────────────────────────────────────

    private class Palette(
        val background: Int,
        val frame: Int,
        val play: Int,
        val playActive: Int,
        val gold: Int,
        val onGold: Int,
        val text: Int,
        val text2: Int,
        val muted: Int,
    )

    /** Null when the widget should simply follow the system theme. */
    private fun forcedPalette(context: Context, theme: String?): Palette? {
        fun c(id: Int) = ContextCompat.getColor(context, id)
        return when (theme) {
            "light" -> Palette(
                R.drawable.widget_background_light, R.drawable.widget_frame_light,
                R.drawable.widget_play_bg_light, R.drawable.widget_play_bg_active_light,
                c(R.color.widget_gold_light), c(R.color.widget_on_gold_light),
                c(R.color.widget_text_light), c(R.color.widget_text2_light),
                c(R.color.widget_muted_light),
            )
            "dark" -> Palette(
                R.drawable.widget_background_dark, R.drawable.widget_frame_dark,
                R.drawable.widget_play_bg_dark, R.drawable.widget_play_bg_active_dark,
                c(R.color.widget_gold_dark), c(R.color.widget_on_gold_dark),
                c(R.color.widget_text_dark), c(R.color.widget_text2_dark),
                c(R.color.widget_muted_dark),
            )
            else -> null
        }
    }

    private fun render(context: Context, data: SharedPreferences, speaking: Boolean): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_word)
        val entry = today(data)
        val french = entry?.french

        if (entry == null) {
            views.setTextViewText(R.id.widget_date, "")
            views.setTextViewText(R.id.widget_word, "Bonjour !")
            views.setTextViewText(R.id.widget_ipa, "bɔ̃.ʒuʁ")
            views.setTextViewText(R.id.widget_translation, "Abre FrenchPass para ver tu palabra del día")
            views.setTextViewText(R.id.widget_example, "")
        } else {
            views.setTextViewText(R.id.widget_date, "· " + entry.date)
            views.setTextViewText(R.id.widget_word, entry.french)
            views.setTextViewText(R.id.widget_ipa, if (entry.ipa.isEmpty()) "" else "/${entry.ipa}/")
            views.setTextViewText(R.id.widget_translation, entry.translation)
            views.setTextViewText(R.id.widget_example, if (entry.example.isEmpty()) "" else "« ${entry.example} »")
        }

        val palette = forcedPalette(context, data.getString("widget_theme", null))
        if (palette != null) {
            views.setInt(R.id.widget_root, "setBackgroundResource", palette.background)
            views.setInt(R.id.widget_frame, "setBackgroundResource", palette.frame)
            views.setTextColor(R.id.widget_eyebrow, palette.gold)
            views.setTextColor(R.id.widget_date, palette.muted)
            views.setTextColor(R.id.widget_word, palette.text)
            views.setTextColor(R.id.widget_ipa, palette.text2)
            views.setTextColor(R.id.widget_translation, palette.text)
            views.setTextColor(R.id.widget_example, palette.text2)
            views.setInt(R.id.widget_play_icon, "setColorFilter", palette.onGold)
        }

        // Speaking: the disc grows a halo and the icon turns into a level
        // meter until the word has been said.
        val playBg = when {
            palette == null -> if (speaking) R.drawable.widget_play_bg_active else R.drawable.widget_play_bg
            speaking -> palette.playActive
            else -> palette.play
        }
        views.setInt(R.id.widget_play, "setBackgroundResource", playBg)
        views.setImageViewResource(
            R.id.widget_play_icon,
            if (speaking) R.drawable.ic_widget_eq else R.drawable.ic_widget_volume,
        )

        views.setOnClickPendingIntent(
            R.id.widget_root,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
        )
        if (!french.isNullOrEmpty()) {
            val speakIntent = Intent(context, WordOfTheDayWidgetProvider::class.java)
                .setAction(ACTION_SPEAK)
            views.setOnClickPendingIntent(
                R.id.widget_play,
                PendingIntent.getBroadcast(
                    context, 0, speakIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
        }
        return views
    }

    private fun redrawAll(context: Context, speaking: Boolean) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, WordOfTheDayWidgetProvider::class.java))
        val data = HomeWidgetPlugin.getData(context)
        ids.forEach { manager.updateAppWidget(it, render(context, data, speaking)) }
    }

    // ── Speaking ──────────────────────────────────────────────────────────

    private fun speak(context: Context) {
        val app = context.applicationContext
        val data = HomeWidgetPlugin.getData(app)
        val word = today(data)?.french
        if (word.isNullOrEmpty()) return

        // The app stores its rate as a percentage of flutter_tts's scale,
        // where 0.5 is Android's normal speed (flutter_tts doubles it).
        val rate = data.getInt("widget_speech_rate", 38) / 100f * 2f

        val pending = goAsync()
        val main = Handler(Looper.getMainLooper())
        var tts: TextToSpeech? = null
        var done = false
        val finish = Runnable {
            if (done) return@Runnable
            done = true
            try {
                tts?.stop()
                tts?.shutdown()
            } catch (_: Exception) {
            }
            redrawAll(app, speaking = false)
            pending.finish()
        }

        redrawAll(app, speaking = true)
        // A broadcast may not outlive ~10 s; never hold it past that, even if
        // the engine never calls back.
        main.postDelayed(finish, 8_000)

        tts = TextToSpeech(app) { status ->
            val engine = tts
            if (status != TextToSpeech.SUCCESS || engine == null) {
                main.post(finish)
                return@TextToSpeech
            }
            if (engine.setLanguage(Locale.FRANCE) < 0) engine.setLanguage(Locale.FRENCH)
            engine.setSpeechRate(rate)
            engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {}
                override fun onDone(utteranceId: String?) {
                    main.post(finish)
                }

                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) {
                    main.post(finish)
                }
            })
            engine.speak(word, TextToSpeech.QUEUE_FLUSH, null, "fp-widget-word")
        }
    }

    companion object {
        const val ACTION_SPEAK = "com.frenchpass.french_pass.widget.SPEAK"
    }
}
