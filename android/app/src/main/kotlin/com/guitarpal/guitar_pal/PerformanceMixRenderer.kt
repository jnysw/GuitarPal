package com.guitarpal.guitar_pal

import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** File-backed, constant-memory offline mix. All time arguments are input-relative milliseconds. */
internal object PerformanceMixRenderer {
    const val RATE = 44100
    interface Pcm : AutoCloseable {
        val rate: Int
        val channels: Int
        val frames: Long
        fun sample(frame: Long, side: Int): Double
    }
    class FilePcm(
        private val file: RandomAccessFile, override val rate: Int,
        override val channels: Int, override val frames: Long, private val offset: Long = 0,
    ) : Pcm {
        private val bytes = ByteArray(4096 * channels * 2)
        private var start = -1L
        private var count = 0
        override fun sample(frame: Long, side: Int): Double {
            if (frame < 0 || frame >= frames) return 0.0
            if (frame < start || frame >= start + count) {
                start = frame; count = min(4096L, frames - frame).toInt()
                file.seek(offset + frame * channels * 2)
                file.readFully(bytes, 0, count * channels * 2)
            }
            val i = ((frame - start).toInt() * channels + if (channels == 1) 0 else side) * 2
            return ((bytes[i].toInt() and 255) or (bytes[i + 1].toInt() shl 8)).toShort() / 32768.0
        }
        override fun close() = file.close()
    }
    data class Track(val pcm: Pcm, val gain: Double, val pan: Double)
    data class Plan(
        val durationMs: Int, val leadMs: Int, val alignmentMs: Int,
        val backingEndMs: Int, val micGain: Double, val backingGain: Double,
        val tracks: List<Track>,
    ) {
        init {
            require(durationMs in 1..1250000 && leadMs in -10000..10000 && alignmentMs in -2000..2000)
            require(backingEndMs in 0..600000 && tracks.size <= 16)
            require(listOf(micGain, backingGain).all { it.isFinite() && it in 0.0..1.0 })
            require(tracks.all { it.gain.isFinite() && it.gain in 0.0..1.0 && it.pan.isFinite() && it.pan in -1.0..1.0 })
        }
    }
    data class Result(val frames: Long, val peak: Double, val attenuation: Double)
    private fun at(pcm: Pcm, seconds: Double, side: Int): Double {
        if (seconds < 0) return 0.0
        val p = seconds * pcm.rate
        val a = floor(p).toLong()
        if (a >= pcm.frames) return 0.0
        val fraction = p - a
        return pcm.sample(a, side) * (1 - fraction) + pcm.sample(min(a + 1, pcm.frames - 1), side) * fraction
    }
    fun render(mic: Pcm, plan: Plan, target: File, check: () -> Unit, progress: (Double) -> Unit): Result {
        val frames = plan.durationMs.toLong() * RATE / 1000
        fun value(frame: Long, side: Int): Double {
            val seconds = frame.toDouble() / RATE
            var mixed = at(mic, seconds, side) * plan.micGain
            val backingMs = seconds * 1000 - plan.leadMs + plan.alignmentMs
            if (backingMs >= 0 && backingMs < plan.backingEndMs) {
                for (t in plan.tracks) {
                    val balance = if (side == 0) 1 - max(0.0, t.pan) else 1 + min(0.0, t.pan)
                    mixed += at(t.pcm, backingMs / 1000, side) * t.gain * balance * plan.backingGain
                }
            }
            check(mixed.isFinite()) { "音频采样无效" }
            return mixed
        }
        var peak = 0.0
        for (frame in 0 until frames) {
            if (frame % 4096 == 0L) { check(); progress(.5 * frame / frames) }
            for (side in 0..1) peak = max(peak, abs(value(frame, side)))
        }
        // One constant attenuation for the entire file, preserving dynamics.
        val attenuation = if (peak > .98) .98 / peak else 1.0
        RandomAccessFile(target, "rw").use { out ->
            out.setLength(0)
            out.write(header(frames))
            val buffer = ByteBuffer.allocate(4096 * 4).order(ByteOrder.LITTLE_ENDIAN)
            for (frame in 0 until frames) {
                if (frame % 4096 == 0L) { check(); progress(.5 + .5 * frame / frames) }
                for (side in 0..1) buffer.putShort((value(frame, side) * attenuation * 32768).roundToInt().coerceIn(-32768, 32767).toShort())
                if (!buffer.hasRemaining()) { out.write(buffer.array()); buffer.clear() }
            }
            if (buffer.position() > 0) out.write(buffer.array(), 0, buffer.position())
            check(); out.fd.sync()
        }
        require(target.length() == 44 + frames * 4) { "导出文件不完整" }
        progress(1.0)
        return Result(frames, peak, attenuation)
    }
    private fun header(frames: Long): ByteArray = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
        .put("RIFF".toByteArray()).putInt((36 + frames * 4).toInt()).put("WAVEfmt ".toByteArray())
        .putInt(16).putShort(1).putShort(2).putInt(RATE).putInt(RATE * 4).putShort(4).putShort(16)
        .put("data".toByteArray()).putInt((frames * 4).toInt()).array()
}
