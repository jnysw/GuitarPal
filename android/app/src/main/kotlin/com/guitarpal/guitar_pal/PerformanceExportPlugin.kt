package com.guitarpal.guitar_pal

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.CancellationException
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.abs

/** No network, no recording DB writes. Only complete WAVs are exposed to Android document/share UIs. */
internal class PerformanceExportPlugin(private val activity: Activity, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "com.guitarpal/performance_export")
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val root = File(activity.filesDir, "performance_exports").apply { mkdirs() }
    private val scratch = File(activity.cacheDir, "performance_export_work").apply { mkdirs() }
    @Volatile private var cancelled = AtomicBoolean(false)
    @Volatile private var busy = false
    @Volatile private var progress = 0.0
    @Volatile private var stage = ""
    private var player: MediaPlayer? = null
    private var saveResult: MethodChannel.Result? = null
    private var saveFile: File? = null
    private var disposed = false
    init {
        channel.setMethodCallHandler(this)
        val before = System.currentTimeMillis() - 7L * 24 * 3600000
        root.listFiles()?.filter { it.lastModified() < before }?.forEach { it.delete() }
        scratch.listFiles()?.filter { it.lastModified() < before }?.forEach { it.deleteRecursively() }
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "render" -> {
                    check(!busy) { "已有导出任务，请稍后重试" }
                    stopPlayback()
                    val args = call.arguments as Map<*, *>
                    val flag = AtomicBoolean(false); cancelled = flag; busy = true; progress = 0.0; stage = "检查本机文件"
                    worker.execute {
                        try {
                            val value = render(args, flag)
                            main.post { result.success(value) }
                        } catch (_: CancellationException) {
                            main.post { result.error("cancelled", "导出已取消，原始录音仍保留", null) }
                        } catch (e: Exception) {
                            main.post { result.error("export_failed", if (e is IllegalArgumentException || e is IllegalStateException) e.message else "导出失败，请检查本机空间后重试", null) }
                        } finally { busy = false }
                    }
                }
                "snapshot" -> result.success(mapOf("progress" to progress, "stage" to stage, "playing" to (player?.isPlaying == true)))
                "cancel" -> { cancelled.set(true); result.success(null) }
                "play" -> {
                    stopPlayback()
                    val file = exported(call.argument<String>("id"))
                    val volume = (call.argument<Number>("volume")?.toFloat() ?: 1f).also { require(it.isFinite() && it in 0f..1f) }
                    player = MediaPlayer().apply { setDataSource(file.absolutePath); prepare(); setVolume(volume, volume); start() }
                    result.success(null)
                }
                "discard" -> { stopPlayback(); check(exported(call.argument<String>("id")).delete()); result.success(null) }
                "stop" -> { stopPlayback(); result.success(null) }
                "share" -> {
                    stopPlayback()
                    val file = exported(call.argument<String>("id"))
                    val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.performance_exports", file)
                    val send = Intent(Intent.ACTION_SEND).apply {
                        type = "audio/wav"; putExtra(Intent.EXTRA_STREAM, uri)
                        clipData = ClipData.newRawUri("演奏作品", uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    activity.startActivity(Intent.createChooser(send, "分享演奏音频")); result.success(null)
                }
                "save" -> {
                    check(saveResult == null) { "文件选择窗口已打开" }
                    stopPlayback()
                    val file = exported(call.argument<String>("id"))
                    val title = call.argument<String>("title").orEmpty().replace(Regex("[\\\\/:*?\"<>|\\p{Cntrl}]"), "_").take(80).ifBlank { "GuitarPal演奏" }
                    saveFile = file; saveResult = result
                    try {
                        activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE); type = "audio/wav"
                            putExtra(Intent.EXTRA_TITLE, "$title.wav")
                        }, REQUEST_SAVE)
                    } catch (e: Exception) { saveResult = null; saveFile = null; throw e }
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) { result.error("export_unavailable", e.message ?: "音频操作未完成", null) }
    }
    private fun render(args: Map<*, *>, flag: AtomicBoolean): Map<String, Any> {
        fun checkCancel() { if (flag.get()) throw CancellationException() }
        fun number(key: String): Double = (args[key] as Number).toDouble().also { require(it.isFinite()) }
        fun integer(key: String): Int = number(key).also { require(it == it.toInt().toDouble()) }.toInt()
        val takeId = args["takeId"] as String
        require(Regex("[a-zA-Z0-9_-]{1,128}").matches(takeId)) { "录音标识无效" }
        val mic = File(activity.filesDir, "practice_recordings/$takeId.m4a").canonicalFile
        require(mic.parentFile == File(activity.filesDir, "practice_recordings").canonicalFile && mic.isFile && mic.length() in 1..100L * 1024 * 1024) { "原始录音无法读取" }
        val duration = integer("durationMs"); require(duration in 1..1250000)
        require(number("speed") == 1.0 || (args["tracks"] as List<*>).isEmpty()) { "当前混音导出仅支持 1.00× 伴奏" }
        val tracks = args["tracks"] as List<*>; require(tracks.size <= 16)
        val stemRoot = File(activity.filesDir, "algorithm_stems").canonicalFile
        val paths = tracks.map {
            val m = it as Map<*, *>; val file = File(m["path"] as String).canonicalFile
            require(file.parentFile == stemRoot && file.isFile && file.extension in setOf("wav", "flac")) { "本机伴奏不完整，请返回准备页补齐" }; file
        }
        require(paths.toSet().size == paths.size)
        val identity = (paths + mic).associateWith { "${it.length()}:${it.lastModified()}" }
        var decodeSpace = 0L
        for (p in paths) if (p.extension == "flac") {
            val header = ByteArray(26)
            java.io.RandomAccessFile(p, "r").use { it.readFully(header) }
            val packed = java.nio.ByteBuffer.wrap(header).order(java.nio.ByteOrder.BIG_ENDIAN).getLong(18)
            val frames = packed and 0xfffffffffL
            val channels = ((packed ushr 41).toInt() and 7) + 1
            require(channels in 1..2 && frames in 1..57600000L) { "FLAC 音轨头无效" }
            decodeSpace += frames * channels * 2 + 44
        }
        val required = 32L * 1024 * 1024 + duration.toLong() * (PerformanceMixRenderer.RATE * 4 + 96000 * 4) / 1000 + decodeSpace
        require(StatFs(root.absolutePath).availableBytes >= required) { "本机空间不足，请清理存储后重试" }
        val id = UUID.randomUUID().toString()
        val work = File(scratch, id).apply { check(mkdir()) }
        val output = File(root, "$id.wav")
        val inputs = mutableListOf<PerformanceMixRenderer.Pcm>()
        try {
            checkCancel(); stage = "解码原始录音"
            val decoded = PerformanceMicDecoder.decode(mic, File(work, "mic.pcm"), duration, ::checkCancel).also { inputs.add(it) }
            val prepared = tracks.mapIndexed { index, t ->
                checkCancel(); stage = "载入伴奏 ${index + 1}/${tracks.size}"
                val m = t as Map<*, *>
                val wave = StemPcmWave.open("export_$index", paths[index].absolutePath, stemRoot, ::checkCancel)
                val pcm = PerformanceMixRenderer.FilePcm(wave.file, wave.rate, wave.channels, wave.frames, wave.dataOffset).also { inputs.add(it) }
                require(abs(wave.frames * 1000.0 / wave.rate - integer("backingDurationMs")) <= 100) { "本机伴奏时长与成果不一致" }
                PerformanceMixRenderer.Track(pcm, (m["gain"] as Number).toDouble(), (m["pan"] as Number).toDouble())
            }
            stage = "检测峰值与合成音频"
            val plan = PerformanceMixRenderer.Plan(duration, integer("leadMs"), integer("alignmentMs"), integer("backingEndMs"), number("micGain"), number("backingGain"), prepared)
            val temporary = File(work, "mix.part")
            val rendered = PerformanceMixRenderer.render(decoded, plan, temporary, ::checkCancel) { progress = it }
            checkCancel()
            require(identity.all { (f, v) -> f.isFile && "${f.length()}:${f.lastModified()}" == v }) { "输入文件已变化，请重新打开成果后导出" }
            check(temporary.renameTo(output)) { "无法保存完整作品，请检查本机空间" }
            if (flag.get()) { output.delete(); throw CancellationException() }
            return mapOf("id" to id, "bytes" to output.length(), "durationMs" to duration, "attenuation" to rendered.attenuation, "peak" to rendered.peak, "sampleRate" to PerformanceMixRenderer.RATE)
        } finally { inputs.forEach { runCatching { it.close() } }; work.deleteRecursively() }
    }
    private fun exported(id: String?): File {
        require(id != null && runCatching { UUID.fromString(id).toString() == id }.getOrDefault(false)) { "作品标识无效" }
        return File(root, "$id.wav").also { require(it.isFile && it.length() > 44) { "临时作品已清理，请重新导出" } }
    }
    fun onActivityResult(request: Int, code: Int, data: Intent?): Boolean {
        if (request != REQUEST_SAVE) return false
        val result = saveResult; val source = saveFile; saveResult = null; saveFile = null
        if (result == null) return true
        val uri = data?.data
        if (code != Activity.RESULT_OK || uri == null || source == null) { result.success(false); return true }
        worker.execute {
            try {
                activity.contentResolver.openOutputStream(uri, "wt").use { out ->
                    requireNotNull(out) { "无法写入所选文件" }; source.inputStream().use { it.copyTo(out, 65536) }
                }
                main.post { result.success(true) }
            } catch (_: Exception) {
                runCatching { android.provider.DocumentsContract.deleteDocument(activity.contentResolver, uri) }
                main.post { result.error("save_failed", "保存未完成，完整作品仍在本机，可重试", null) }
            }
        }
        return true
    }
    private fun stopPlayback() { runCatching { player?.stop() }; player?.release(); player = null }
    fun onHostStop() { cancelled.set(true); stopPlayback() }
    fun dispose() {
        if (disposed) return
        disposed = true; onHostStop(); channel.setMethodCallHandler(null); worker.shutdown()
        saveResult?.error("cancelled", "保存已中断，可重新打开成果后导出", null); saveResult = null; saveFile = null
    }
    companion object { private const val REQUEST_SAVE = 6814 }
}

class PerformanceExportFileProvider : FileProvider()
