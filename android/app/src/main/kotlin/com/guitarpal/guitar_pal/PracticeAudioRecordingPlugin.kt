package com.guitarpal.guitar_pal

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class PracticeAudioRecordingPlugin(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private data class ActiveRecording(
        val recorder: MediaRecorder,
        val pendingFile: File,
        val finalFile: File,
        val relativePath: String,
        val startedAtElapsedMilliseconds: Long,
    )

    private val channel = MethodChannel(messenger, channelName)
    private val permissionPreferences = activity.applicationContext.getSharedPreferences(
        permissionPreferencesName,
        Context.MODE_PRIVATE,
    )
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var activeRecording: ActiveRecording? = null
    private var playbackPlayer: MediaPlayer? = null
    private var playbackRelativePath: String? = null
    private val analysisExecutor = Executors.newSingleThreadExecutor()
    @Volatile private var disposed = false

    init {
        recordingDirectory().mkdirs()
        cleanupPendingFiles()
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "permissionStatus" -> result.success(permissionStatus())
            "requestPermission" -> requestPermission(result)
            "openAppSettings" -> openAppSettings(result)
            "start" -> start(call.argument<String>("recordingId"), result)
            "stop" -> stop(result)
            "cancel" -> {
                cancelActiveRecording()
                result.success(null)
            }
            "isRecording" -> result.success(activeRecording != null)
            "playRecording" -> playRecording(
                call.argument<String>("relativePath"),
                call.argument<Number>("positionMilliseconds")?.toInt() ?: 0,
                result,
            )
            "pausePlayback" -> pausePlayback(result)
            "seekPlayback" -> seekPlayback(
                call.argument<Number>("positionMilliseconds")?.toInt(),
                result,
            )
            "playbackSnapshot" -> playbackSnapshot(result)
            "stopPlayback" -> {
                stopPlayback()
                result.success(null)
            }
            "resolveAbsolutePath" -> resolveAbsolutePath(
                call.argument<String>("relativePath"),
                result,
            )
            "deleteRecording" -> deleteRecording(
                call.argument<String>("relativePath"),
                result,
            )
            "analyzeRecording" -> analyzeRecording(
                call.argument<String>("relativePath"),
                result,
            )
            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != microphonePermissionRequestCode) return false
        val result = pendingPermissionResult ?: return true
        pendingPermissionResult = null
        val granted = permissions.indices.any { index ->
            permissions[index] == Manifest.permission.RECORD_AUDIO &&
                grantResults.getOrNull(index) == PackageManager.PERMISSION_GRANTED
        }
        result.success(if (granted) permissionGranted else permissionStatus())
        return true
    }

    fun onHostStop() {
        cancelActiveRecording()
        stopPlayback()
    }

    fun dispose() {
        disposed = true
        analysisExecutor.shutdownNow()
        pendingPermissionResult?.error(
            "permission_request_closed",
            "麦克风权限请求已关闭",
            null,
        )
        pendingPermissionResult = null
        cancelActiveRecording()
        stopPlayback()
        channel.setMethodCallHandler(null)
    }

    private fun analyzeRecording(relativePath: String?, result: MethodChannel.Result) {
        val file = validatedRecordingFile(relativePath)
        if (file == null || !file.isFile) {
            result.error("recording_not_found", "录音文件不存在", null)
            return
        }
        analysisExecutor.execute {
            try {
                val analysis = PracticeAudioAnalyzer.analyze(file)
                if (!disposed) activity.runOnUiThread { result.success(analysis) }
            } catch (error: Throwable) {
                if (!disposed) {
                    activity.runOnUiThread {
                        result.error(
                            "recording_analysis_failed",
                            error.message ?: "无法分析录音",
                            null,
                        )
                    }
                }
            }
        }
    }

    private fun permissionStatus(): String {
        if (
            activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return permissionGranted
        }
        val requestedBefore = permissionPreferences.getBoolean(requestedBeforeKey, false)
        return if (
            requestedBefore &&
            !activity.shouldShowRequestPermissionRationale(Manifest.permission.RECORD_AUDIO)
        ) {
            permissionPermanentlyDenied
        } else {
            permissionDenied
        }
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (permissionStatus() == permissionGranted) {
            result.success(permissionGranted)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("permission_request_busy", "麦克风权限正在请求中", null)
            return
        }
        pendingPermissionResult = result
        permissionPreferences.edit().putBoolean(requestedBeforeKey, true).apply()
        activity.requestPermissions(
            arrayOf(Manifest.permission.RECORD_AUDIO),
            microphonePermissionRequestCode,
        )
    }

    private fun openAppSettings(result: MethodChannel.Result) {
        try {
            activity.startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:${activity.packageName}"),
                ),
            )
            result.success(null)
        } catch (error: Throwable) {
            result.error(
                "settings_unavailable",
                error.message ?: "无法打开应用设置",
                null,
            )
        }
    }

    private fun start(recordingId: String?, result: MethodChannel.Result) {
        if (permissionStatus() != permissionGranted) {
            result.error("microphone_permission_denied", "尚未获得麦克风权限", null)
            return
        }
        if (activeRecording != null) {
            result.error("recording_busy", "已有录音正在进行", null)
            return
        }
        if (recordingId == null || !recordingId.matches(safeRecordingId)) {
            result.error("invalid_recording_id", "录音 ID 无效", null)
            return
        }

        stopPlayback()
        val directory = recordingDirectory().apply { mkdirs() }
        val pendingFile = File(directory, "$recordingId.pending.m4a")
        val finalFile = File(directory, "$recordingId.m4a")
        if (finalFile.exists()) {
            result.error("recording_exists", "该录音文件已经存在", null)
            return
        }
        pendingFile.delete()

        var recorder: MediaRecorder? = null
        try {
            recorder = createMediaRecorder().apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioEncodingBitRate(audioBitRate)
                setAudioSamplingRate(audioSampleRate)
                setOutputFile(pendingFile.absolutePath)
                prepare()
                start()
            }
            activeRecording = ActiveRecording(
                recorder = recorder,
                pendingFile = pendingFile,
                finalFile = finalFile,
                relativePath = "$recordingDirectoryName/${finalFile.name}",
                startedAtElapsedMilliseconds = SystemClock.elapsedRealtime(),
            )
            result.success(null)
        } catch (error: Throwable) {
            try {
                recorder?.release()
            } catch (_: Throwable) {
                // Ignore a second failure while unwinding recorder setup.
            }
            pendingFile.delete()
            result.error(
                "recording_start_failed",
                error.message ?: "无法开始录音",
                null,
            )
        }
    }

    private fun stop(result: MethodChannel.Result) {
        val active = activeRecording
        if (active == null) {
            result.error("not_recording", "当前没有正在进行的录音", null)
            return
        }
        activeRecording = null

        try {
            active.recorder.stop()
            val durationMilliseconds = (
                SystemClock.elapsedRealtime() - active.startedAtElapsedMilliseconds
            ).coerceAtLeast(1L)
            active.recorder.release()
            if (!active.pendingFile.isFile || active.pendingFile.length() <= 0L) {
                throw IllegalStateException("录音文件为空")
            }
            if (!active.pendingFile.renameTo(active.finalFile)) {
                active.pendingFile.inputStream().use { source ->
                    active.finalFile.outputStream().use { target -> source.copyTo(target) }
                }
                if (!active.pendingFile.delete()) {
                    active.finalFile.delete()
                    throw IllegalStateException("无法提交录音文件")
                }
            }
            result.success(
                mapOf(
                    "relativePath" to active.relativePath,
                    "absolutePath" to active.finalFile.absolutePath,
                    "durationMilliseconds" to durationMilliseconds,
                ),
            )
        } catch (error: Throwable) {
            try {
                active.recorder.release()
            } catch (_: Throwable) {
                // Ignore release errors after an unsuccessful stop.
            }
            active.pendingFile.delete()
            active.finalFile.delete()
            result.error(
                "recording_stop_failed",
                error.message ?: "无法保存录音",
                null,
            )
        }
    }

    private fun resolveAbsolutePath(relativePath: String?, result: MethodChannel.Result) {
        val file = validatedRecordingFile(relativePath)
        if (file == null || !file.isFile) {
            result.error("recording_not_found", "录音文件不存在", null)
            return
        }
        result.success(file.absolutePath)
    }

    private fun deleteRecording(relativePath: String?, result: MethodChannel.Result) {
        val file = validatedRecordingFile(relativePath)
        if (file == null) {
            result.error("invalid_recording_path", "录音文件路径无效", null)
            return
        }
        if (playbackRelativePath == relativePath) stopPlayback()
        if (file.exists() && !file.delete()) {
            result.error("recording_delete_failed", "无法删除录音文件", null)
            return
        }
        result.success(null)
    }

    private fun playRecording(
        relativePath: String?,
        positionMilliseconds: Int,
        result: MethodChannel.Result,
    ) {
        if (activeRecording != null) {
            result.error("recording_busy", "录音过程中不能回听", null)
            return
        }
        val file = validatedRecordingFile(relativePath)
        if (file == null || !file.isFile) {
            result.error("recording_not_found", "录音文件不存在", null)
            return
        }

        stopPlayback()
        var player: MediaPlayer? = null
        try {
            player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build(),
                )
                setDataSource(file.absolutePath)
                prepare()
                seekTo(positionMilliseconds.coerceIn(0, duration.coerceAtLeast(0)))
                start()
            }
            playbackPlayer = player
            playbackRelativePath = relativePath
            result.success(null)
        } catch (error: Throwable) {
            try {
                player?.release()
            } catch (_: Throwable) {
                // Ignore release failures while unwinding playback setup.
            }
            playbackPlayer = null
            playbackRelativePath = null
            result.error(
                "recording_playback_failed",
                error.message ?: "无法播放录音",
                null,
            )
        }
    }

    private fun pausePlayback(result: MethodChannel.Result) {
        val player = playbackPlayer
        if (player == null) {
            result.success(null)
            return
        }
        try {
            if (player.isPlaying) player.pause()
            result.success(null)
        } catch (error: Throwable) {
            result.error(
                "recording_playback_failed",
                error.message ?: "无法暂停录音",
                null,
            )
        }
    }

    private fun seekPlayback(positionMilliseconds: Int?, result: MethodChannel.Result) {
        if (positionMilliseconds == null) {
            result.error("invalid_playback_position", "播放位置无效", null)
            return
        }
        val player = playbackPlayer
        if (player == null) {
            result.error("recording_playback_unavailable", "录音尚未加载", null)
            return
        }
        try {
            player.seekTo(positionMilliseconds.coerceIn(0, player.duration.coerceAtLeast(0)))
            result.success(null)
        } catch (error: Throwable) {
            result.error(
                "recording_playback_failed",
                error.message ?: "无法跳转录音进度",
                null,
            )
        }
    }

    private fun playbackSnapshot(result: MethodChannel.Result) {
        val player = playbackPlayer
        if (player == null) {
            result.success(
                mapOf(
                    "isLoaded" to false,
                    "isPlaying" to false,
                    "positionMilliseconds" to 0,
                    "durationMilliseconds" to 0,
                ),
            )
            return
        }
        try {
            result.success(
                mapOf(
                    "isLoaded" to true,
                    "isPlaying" to player.isPlaying,
                    "positionMilliseconds" to player.currentPosition,
                    "durationMilliseconds" to player.duration.coerceAtLeast(0),
                ),
            )
        } catch (error: Throwable) {
            result.error(
                "recording_playback_failed",
                error.message ?: "无法读取录音播放状态",
                null,
            )
        }
    }

    private fun stopPlayback() {
        val player = playbackPlayer
        playbackPlayer = null
        playbackRelativePath = null
        if (player == null) return
        try {
            player.stop()
        } catch (_: Throwable) {
            // A completed or failed player may no longer accept stop().
        }
        try {
            player.release()
        } catch (_: Throwable) {
            // Ignore release failures during host teardown.
        }
    }

    private fun cancelActiveRecording() {
        val active = activeRecording ?: return
        activeRecording = null
        try {
            active.recorder.stop()
        } catch (_: Throwable) {
            // Very short or interrupted takes may not contain a valid frame.
        }
        try {
            active.recorder.release()
        } catch (_: Throwable) {
            // The recorder may already have released native resources.
        }
        active.pendingFile.delete()
        active.finalFile.delete()
    }

    @Suppress("DEPRECATION")
    private fun createMediaRecorder(): MediaRecorder {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(activity)
        } else {
            MediaRecorder()
        }
    }

    private fun validatedRecordingFile(relativePath: String?): File? {
        if (
            relativePath == null ||
            !relativePath.matches(safeRelativeRecordingPath)
        ) {
            return null
        }
        val root = recordingDirectory().canonicalFile
        val file = File(activity.filesDir, relativePath).canonicalFile
        return file.takeIf { it.parentFile == root }
    }

    private fun cleanupPendingFiles() {
        recordingDirectory().listFiles()
            ?.filter { it.isFile && it.name.endsWith(".pending.m4a") }
            ?.forEach { it.delete() }
    }

    private fun recordingDirectory() = File(activity.filesDir, recordingDirectoryName)

    companion object {
        private const val channelName = "com.guitarpal/practice_audio_recording"
        private const val recordingDirectoryName = "practice_recordings"
        private const val permissionPreferencesName = "guitarpal_audio_recording"
        private const val requestedBeforeKey = "microphone_permission_requested"
        private const val microphonePermissionRequestCode = 7413
        private const val permissionGranted = "granted"
        private const val permissionDenied = "denied"
        private const val permissionPermanentlyDenied = "permanentlyDenied"
        private const val audioBitRate = 128_000
        private const val audioSampleRate = 44_100
        private val safeRecordingId = Regex("^[A-Za-z0-9_-]{1,100}$")
        private val safeRelativeRecordingPath = Regex(
            "^$recordingDirectoryName/[A-Za-z0-9_-]{1,100}\\.m4a$",
        )
    }
}
