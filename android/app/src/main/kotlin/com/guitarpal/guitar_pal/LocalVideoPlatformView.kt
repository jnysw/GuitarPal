package com.guitarpal.guitar_pal

import android.content.Context
import android.graphics.Color
import android.graphics.SurfaceTexture
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.os.Build
import android.os.SystemClock
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
    private val context: Context,
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
    private var appliedVideoVolume = 1.0f
    private var videoWidth = 0
    private var videoHeight = 0
    private var hasRenderedFrame = false
    private var playerError: String? = null
    private var stems: StemMixEngine? = null
    private var stemGains = mapOf<String, Double>()
    private var stemStart = 0L
    private var stemDuration = 0L
    private var stemsActive = false
    private var stemGeneration = 0
    private var pendingStemLoad: MethodChannel.Result? = null
    private var lastPictureCorrection = 0L
    private var ended = false

    private val stateTicker = object : Runnable {
        override fun run() {
            if (isDisposed) return
            synchronizePicture()
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
                stems?.pause()
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
            "loadStems" -> {
                val tracks = call.argument<List<Map<String, Any?>>>("tracks")
                val start = call.argument<Number>("startMs")?.toLong()
                val duration = call.argument<Number>("durationMs")?.toLong()
                if (tracks == null || start == null || duration == null || start < 0 || duration < 2000 || start + duration > safeDuration()) {
                    result.error("invalid_stems", "分轨区间超出当前视频", null); return
                }
                pauseAll(); clearStemEngine()
                val token = stemGeneration
                pendingStemLoad = result
                Thread {
                    try {
                        val engine = StemMixEngine.open(tracks, File(context.filesDir, "algorithm_stems"))
                        handler.post {
                            if (isDisposed || token != stemGeneration) engine.close()
                            else {
                                try {
                                    require(kotlin.math.abs((engine.snapshot()["durationMs"] as Long) - duration) <= 100) { "分轨时长与视频分析区间不一致" }
                                    stems = engine; stemStart = start; stemDuration = duration
                                    stemGains = tracks.associate { it["id"] as String to 1.0 }
                                    configureStems()
                                    val target = safePosition().toLong().takeIf { it in start until start + duration } ?: start
                                    routeStems(target, false); seekPicture(target.toInt())
                                    pendingStemLoad = null; result.success(null); emitState(positionOverride = target.toInt())
                                } catch (e: Throwable) { pendingStemLoad = null; engine.close(); clearStemEngine(); result.error("stem_load_failed", e.message, null) }
                            }
                        }
                    } catch (e: Throwable) { handler.post { if (token == stemGeneration && !isDisposed) { pendingStemLoad = null; result.error("stem_load_failed", e.message, null) } } }
                }.start()
            }
            "setStemGains" -> {
                val raw = call.argument<Map<String, Number>>("gains")
                val previous = stemGains
                try {
                    require(raw != null && raw.keys == stemGains.keys)
                    stemGains = raw.mapValues { it.value.toDouble() }; configureStems()
                    result.success(null)
                } catch (e: Throwable) { stemGains = previous; result.error("invalid_gains", e.message, null) }
            }
            "clearStems" -> {
                val position = effectivePosition(); pauseAll(); clearStemEngine(); seekPicture(position)
                emitState(positionOverride = position); result.success(null)
            }
            "play" -> {
                pendingPlay = true
                if (mediaPlayer == null) preparePlayer()
                if (isPrepared) startPlayer()
                emitState()
                result.success(null)
            }

            "pause" -> {
                stems?.pause()
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
                        ended = false
                        routeStems(target.toLong(), safeIsPlaying())
                        seekPicture(target)
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
                try { configureStems() } catch (_: Throwable) { pauseAll(); playerError = "当前设备无法同步该倍速" }
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
                if (isPrepared && player != null && !applyVolume(player, if (stemsActive) 0f else target)) {
                    emitState()
                    result.error("set_volume_failed", "当前设备无法设置媒体音量", null)
                    return
                }
                volume = target
                try { configureStems() } catch (_: Throwable) { pauseAll(); playerError = "无法调节分轨音量" }
                emitState()
                result.success(null)
            }

            "snapshot" -> result.success(stateMap())
            else -> result.notImplemented()
        }
    }

    override fun onFlutterViewDetached() {
        stems?.pause()
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
        clearStemEngine()
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
                applyVolume(preparedPlayer, if (stemsActive) 0f else volume)
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
                if (stemsActive) {
                    val audio = stems?.snapshot()
                    if (audio?.get("isPlaying") == true && (audio["positionMs"] as Long) < stemDuration - 20) {
                        seekPicture(effectivePosition()); completedPlayer.start(); return@setOnCompletionListener
                    }
                }
                pendingPlay = false
                ended = true
                stems?.pause()
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
            ended = false
            routeStems(effectivePosition().toLong(), true)
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
            appliedVideoVolume = value
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

    private fun configureStems() {
        stems?.configure(mapOf("gains" to stemGains, "master" to volume.toDouble(), "speed" to speed.toDouble(), "loopStartMs" to null, "loopEndMs" to null))
    }
    private fun pauseAll() {
        stems?.pause(); pendingPlay = false
        if (safeIsPlaying()) mediaPlayer?.pause()
    }
    private fun clearStemEngine() {
        stemGeneration++
        pendingStemLoad?.error("stem_load_interrupted", "视频分轨载入已停止", null); pendingStemLoad = null
        stems?.close(); stems = null; stemsActive = false; stemGains = emptyMap()
        if (isPrepared) applyVolume(mediaPlayer!!, volume)
    }
    private fun routeStems(position: Long, resume: Boolean) {
        val engine = stems
        val active = engine != null && position in stemStart until stemStart + stemDuration
        engine?.pause(); stemsActive = active
        if (active) {
            engine!!.seek(position - stemStart)
            if (isPrepared) applyVolume(mediaPlayer!!, 0f)
            if (resume) engine.play()
        } else if (isPrepared) applyVolume(mediaPlayer!!, volume)
    }
    private fun effectivePosition(): Int {
        val state = if (stemsActive) stems?.snapshot() else null
        return if (state?.get("isLoaded") == true) (stemStart + (state["positionMs"] as Long)).toInt() else safePosition()
    }
    private fun seekPicture(position: Int) {
        if (!isPrepared) { pendingSeekMilliseconds = position; return }
        if (Build.VERSION.SDK_INT >= 26) mediaPlayer?.seekTo(position.toLong(), MediaPlayer.SEEK_CLOSEST) else mediaPlayer?.seekTo(position)
    }
    private fun synchronizePicture() {
        val engine = stems ?: return
        if (!isPrepared || !safeIsPlaying()) return
        try {
            if (!stemsActive) {
                val position = safePosition().toLong()
                if (position in stemStart until stemStart + stemDuration) routeStems(position, true)
                return
            }
            val state = engine.snapshot()
            if (state["error"] != null) throw IllegalStateException(state["error"] as String)
            val target = stemStart + (state["positionMs"] as Long)
            if (state["isPlaying"] != true) {
                if (target >= stemStart + stemDuration - 2) {
                    stemsActive = false; engine.pause(); seekPicture(target.toInt()); applyVolume(mediaPlayer!!, volume)
                } else { pauseAll() }
                return
            }
            val now = SystemClock.elapsedRealtime()
            if (kotlin.math.abs(safePosition() - target) > 120 && now - lastPictureCorrection > 500) {
                seekPicture(target.toInt()); lastPictureCorrection = now
            }
        } catch (_: Throwable) { pauseAll(); clearStemEngine(); playerError = "分轨播放中断，已恢复原声音轨" }
    }

    private fun stateMap(positionOverride: Int? = null): Map<String, Any?> {
        return mapOf(
            "ready" to isPrepared,
            "playing" to safeIsPlaying(),
            "positionMilliseconds" to (positionOverride ?: effectivePosition()),
            "durationMilliseconds" to safeDuration(),
            "speed" to speed.toDouble(),
            "volume" to volume.toDouble(),
            "hasVideoFrame" to hasRenderedFrame,
            "videoWidth" to videoWidth,
            "videoHeight" to videoHeight,
            "error" to playerError,
            "videoAudioVolume" to appliedVideoVolume.toDouble(), "videoPositionMilliseconds" to safePosition(),
            "stemsLoaded" to (stems != null), "stemsActive" to stemsActive, "ended" to ended,
        )
    }

    private fun emitState(positionOverride: Int? = null) {
        if (isDisposed) return
        channel.invokeMethod("state", stateMap(positionOverride))
    }

    companion object {
        private const val CHANNEL_PREFIX = "com.guitarpal/local_video_player"
        private const val STATE_INTERVAL_MS = 100L
        private const val MIN_SPEED = 0.5f
        private const val MAX_SPEED = 2.0f
        private const val MIN_VOLUME = 0.0f
        private const val MAX_VOLUME = 1.0f
    }
}
