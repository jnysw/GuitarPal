package com.guitarpal.guitar_pal

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteOrder

/** Decode AAC to a bounded disk scratch file; codec output timestamps define the microphone clock. */
internal object PerformanceMicDecoder {
    fun decode(source: File, target: File, durationMs: Int, check: () -> Unit): PerformanceMixRenderer.Pcm {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            extractor.setDataSource(source.absolutePath)
            val index = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: error("录音没有音频")
            extractor.selectTrack(index)
            val format = extractor.getTrackFormat(index)
            val rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            val channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            require(rate in 8000..96000 && channels in 1..2) { "录音采样格式不支持" }
            val maxFrames = durationMs.toLong() * rate / 1000
            var encoding = AudioFormat.ENCODING_PCM_16BIT
            codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            codec.configure(format, null, null, 0); codec.start()
            val info = MediaCodec.BufferInfo()
            var inputEnded = false; var outputEnded = false
            var written = 0L
            val deadline = System.nanoTime() + 300_000_000_000L
            RandomAccessFile(target, "rw").use { out ->
                out.setLength(0)
                while (!outputEnded) {
                    check(); check(System.nanoTime() < deadline) { "本机录音解码超时，请重试" }
                    if (!inputEnded) {
                        val slot = codec.dequeueInputBuffer(10000)
                        if (slot >= 0) {
                            val buffer = codec.getInputBuffer(slot)!!; buffer.clear()
                            val size = extractor.readSampleData(buffer, 0)
                            if (size < 0) {
                                codec.queueInputBuffer(slot, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM); inputEnded = true
                            } else {
                                codec.queueInputBuffer(slot, 0, size, extractor.sampleTime, 0); extractor.advance()
                            }
                        }
                    }
                    when (val slot = codec.dequeueOutputBuffer(info, 10000)) {
                        MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            val pcm = codec.outputFormat
                            require(pcm.getInteger(MediaFormat.KEY_SAMPLE_RATE) == rate && pcm.getInteger(MediaFormat.KEY_CHANNEL_COUNT) == channels) { "录音解码格式发生变化" }
                            encoding = if (pcm.containsKey(MediaFormat.KEY_PCM_ENCODING)) pcm.getInteger(MediaFormat.KEY_PCM_ENCODING) else AudioFormat.ENCODING_PCM_16BIT
                            require(encoding == AudioFormat.ENCODING_PCM_16BIT || encoding == AudioFormat.ENCODING_PCM_FLOAT) { "设备录音解码格式不支持" }
                        }
                        else -> if (slot >= 0) {
                            try {
                                if (info.size > 0 && info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
                                    val pcm = codec.getOutputBuffer(slot)!!.duplicate().order(ByteOrder.LITTLE_ENDIAN)
                                    val size = if (encoding == AudioFormat.ENCODING_PCM_FLOAT) 4 else 2
                                    require(info.size % (channels * size) == 0)
                                    require(info.size <= 2 * 1024 * 1024) { "录音解码块过大" }
                                    val frames = info.size / (channels * size)
                                    val at = Math.round(info.presentationTimeUs.toDouble() * rate / 1000000)
                                    val first = maxOf(0L, -at, written - at)
                                    val end = minOf(frames.toLong(), maxFrames - at)
                                    if (end > first) {
                                        // Sparse gaps read as silence; never allocate a whole recording in RAM.
                                        out.seek((at + first) * channels * 2)
                                        val bytes = ByteArray(((end - first) * channels * 2).toInt())
                                        var dest = 0
                                        for (f in first until end) for (c in 0 until channels) {
                                            val pos = info.offset + (f.toInt() * channels + c) * size
                                            val value = if (size == 2) pcm.getShort(pos).toInt() else {
                                                val x = pcm.getFloat(pos); require(x.isFinite())
                                                Math.round(x.coerceIn(-1f, 1f) * 32768).coerceIn(-32768, 32767)
                                            }
                                            bytes[dest++] = value.toByte(); bytes[dest++] = (value shr 8).toByte()
                                        }
                                        out.write(bytes); written = at + end
                                    }
                                }
                                outputEnded = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                            } finally { codec.releaseOutputBuffer(slot, false) }
                        }
                    }
                }
                require(written > 0 && written >= maxFrames - rate / 4) { "录音实际时长与成果不符，无法导出" }
                // Container metadata may round AAC duration; only a <=250ms tail is zero padded.
                out.setLength(maxFrames * channels * 2)
            }
            return PerformanceMixRenderer.FilePcm(RandomAccessFile(target, "r"), rate, channels, maxFrames)
        } finally {
            runCatching { codec?.stop() }; runCatching { codec?.release() }; extractor.release()
        }
    }
}
