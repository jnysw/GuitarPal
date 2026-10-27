package com.guitarpal.guitar_pal

import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingSharedText: String? = null
    private var shareChannel: MethodChannel? = null
    private var localVideoImportPlugin: LocalVideoImportPlugin? = null
    private var practiceReminderPlugin: PracticeReminderPlugin? = null
    private var appSettingsPlugin: AppSettingsPlugin? = null
    private var practiceAudioRecordingPlugin: PracticeAudioRecordingPlugin? = null
    private var algorithmAudioImportPlugin: AlgorithmAudioImportPlugin? = null
    private var algorithmStemPlugin: AlgorithmStemPlugin? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingSharedText = extractSharedText(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            LOCAL_VIDEO_PLAYER_VIEW_TYPE,
            LocalVideoPlayerFactory(flutterEngine.dartExecutor.binaryMessenger),
        )
        shareChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SHARE_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialSharedText" -> {
                        result.success(pendingSharedText)
                        pendingSharedText = null
                    }

                    "shareText" -> {
                        val arguments = call.arguments as? Map<*, *>
                        val subject = (arguments?.get("subject") as? String)?.trim().orEmpty()
                        val text = (arguments?.get("text") as? String)?.trim().orEmpty()
                        if (text.isEmpty()) {
                            result.error("invalid_share_text", "分享内容不能为空", null)
                            return@setMethodCallHandler
                        }

                        val sendIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            if (subject.isNotEmpty()) {
                                putExtra(Intent.EXTRA_SUBJECT, subject)
                            }
                            putExtra(Intent.EXTRA_TEXT, text)
                        }
                        try {
                            startActivity(Intent.createChooser(sendIntent, "导出练习笔记"))
                            result.success(true)
                        } catch (_: ActivityNotFoundException) {
                            result.success(false)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
        }
        localVideoImportPlugin = LocalVideoImportPlugin(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        practiceReminderPlugin = PracticeReminderPlugin(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        appSettingsPlugin = AppSettingsPlugin(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        practiceAudioRecordingPlugin = PracticeAudioRecordingPlugin(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        algorithmAudioImportPlugin = AlgorithmAudioImportPlugin(this, flutterEngine.dartExecutor.binaryMessenger)
        algorithmStemPlugin = AlgorithmStemPlugin(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val sharedText = extractSharedText(intent) ?: return
        val channel = shareChannel
        if (channel == null) {
            pendingSharedText = sharedText
        } else {
            channel.invokeMethod("sharedText", sharedText)
        }
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (algorithmAudioImportPlugin?.onActivityResult(requestCode, resultCode, data) == true) return
        if (localVideoImportPlugin?.onActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (
            practiceReminderPlugin?.onRequestPermissionsResult(
                requestCode,
                permissions,
                grantResults,
            ) == true
        ) {
            return
        }
        if (
            practiceAudioRecordingPlugin?.onRequestPermissionsResult(
                requestCode,
                permissions,
                grantResults,
            ) == true
        ) {
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onStop() {
        algorithmStemPlugin?.stop()
        practiceAudioRecordingPlugin?.onHostStop()
        super.onStop()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        shareChannel?.setMethodCallHandler(null)
        shareChannel = null
        localVideoImportPlugin?.dispose()
        localVideoImportPlugin = null
        practiceReminderPlugin?.dispose()
        practiceReminderPlugin = null
        appSettingsPlugin?.dispose()
        appSettingsPlugin = null
        practiceAudioRecordingPlugin?.dispose()
        practiceAudioRecordingPlugin = null
        algorithmAudioImportPlugin?.dispose()
        algorithmAudioImportPlugin = null
        algorithmStemPlugin?.dispose()
        algorithmStemPlugin = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun extractSharedText(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_SEND || intent.type != "text/plain") {
            return null
        }
        return intent.getCharSequenceExtra(Intent.EXTRA_TEXT)
            ?.toString()
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
    }

    companion object {
        private const val SHARE_CHANNEL = "com.guitarpal/share"
        private const val LOCAL_VIDEO_PLAYER_VIEW_TYPE = "com.guitarpal/local_video_player"
    }
}
