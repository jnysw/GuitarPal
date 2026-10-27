package com.guitarpal.guitar_pal

import java.io.File
import java.io.RandomAccessFile

/** RIFF PCM16 reader. Reads chunks, including unknown/padded chunks, not a fixed 44-byte header. */
internal class StemPcmWave private constructor(
    val id: String, val file: RandomAccessFile, val rate: Int, val channels: Int,
    val dataOffset: Long, val frames: Long,
) {
    fun read(frame: Long, count: Int, bytes: ByteArray) {
        require(frame >= 0 && frame + count <= frames)
        file.seek(dataOffset + frame * channels * 2)
        file.readFully(bytes, 0, count * channels * 2)
    }

    companion object {
        fun open(id: String, path: String, root: File): StemPcmWave {
            val source = File(path).canonicalFile
            require(source.parentFile == root.canonicalFile && source.isFile && source.extension == "wav") { "请选择已下载的 WAV 音轨" }
            require(source.length() in 44L..(256L * 1024 * 1024)) { "音轨大小无效" }
            val file = RandomAccessFile(source, "r")
            try {
                fun tag(): String { val b = ByteArray(4); file.readFully(b); return String(b, Charsets.US_ASCII) }
                fun u16(): Int = file.readUnsignedByte() or (file.readUnsignedByte() shl 8)
                fun u32(): Long = u16().toLong() or (u16().toLong() shl 16)
                require(tag() == "RIFF") { "混音仅支持 PCM16 WAV" }
                val end = u32() + 8
                require(end in 44L..file.length() && tag() == "WAVE") { "WAV 容器无效" }
                var rate = 0; var channels = 0; var offset = -1L; var size = 0L
                while (file.filePointer + 8 <= end) {
                    val chunk = tag(); val length = u32(); val start = file.filePointer
                    require(start + length <= end) { "WAV 数据被截断" }
                    when (chunk) {
                        "fmt " -> {
                            require(rate == 0 && length >= 16 && u16() == 1) { "混音仅支持 PCM16 WAV" }
                            channels = u16(); rate = u32().toInt()
                            val byteRate = u32(); val block = u16(); val bits = u16()
                            require(channels in 1..2 && rate in 8000..96000 && bits == 16 && block == channels * 2 && byteRate == rate.toLong() * block) { "WAV 采样格式不支持" }
                        }
                        "data" -> { require(offset < 0); offset = start; size = length }
                    }
                    file.seek(start + length + (length % 2))
                }
                require(rate > 0 && offset >= 0 && size > 0 && size % (channels * 2) == 0L) { "WAV 缺少有效音频数据" }
                val frames = size / (channels * 2)
                require(frames <= rate.toLong() * 600) { "音轨超过 10 分钟" }
                return StemPcmWave(id, file, rate, channels, offset, frames)
            } catch (e: Throwable) { file.close(); throw e }
        }
    }
}
