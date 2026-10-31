package com.guitarpal.guitar_pal

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest
import java.util.UUID
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/** PCM16 input in video media coordinates: retain silence and fill timestamp gaps. */
internal object VideoAudioExtraction {
    fun extract(path: String, startMs: Long, endMs: Long, sourceRoot: File, outputRoot: File, sourceDurationMs: Long? = null): Map<String, Any> {
        val source = File(path).canonicalFile
        require(source.parentFile == sourceRoot.canonicalFile && source.isFile) { "请选择已导入练习库的本地视频" }
        require(startMs >= 0 && endMs - startMs in 2000L..600000L) { "请选择 2 秒至 10 分钟的分析区间" }
        val beforeSize = source.length(); val beforeModified = source.lastModified()
        val retriever = MediaMetadataRetriever()
        val metadataDuration = try { retriever.setDataSource(path); retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLong() ?: 0 } finally { retriever.release() }
        // The practice timeline uses MediaPlayer milliseconds. Container metadata
        // can round the final frame differently; never clamp away selected audio.
        fun playbackDuration(): Long {
            val probe = MediaPlayer()
            return try { probe.setDataSource(path); probe.prepare(); probe.duration.toLong() } finally { probe.release() }
        }
        val duration = sourceDurationMs ?: metadataDuration.takeIf { it > 0 } ?: playbackDuration()
        require(duration > 0) { "无法读取视频时长，请重新打开视频后重试" }
        if (sourceDurationMs != null && abs(sourceDurationMs - metadataDuration) > 2) {
            require(abs(playbackDuration() - sourceDurationMs) <= 2) { "视频时长信息已变化，请重新打开视频后分析" }
        }
        require(endMs <= duration) { "分析区间超出视频时长" }
        val extractor = MediaExtractor(); var codec: MediaCodec? = null
        outputRoot.mkdirs()
        val target = File(outputRoot, "${UUID.randomUUID()}.wav")
        try {
            extractor.setDataSource(path)
            val track = (0 until extractor.trackCount).firstOrNull { extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true }
                ?: throw IllegalArgumentException("这个视频没有音轨")
            extractor.selectTrack(track); extractor.seekTo(startMs * 1000, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
            val format = extractor.getTrackFormat(track)
            var rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            require(rate in 8000..96000 && channels in 1..2) { "目前支持单声道或立体声音轨" }
            val expectedRate = rate; val expectedChannels = channels
            var encoding = AudioFormat.ENCODING_PCM_16BIT
            val frames = (endMs - startMs) * rate / 1000
            val bytes = frames * channels * 2
            require(bytes + 44 <= 50L * 1024 * 1024) { "提取的音频超过 50 MiB，请选择更短的 A-B 区间" }
            format.setInteger(MediaFormat.KEY_PCM_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
            codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            codec.configure(format, null, null, 0); codec.start()
            val info = MediaCodec.BufferInfo(); var inputEnded = false; var outputEnded = false
            var written = 0L
            val peaks = DoubleArray(240)
            val deadline = System.nanoTime() + 180_000_000_000L
            RandomAccessFile(target, "rw").use { output ->
                output.write(ByteArray(44))
                fun silence(count: Long) {
                    var remaining = count * channels * 2
                    val zeros = ByteArray(16384)
                    while (remaining > 0) { val n = min(remaining, zeros.size.toLong()).toInt(); output.write(zeros, 0, n); remaining -= n }
                    written += count
                }
                while (!outputEnded) {
                    check(System.nanoTime() < deadline) { "音频提取超时" }
                    if (!inputEnded) {
                        val index = codec.dequeueInputBuffer(10_000)
                        if (index >= 0) {
                            val buffer = codec.getInputBuffer(index)!!; buffer.clear()
                            val stamp = extractor.sampleTime
                            val size = if (stamp < 0 || stamp >= endMs * 1000) -1 else extractor.readSampleData(buffer, 0)
                            if (size < 0) { codec.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM); inputEnded = true }
                            else { codec.queueInputBuffer(index, 0, size, stamp, 0); extractor.advance() }
                        }
                    }
                    when (val index = codec.dequeueOutputBuffer(info, 10_000)) {
                        MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            val pcm = codec.outputFormat
                            rate = pcm.getInteger(MediaFormat.KEY_SAMPLE_RATE); channels = pcm.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                            require(rate == expectedRate && channels == expectedChannels) { "解码时音频格式发生变化" }
                            encoding = if (pcm.containsKey(MediaFormat.KEY_PCM_ENCODING)) pcm.getInteger(MediaFormat.KEY_PCM_ENCODING) else AudioFormat.ENCODING_PCM_16BIT
                            require(encoding == AudioFormat.ENCODING_PCM_16BIT || encoding == AudioFormat.ENCODING_PCM_FLOAT) { "音频编码暂不支持" }
                        }
                        else -> if (index >= 0) {
                            try {
                                val buffer = codec.getOutputBuffer(index)!!.duplicate().order(ByteOrder.LITTLE_ENDIAN)
                                val sampleBytes = if (encoding == AudioFormat.ENCODING_PCM_FLOAT) 4 else 2
                                val count = info.size / (channels * sampleBytes)
                                val base = Math.floorDiv((info.presentationTimeUs - startMs * 1000) * rate, 1_000_000L)
                                val first = max(0L, max(-base, written - base)).coerceAtMost(count.toLong()).toInt()
                                val last = min(count.toLong(), frames - base).coerceAtLeast(first.toLong()).toInt()
                                if (last > first) {
                                    val gap = base + first - written
                                    if (gap > 0) silence(gap)
                                    val data = ByteArray((last - first) * channels * 2)
                                    var dest = 0
                                    for (frame in first until last) {
                                        var peak = 0.0
                                        for (channel in 0 until channels) {
                                            val offset = info.offset + (frame * channels + channel) * sampleBytes
                                            val value = if (sampleBytes == 4) (buffer.getFloat(offset).toDouble().coerceIn(-1.0, 1.0) * 32767).toInt() else buffer.getShort(offset).toInt()
                                            data[dest++] = value.toByte(); data[dest++] = (value shr 8).toByte()
                                            peak = max(peak, abs(value.toDouble()) / 32768)
                                        }
                                        val bucket = ((base + frame) * peaks.size / frames).toInt().coerceIn(0, peaks.lastIndex)
                                        peaks[bucket] = max(peaks[bucket], peak)
                                    }
                                    output.write(data); written += last - first
                                }
                                outputEnded = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0 || written >= frames
                            } finally { codec.releaseOutputBuffer(index, false) }
                        }
                    }
                }
                if (written < frames) silence(frames - written)
                val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
                header.put("RIFF".toByteArray()).putInt((bytes + 36).toInt()).put("WAVEfmt ".toByteArray()).putInt(16)
                    .putShort(1).putShort(channels.toShort()).putInt(rate).putInt(rate * channels * 2).putShort((channels * 2).toShort()).putShort(16)
                    .put("data".toByteArray()).putInt(bytes.toInt())
                output.seek(0); output.write(header.array())
            }
            require(source.length() == beforeSize && source.lastModified() == beforeModified) { "提取期间视频已变化，请重试" }
            val digest = MessageDigest.getInstance("SHA-256")
            target.inputStream().use { input -> val buffer = ByteArray(65536); while (true) { val n = input.read(buffer); if (n < 0) break; digest.update(buffer, 0, n) } }
            return mapOf("path" to target.absolutePath, "sizeBytes" to target.length(), "durationMs" to (endMs - startMs),
                "sha256" to digest.digest().joinToString("") { "%02x".format(it) }, "waveform" to peaks.toList())
        } catch (e: Throwable) { target.delete(); throw e }
        finally { try { codec?.stop() } catch (_: Throwable) { }; codec?.release(); extractor.release() }
    }
}
