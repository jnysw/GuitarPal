package com.guitarpal.guitar_pal

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class AppSettingsPlugin(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val preferences = context.applicationContext.getSharedPreferences(
        preferencesName,
        Context.MODE_PRIVATE,
    )
    private val channel = MethodChannel(messenger, channelName)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "load" -> result.success(
                mapOf(
                    "themeMode" to preferences.getString(themeModeKey, "system"),
                    "defaultPlaybackSpeed" to preferences.getFloat(
                        defaultPlaybackSpeedKey,
                        1.0f,
                    ).toDouble(),
                ),
            )

            "save" -> save(call, result)
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    private fun save(call: MethodCall, result: MethodChannel.Result) {
        val themeMode = call.argument<String>("themeMode")
        val speed = call.argument<Number>("defaultPlaybackSpeed")?.toDouble()
        if (themeMode !in supportedThemeModes) {
            result.error("invalid_theme_mode", "主题模式无效", null)
            return
        }
        if (speed == null || !speed.isFinite() || speed < 0.5 || speed > 2.0) {
            result.error("invalid_playback_speed", "默认倍速必须在 0.50 到 2.00 之间", null)
            return
        }

        preferences.edit()
            .putString(themeModeKey, themeMode)
            .putFloat(defaultPlaybackSpeedKey, speed.toFloat())
            .apply()
        result.success(null)
    }

    companion object {
        private const val channelName = "com.guitarpal/app_settings"
        private const val preferencesName = "guitarpal_app_settings"
        private const val themeModeKey = "theme_mode"
        private const val defaultPlaybackSpeedKey = "default_playback_speed"
        private val supportedThemeModes = setOf("system", "light", "dark")
    }
}
