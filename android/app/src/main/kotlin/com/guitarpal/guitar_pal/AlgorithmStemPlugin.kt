package com.guitarpal.guitar_pal

import android.app.Activity
import android.media.AudioAttributes
import android.media.MediaPlayer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Independent local audition player; never accepts network URLs or user paths. */
class AlgorithmStemPlugin(private val activity: Activity, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "com.guitarpal/algorithm_stems")
    private val root get() = File(activity.filesDir, "algorithm_stems")
    private var player: MediaPlayer? = null
    private var preparing: MethodChannel.Result? = null
    init { channel.setMethodCallHandler(this) }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "directory" -> { root.mkdirs(); result.success(root.absolutePath) }
                "play" -> {
                    val file = File(requireNotNull(call.argument<String>("path"))).canonicalFile
                    require(file.parentFile == root.canonicalFile && file.isFile && file.extension in setOf("wav", "flac"))
                    stop()
                    val p = MediaPlayer()
                    player = p
                    preparing = result
                    p.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                    p.setDataSource(file.absolutePath)
                    p.setOnPreparedListener {
                        val pending = preparing
                        preparing = null
                        try {
                            p.seekTo((call.argument<Number>("positionMs")?.toInt() ?: 0).coerceIn(0, p.duration.coerceAtLeast(0)))
                            p.start()
                            pending?.success(null)
                        } catch (_: Throwable) { pending?.error("play_failed", "无法播放此音轨", null); stop() }
                    }
                    p.setOnErrorListener { _, _, _ ->
                        stop()
                        true
                    }
                    p.prepareAsync()
                }
                "pause" -> { if (preparing != null) stop() else if (player?.isPlaying == true) player?.pause(); result.success(null) }
                "stop" -> { stop(); result.success(null) }
                "seek" -> { if (preparing == null) player?.let { it.seekTo((call.argument<Number>("positionMs")?.toInt() ?: 0).coerceIn(0, it.duration.coerceAtLeast(0))) }; result.success(null) }
                "snapshot" -> result.success(mapOf("isPlaying" to (preparing == null && player?.isPlaying == true),
                    "positionMs" to (if (preparing == null) player?.currentPosition ?: 0 else 0),
                    "durationMs" to (if (preparing == null) player?.duration ?: 0 else 0)))
                else -> result.notImplemented()
            }
        } catch (_: Throwable) { stop(); result.error("stem_playback_failed", "无法播放本机音轨", null) }
    }

    fun stop() {
        preparing?.error("play_interrupted", "音轨准备已停止", null)
        preparing = null
        try { player?.release() } catch (_: Throwable) { }
        player = null
    }
    fun dispose() { stop(); channel.setMethodCallHandler(null) }
}
