package com.guitarpal.guitar_pal

import android.content.Context
import android.graphics.Color
import android.graphics.SurfaceTexture
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.Surface
import android.view.TextureView
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.io.File
import kotlin.math.roundToInt

class LocalVideoPlatformView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    private val path: String,
) : PlatformView,
    MethodChannel.MethodCallHandler,
    TextureView.SurfaceTextureListener {
    private val container = FrameLayout(context).apply {
        setBackgroundColor(Color.BLACK)
    }
    private val textureView = TextureView(context).apply {
        surfaceTextureListener = this@LocalVideoPlatformView
        isOpaque = true
    }
    private val channel = MethodChannel(messenger, "$CHANNEL_PREFIX/$viewId")
    private val handler = Handler(Looper.getMainLooper())

    private var mediaPlayer: MediaPlayer? = null
    private var outputSurface: Surface? = null
    private var isPrepared = false
    private var isPreparing = false
    private var isDisposed = false
    private var pendingPlay = false
    private var pendingSeekMilliseconds: Int? = null
    private var speed = 1.0f
    private var volume = 1.0f
    private var videoWidth = 0
    private var videoHeight = 0
    private var hasRenderedFrame = false
    private var playerError: String? = null

    private val stateTicker = object : Runnable {
        override fun run() {
            if (isDisposed) return
            emitState()
            handler.postDelayed(this, STATE_INTERVAL_MS)
        }
    }

    init {
        channel.setMethodCallHandler(this)
        container.addView(
            textureView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
                Gravity.CENTER,
            ),
        )
        container.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ ->
            updateTextureLayout()
        }

        val file = File(path)
        if (path.isBlank() || !file.isFile) {
            playerError = "本地视频文件不存在"
        }
        handler.post(stateTicker)
    }

    override fun getView(): View = container

    override fun onSurfaceTextureAvailable(
        surfaceTexture: SurfaceTexture,
        width: Int,
        height: Int,
    ) {
        if (isDisposed) return
        hasRenderedFrame = false
        replaceOutputSurface(Surface(surfaceTexture))
        val player = mediaPlayer
        if (player == null) {
            preparePlayer()
        } else {
            try {
                player.setSurface(outputSurface)
                if (isPrepared) {
                    restorePositionOnAttachedSurface(player)
                    if (pendingPlay) startPlayer()
                }
            } catch (_: Throwable) {
                releasePlayer(player)
                playerError = "正在重新连接视频画面"
                preparePlayer()
            }
        }
    }

    override fun onSurfaceTextureSizeChanged(
        surfaceTexture: SurfaceTexture,
        width: Int,
        height: Int,
    ) {
        updateTextureLayout()
    }

    override fun onSurfaceTextureDestroyed(surfaceTexture: SurfaceTexture): Boolean {
        if (!isDisposed) {
            hasRenderedFrame = false
            val player = mediaPlayer
            if (isPreparing) {
                releasePlayer(player)
            } else if (isPrepared) {
                pendingSeekMilliseconds = safePosition()
                val wasPlaying = safeIsPlaying()
                if (wasPlaying) pendingPlay = true
                try {
                    if (wasPlaying) player?.pause()
                    player?.setSurface(null)
                } catch (_: Throwable) {
                    // The player can already be transitioning to a released state.
                }
            }
        }
        replaceOutputSurface(null)
        return true
    }

    override fun onSurfaceTextureUpdated(surfaceTexture: SurfaceTexture) {
        if (!hasRenderedFrame && !isDisposed) {
            hasRenderedFrame = true
            emitState()
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play" -> {
                pendingPlay = true
                if (mediaPlayer == null) preparePlayer()
                if (isPrepared) startPlayer()
                emitState()
                result.success(null)
            }

            "pause" -> {
                pendingPlay = false
                if (isPrepared && safeIsPlaying()) {
                    try {
                        mediaPlayer?.pause()
                    } catch (_: Throwable) {
                        playerError = "暂停视频失败"
                    }
                }
                emitState()
                result.success(null)
            }

            "seekTo" -> {
                val requested = (call.argument<Number>("milliseconds"))?.toInt()
                if (requested == null) {
                    result.error("invalid_position", "播放位置无效", null)
                    return
                }
                val duration = safeDuration()
                val target = if (duration > 0) {
                    requested.coerceIn(0, duration)
                } else {
                    requested.coerceAtLeast(0)
                }
                if (isPrepared) {
                    try {
                        mediaPlayer?.seekTo(target)
                    } catch (_: Throwable) {
                        playerError = "跳转播放位置失败"
                    }
                } else {
                    pendingSeekMilliseconds = target
                }
                emitState(positionOverride = target)
                result.success(null)
            }

            "setSpeed" -> {
                val requested = (call.argument<Number>("speed"))?.toFloat()
                if (requested == null || !requested.isFinite()) {
                    result.error("invalid_speed", "播放速度无效", null)
                    return
                }
                speed = requested.coerceIn(MIN_SPEED, MAX_SPEED)
                mediaPlayer?.let { player ->
                    if (isPrepared) applySpeed(player, speed)
                }
                emitState()
                result.success(null)
            }

            "setVolume" -> {
                val requested = (call.argument<Number>("volume"))?.toFloat()
                if (requested == null || !requested.isFinite()) {
                    result.error("invalid_volume", "媒体音量无效", null)
                    return
                }
                val target = requested.coerceIn(MIN_VOLUME, MAX_VOLUME)
                val player = mediaPlayer
                if (isPrepared && player != null && !applyVolume(player, target)) {
                    emitState()
                    result.error("set_volume_failed", "当前设备无法设置媒体音量", null)
                    return
                }
                volume = target
                emitState()
                result.success(null)
            }

            "snapshot" -> result.success(stateMap())
            else -> result.notImplemented()
        }
    }

    override fun onFlutterViewDetached() {
        pendingPlay = false
        if (isPrepared && safeIsPlaying()) {
            try {
                mediaPlayer?.pause()
            } catch (_: Throwable) {
                // Detaching must remain safe during activity teardown.
            }
        }
        emitState()
    }

    override fun dispose() {
        if (isDisposed) return
        isDisposed = true
        handler.removeCallbacks(stateTicker)
        channel.setMethodCallHandler(null)
        textureView.surfaceTextureListener = null
        replaceOutputSurface(null)
        releasePlayer(mediaPlayer)
    }

    private fun preparePlayer() {
        if (isDisposed || isPreparing || mediaPlayer != null || outputSurface == null) return
        val file = File(path)
        if (!file.isFile) {
            playerError = "本地视频文件不存在"
            emitState()
            return
        }

        isPreparing = true
        playerError = null
        val player = MediaPlayer()
        mediaPlayer = player
        try {
            player.setSurface(outputSurface)
            player.setDataSource(file.absolutePath)
            player.setOnPreparedListener { preparedPlayer ->
                if (isDisposed || mediaPlayer !== preparedPlayer) return@setOnPreparedListener
                isPreparing = false
                isPrepared = true
                playerError = null
                videoWidth = preparedPlayer.videoWidth
                videoHeight = preparedPlayer.videoHeight
                updateTextureLayout()
                applySpeed(preparedPlayer, speed)
                applyVolume(preparedPlayer, volume)
                restorePositionOnAttachedSurface(preparedPlayer)
                if (pendingPlay) startPlayer()
                emitState()
            }
            player.setOnVideoSizeChangedListener { callbackPlayer, width, height ->
                if (isDisposed || mediaPlayer !== callbackPlayer) {
                    return@setOnVideoSizeChangedListener
                }
                videoWidth = width
                videoHeight = height
                updateTextureLayout()
            }
            player.setOnCompletionListener { completedPlayer ->
                if (mediaPlayer !== completedPlayer) return@setOnCompletionListener
                pendingPlay = false
                emitState()
            }
            player.setOnErrorListener { failedPlayer, what, extra ->
                if (mediaPlayer !== failedPlayer) return@setOnErrorListener true
                isPreparing = false
                isPrepared = false
                pendingPlay = false
                playerError = "无法播放这个视频（$what/$extra）"
                releasePlayer(failedPlayer)
                emitState()
                true
            }
            player.prepareAsync()
        } catch (_: Throwable) {
            pendingPlay = false
            playerError = "无法打开这个本地视频"
            releasePlayer(player)
            emitState()
        }
    }

    private fun restorePositionOnAttachedSurface(player: MediaPlayer) {
        val position = pendingSeekMilliseconds ?: return
        try {
            val duration = safeDuration()
            val target = if (duration > 0) position.coerceIn(0, duration) else position
            player.seekTo(target)
            pendingSeekMilliseconds = null
        } catch (_: Throwable) {
            playerError = "恢复视频画面失败"
        }
    }

    private fun releasePlayer(player: MediaPlayer?) {
        if (player == null) return
        if (mediaPlayer === player) mediaPlayer = null
        isPreparing = false
        isPrepared = false
        hasRenderedFrame = false
        videoWidth = 0
        videoHeight = 0
        try {
            player.setOnPreparedListener(null)
            player.setOnVideoSizeChangedListener(null)
            player.setOnCompletionListener(null)
            player.setOnErrorListener(null)
        } catch (_: Throwable) {
            // Releasing the codec remains the priority.
        }
        try {
            player.release()
        } catch (_: Throwable) {
            // The player may already have been released by the platform.
        }
    }

    private fun startPlayer() {
        val player = mediaPlayer ?: return
        if (!isPrepared || outputSurface == null) return
        try {
            player.start()
            playerError = null
        } catch (_: Throwable) {
            playerError = "播放视频失败"
        }
    }

    private fun applySpeed(player: MediaPlayer, value: Float) {
        try {
            val wasPlaying = safeIsPlaying()
            player.playbackParams = player.playbackParams.setSpeed(value)
            if (!wasPlaying) player.pause()
            playerError = null
        } catch (_: Throwable) {
            playerError = "当前设备无法设置该倍速"
        }
    }

    private fun applyVolume(player: MediaPlayer, value: Float): Boolean {
        return try {
            player.setVolume(value, value)
            true
        } catch (_: Throwable) {
            playerError = "当前设备无法设置媒体音量"
            false
        }
    }

    private fun replaceOutputSurface(surface: Surface?) {
        val previous = outputSurface
        outputSurface = surface
        previous?.release()
    }

    private fun updateTextureLayout() {
        if (videoWidth <= 0 || videoHeight <= 0) return
        val availableWidth = container.width
        val availableHeight = container.height
        if (availableWidth <= 0 || availableHeight <= 0) return

        val videoRatio = videoWidth.toDouble() / videoHeight
        val containerRatio = availableWidth.toDouble() / availableHeight
        val targetWidth: Int
        val targetHeight: Int
        if (videoRatio > containerRatio) {
            targetWidth = availableWidth
            targetHeight = (availableWidth / videoRatio).roundToInt()
        } else {
            targetHeight = availableHeight
            targetWidth = (availableHeight * videoRatio).roundToInt()
        }

        val current = textureView.layoutParams as FrameLayout.LayoutParams
        if (current.width == targetWidth && current.height == targetHeight) return
        textureView.layoutParams = FrameLayout.LayoutParams(
            targetWidth,
            targetHeight,
            Gravity.CENTER,
        )
    }

    private fun safeDuration(): Int {
        if (!isPrepared) return 0
        return try {
            mediaPlayer?.duration?.coerceAtLeast(0) ?: 0
        } catch (_: Throwable) {
            0
        }
    }

    private fun safePosition(): Int {
        if (!isPrepared) return pendingSeekMilliseconds ?: 0
        return try {
            mediaPlayer?.currentPosition?.coerceAtLeast(0) ?: 0
        } catch (_: Throwable) {
            0
        }
    }

    private fun safeIsPlaying(): Boolean {
        if (!isPrepared) return false
        return try {
            mediaPlayer?.isPlaying == true
        } catch (_: Throwable) {
            false
        }
    }

    private fun stateMap(positionOverride: Int? = null): Map<String, Any?> {
        return mapOf(
            "ready" to isPrepared,
            "playing" to safeIsPlaying(),
            "positionMilliseconds" to (positionOverride ?: safePosition()),
            "durationMilliseconds" to safeDuration(),
            "speed" to speed.toDouble(),
            "volume" to volume.toDouble(),
            "hasVideoFrame" to hasRenderedFrame,
            "videoWidth" to videoWidth,
            "videoHeight" to videoHeight,
            "error" to playerError,
        )
    }

    private fun emitState(positionOverride: Int? = null) {
        if (isDisposed) return
        channel.invokeMethod("state", stateMap(positionOverride))
    }

    companion object {
        private const val CHANNEL_PREFIX = "com.guitarpal/local_video_player"
        private const val STATE_INTERVAL_MS = 200L
        private const val MIN_SPEED = 0.5f
        private const val MAX_SPEED = 2.0f
        private const val MIN_VOLUME = 0.0f
        private const val MAX_VOLUME = 1.0f
    }
}
