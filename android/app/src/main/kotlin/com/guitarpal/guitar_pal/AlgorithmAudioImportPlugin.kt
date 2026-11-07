package com.guitarpal.guitar_pal

import android.app.Activity
import android.content.Intent
import android.media.MediaExtractor
import android.media.MediaFormat
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

/** Bounded private audio copies for explicit experimental-server uploads. */
class AlgorithmAudioImportPlugin(private val activity: Activity, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "com.guitarpal/algorithm_audio_import")
    private var pending: MethodChannel.Result? = null
    private val root get() = File(activity.filesDir, "algorithm_inputs")

    init { channel.setMethodCallHandler(this) }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "serviceConfiguration" -> result.success(mapOf("baseUrl" to BuildConfig.ALGORITHM_API_BASE_URL))
            "extractVideoAudio" -> Thread {
                try {
                    val info = VideoAudioExtraction.extract(requireNotNull(call.argument<String>("path")),
                        requireNotNull(call.argument<Number>("startMs")).toLong(), requireNotNull(call.argument<Number>("endMs")).toLong(),
                        File(activity.filesDir, "guitarpal_videos"), root,
                        call.argument<Number>("sourceDurationMs")?.toLong())
                    activity.runOnUiThread { result.success(info) }
                } catch (e: Throwable) { activity.runOnUiThread { result.error("extraction_failed", e.message ?: "无法提取视频音频", null) } }
            }.start()
            "pickAudio" -> {
                if (pending != null) { result.error("picker_busy", "音频选择器已经打开", null); return }
                pending = result
                try {
                    activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "audio/*"
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }, REQUEST)
                } catch (_: Throwable) {
                    pending = null
                    result.error("picker_unavailable", "无法打开音频选择器", null)
                }
            }
            "deleteInput" -> {
                val path = call.argument<String>("path")
                try {
                    val file = File(requireNotNull(path)).canonicalFile
                    require(file.parentFile == root.canonicalFile) { "音频不属于应用导入目录" }
                    if (file.exists() && !file.delete()) throw IllegalStateException("无法删除音频副本")
                    result.success(null)
                } catch (_: Throwable) { result.error("invalid_input", "无法删除此音频副本", null) }
            }
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val result = pending ?: return true
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { result.success(null); return true }
        Thread {
            var target: File? = null
            try {
                val name = activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                    if (it.moveToFirst()) it.getString(0) else null
                } ?: "音频.m4a"
                val extension = name.substringAfterLast('.', "").lowercase()
                require(extension in setOf("mp3", "wav", "flac", "ogg", "m4a")) { "请选择 MP3、WAV、FLAC、OGG 或 M4A 音频" }
                root.mkdirs()
                val file = File(root, "${UUID.randomUUID()}.$extension")
                target = file
                var bytes = 0L
                activity.contentResolver.openInputStream(uri)!!.use { input ->
                    file.outputStream().use { output ->
                        val buffer = ByteArray(65536)
                        while (true) {
                            val read = input.read(buffer)
                            if (read < 0) break
                            bytes += read
                            require(bytes <= MAX_BYTES) { "音频不能超过 50 MiB" }
                            output.write(buffer, 0, read)
                        }
                    }
                }
                require(bytes > 0) { "所选音频为空" }
                val extractor = MediaExtractor()
                val durationMs = try {
                    extractor.setDataSource(file.absolutePath)
                    val format = (0 until extractor.trackCount).map { extractor.getTrackFormat(it) }
                        .firstOrNull { it.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true }
                        ?: throw IllegalArgumentException("文件没有可解码的音轨")
                    require(format.containsKey(MediaFormat.KEY_DURATION)) { "无法读取音频时长" }
                    format.getLong(MediaFormat.KEY_DURATION) / 1000
                } finally { extractor.release() }
                require(durationMs in 2000L..600000L) { "请选择 2 秒到 10 分钟的音频" }
                val info = mapOf("path" to file.absolutePath, "name" to name,
                    "sizeBytes" to bytes, "durationMs" to durationMs)
                activity.runOnUiThread { result.success(info) }
            } catch (error: Throwable) {
                target?.delete()
                activity.runOnUiThread { result.error("audio_import_failed", error.message ?: "音频导入失败", null) }
            }
        }.start()
        return true
    }

    fun dispose() {
        pending?.error("picker_closed", "音频选择器已关闭", null)
        pending = null
        channel.setMethodCallHandler(null)
    }

    companion object {
        private const val REQUEST = 7042
        private const val MAX_BYTES = 50L * 1024 * 1024
    }
}
