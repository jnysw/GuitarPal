package com.guitarpal.guitar_pal

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest

/** Decode a downloaded lossless stem once; playback retries keep the original download. */
internal object StemFlacDecoder {
    @Synchronized fun decode(source: File): File {
        val target = File(source.parentFile, "${source.name}.mix.wav")
        val receipt = File(source.parentFile, "${source.name}.mix.identity")
        val identity = "${source.length()}:${source.lastModified()}"
        if (target.isFile && receipt.isFile && receipt.readText() == identity) {
            try {
                StemPcmWave.open("probe", target.absolutePath, source.parentFile!!).file.close()
                return target
            } catch (_: Throwable) { target.delete(); receipt.delete() }
        }
        val header = ByteArray(42)
        RandomAccessFile(source, "r").use { it.readFully(header) }
        require(String(header, 0, 4, Charsets.US_ASCII) == "fLaC" &&
            header[4].toInt() and 127 == 0 && header[5] == 0.toByte() &&
            header[6] == 0.toByte() && header[7] == 34.toByte()) { "FLAC 文件头无效" }
        val packed = ByteBuffer.wrap(header).order(ByteOrder.BIG_ENDIAN).getLong(18)
        val expectedRate = (packed ushr 44).toInt() and 0xfffff
        val expectedChannels = ((packed ushr 41).toInt() and 7) + 1
        val bits = ((packed ushr 36).toInt() and 31) + 1
        val frames = packed and 0xfffffffffL
        require(expectedRate in 8000..96000 && expectedChannels in 1..2 && bits == 16 &&
            frames in 1..expectedRate.toLong() * 600) { "FLAC 采样格式或时长不支持" }
        val expectedBytes = frames * expectedChannels * 2
        require(expectedBytes + 44 <= 256L * 1024 * 1024) { "解码音轨超过大小限制" }
        val partial = File(source.parentFile, "${source.name}.mix.wav.part")
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            extractor.setDataSource(source.absolutePath)
            // Some Android extractors decode FLAC themselves and expose audio/raw.
            val index = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME) in setOf("audio/flac", "audio/raw")
            } ?: throw IllegalArgumentException("设备无法读取 FLAC 音轨，原文件已保留，无需重新下载")
            extractor.selectTrack(index)
            val format = extractor.getTrackFormat(index)
            require(format.getInteger(MediaFormat.KEY_SAMPLE_RATE) == expectedRate &&
                format.getInteger(MediaFormat.KEY_CHANNEL_COUNT) == expectedChannels) { "FLAC 提取格式与文件头不一致" }
            val raw = format.getString(MediaFormat.KEY_MIME) == "audio/raw"
            var encoding = if (format.containsKey(MediaFormat.KEY_PCM_ENCODING))
                format.getInteger(MediaFormat.KEY_PCM_ENCODING) else AudioFormat.ENCODING_PCM_16BIT
            if (!raw) {
                format.setInteger(MediaFormat.KEY_PCM_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
                codec = MediaCodec.createDecoderByType("audio/flac")
                codec.configure(format, null, null, 0)
                codec.start()
            }
            val digest = MessageDigest.getInstance("MD5")
            var bytes = 0L
            val deadline = System.nanoTime() + 180_000_000_000L
            RandomAccessFile(partial, "rw").use { output ->
                output.setLength(0); output.write(ByteArray(44))
                fun writePcm(buffer: ByteBuffer, offset: Int, size: Int) {
                    require(encoding == AudioFormat.ENCODING_PCM_16BIT || encoding == AudioFormat.ENCODING_PCM_FLOAT) {
                        "设备不支持此 FLAC 解码格式；原文件已保留，无需重下"
                    }
                    val data = if (encoding == AudioFormat.ENCODING_PCM_FLOAT) {
                        require(size % 4 == 0)
                        val pcm = ByteBuffer.allocate(size / 2).order(ByteOrder.LITTLE_ENDIAN)
                        for (i in offset until offset + size step 4) {
                            val value = buffer.getFloat(i)
                            require(value.isFinite()) { "FLAC 解码出现无效样本" }
                            pcm.putShort(kotlin.math.round(value.coerceIn(-1f, 1f) * 32768).toInt().coerceIn(-32768, 32767).toShort())
                        }
                        pcm.array()
                    } else {
                        buffer.position(offset); buffer.limit(offset + size)
                        ByteArray(size).also { buffer.get(it) }
                    }
                    bytes += data.size
                    require(bytes <= expectedBytes) { "FLAC 解码超出声明帧数" }
                    output.write(data); digest.update(data)
                }
                if (raw) {
                    val buffer = ByteBuffer.allocate(2 * 1024 * 1024).order(ByteOrder.LITTLE_ENDIAN)
                    while (true) {
                        check(System.nanoTime() < deadline) { "本机解码超时，FLAC 已保留，可直接重试载入" }
                        buffer.clear()
                        val size = extractor.readSampleData(buffer, 0)
                        if (size < 0) break
                        writePcm(buffer, 0, size)
                        extractor.advance()
                    }
                } else {
                    val decoder = codec!!
                    val info = MediaCodec.BufferInfo()
                    var inputEnded = false; var outputEnded = false
                    while (!outputEnded) {
                        check(System.nanoTime() < deadline) { "本机解码超时，FLAC 已保留，可直接重试载入" }
                        if (!inputEnded) {
                            val slot = decoder.dequeueInputBuffer(10_000)
                            if (slot >= 0) {
                                val buffer = decoder.getInputBuffer(slot)!!; buffer.clear()
                                val size = extractor.readSampleData(buffer, 0)
                                if (size < 0) {
                                    decoder.queueInputBuffer(slot, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                    inputEnded = true
                                } else {
                                    decoder.queueInputBuffer(slot, 0, size, extractor.sampleTime, 0)
                                    extractor.advance()
                                }
                            }
                        }
                        when (val slot = decoder.dequeueOutputBuffer(info, 10_000)) {
                            MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                                val pcm = decoder.outputFormat
                                require(pcm.getInteger(MediaFormat.KEY_SAMPLE_RATE) == expectedRate &&
                                    pcm.getInteger(MediaFormat.KEY_CHANNEL_COUNT) == expectedChannels) { "FLAC 解码格式发生变化" }
                                encoding = if (pcm.containsKey(MediaFormat.KEY_PCM_ENCODING))
                                    pcm.getInteger(MediaFormat.KEY_PCM_ENCODING) else AudioFormat.ENCODING_PCM_16BIT
                            }
                            else -> if (slot >= 0) {
                                try {
                                    if (info.size > 0) writePcm(decoder.getOutputBuffer(slot)!!.duplicate().order(ByteOrder.LITTLE_ENDIAN), info.offset, info.size)
                                    outputEnded = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                                } finally { decoder.releaseOutputBuffer(slot, false) }
                            }
                        }
                    }
                }
                require(bytes == expectedBytes) { "FLAC 解码不完整，原文件已保留，无需重新下载" }
                val expectedMd5 = header.copyOfRange(26, 42)
                val actualMd5 = digest.digest()
                require(expectedMd5.all { it == 0.toByte() } || expectedMd5.contentEquals(actualMd5)) { "FLAC 音频校验失败，请重新获取这一轨" }
                val h = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
                h.put("RIFF".toByteArray()).putInt((bytes + 36).toInt()).put("WAVEfmt ".toByteArray()).putInt(16)
                    .putShort(1).putShort(expectedChannels.toShort()).putInt(expectedRate).putInt(expectedRate * expectedChannels * 2)
                    .putShort((expectedChannels * 2).toShort()).putShort(16).put("data".toByteArray()).putInt(bytes.toInt())
                output.seek(0); output.write(h.array())
            }
            require("${source.length()}:${source.lastModified()}" == identity) { "本机分轨文件已变化，请重试载入" }
            check(partial.renameTo(target)) { "无法保存解码音轨，请检查本机空间；无需重新下载 FLAC" }
            receipt.writeText(identity)
            return target
        } catch (e: Throwable) { partial.delete(); throw e }
        finally {
            try { codec?.stop() } catch (_: Throwable) {}
            codec?.release(); extractor.release()
        }
    }
}
