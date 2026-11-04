package com.guitarpal.guitar_pal

import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.CancellationException
import kotlin.math.sin
import kotlin.math.PI

class PerformanceMixRendererTest {
    private class Signal(override val rate: Int = 44100, override val channels: Int = 1, override val frames: Long = rate.toLong(), val read: (Long, Int) -> Double) : PerformanceMixRenderer.Pcm {
        override fun sample(frame: Long, side: Int) = if (frame in 0 until frames) read(frame, side) else 0.0
        override fun close() {}
    }
    private fun plan(lead: Int = 0, alignment: Int = 0, end: Int = 500, mic: Double = 0.0, backing: Double = 1.0, tracks: List<PerformanceMixRenderer.Track>) =
        PerformanceMixRenderer.Plan(1000, lead, alignment, end, mic, backing, tracks)
    private fun render(p: PerformanceMixRenderer.Plan, mic: PerformanceMixRenderer.Pcm = Signal { _, _ -> 0.0 }, assertion: (ByteBuffer, PerformanceMixRenderer.Result) -> Unit) {
        val file = File.createTempFile("gp_render_", ".wav")
        try {
            val result = PerformanceMixRenderer.render(mic, p, file, {}, {})
            val b = ByteBuffer.wrap(file.readBytes()).order(ByteOrder.LITTLE_ENDIAN)
            assertEquals("RIFF", String(b.array(), 0, 4)); assertEquals(44100, b.getInt(24))
            assertEquals(2, b.getShort(22).toInt()); assertEquals(16, b.getShort(34).toInt())
            assertEquals(44 + 44100 * 4, file.length().toInt())
            assertion(b, result)
        } finally { file.delete() }
    }
    private fun ByteBuffer.at(ms: Int, side: Int = 0) = getShort(44 + ms * 44100 / 1000 * 4 + side * 2).toInt() / 32768.0
    @Test fun signedLeadAlignmentAndActualEndUseOnlyInputRelativeClock() {
        val track = PerformanceMixRenderer.Track(Signal { _, _ -> .25 }, 1.0, 0.0)
        render(plan(lead = 200, alignment = 50, tracks = listOf(track))) { b, _ ->
            assertEquals(0.0, b.at(149), .0001); assertEquals(.25, b.at(150), .0001)
            assertEquals(.25, b.at(649), .0001); assertEquals(0.0, b.at(650), .0001)
        }
        render(plan(lead = -100, alignment = -50, tracks = listOf(track))) { b, _ ->
            assertEquals(.25, b.at(0), .0001); assertEquals(.25, b.at(449), .0001); assertEquals(0.0, b.at(450), .0001)
        }
    }
    @Test fun micAndBackingGainsAndStereoBalanceApplyOnceWithoutRenormalizingTracks() {
        val track = PerformanceMixRenderer.Track(Signal { _, _ -> .4 }, .5, 1.0)
        render(plan(mic = .5, backing = .5, tracks = listOf(track)), Signal(channels = 2) { _, s -> if (s == 0) .2 else .4 }) { b, r ->
            assertEquals(.1, b.at(100, 0), .0001); assertEquals(.3, b.at(100, 1), .0001)
            assertEquals(.2, b.at(700, 1), .0001); assertEquals(1.0, r.attenuation, 0.0)
        }
        render(plan(tracks = listOf(track.copy(gain = 0.0)))) { b, r -> assertEquals(0.0, b.at(10), 0.0); assertEquals(0.0, r.peak, 0.0) }
    }
    @Test fun peakAttenuationIsOneConstantAcrossTheWholeFile() {
        val track = PerformanceMixRenderer.Track(Signal { f, _ -> if (f < 22050) .8 else .2 }, 1.0, 0.0)
        render(plan(mic = 1.0, end = 1000, tracks = listOf(track)), Signal { f, _ -> if (f < 22050) .8 else .2 }) { b, r ->
            assertEquals(.6125, r.attenuation, .000001)
            assertEquals(.98, b.at(100), .00005); assertEquals(.245, b.at(700), .00005)
        }
    }
    @Test fun differentRatesPreserveOneSecondAndSinePitch() {
        val mic = Signal(rate = 48000) { f, _ -> .25 * sin(2 * PI * 440 * f / 48000) }
        render(plan(mic = 1.0, tracks = emptyList()), mic) { b, _ ->
            var crossings = 0; var previous = 0
            for (i in 0 until 44100) {
                val x = b.getShort(44 + i * 4).toInt()
                if (previous < 0 && x >= 0) crossings++
                previous = x
            }
            assertTrue(crossings in 439..440)
        }
    }
    @Test fun cancellationInterruptsBothPassesAndNoUnboundedWholeSongBufferIsNeeded() {
        for (cancelAt in listOf(2, 20)) {
            val file = File.createTempFile("gp_cancel_", ".part")
            var checks = 0
            try {
                try {
                    PerformanceMixRenderer.render(Signal { _, _ -> .1 }, plan(mic = 1.0, tracks = emptyList()), file,
                        { if (++checks == cancelAt) throw CancellationException() }, {})
                    fail("must cancel")
                } catch (_: CancellationException) { assertEquals(cancelAt, checks) }
            } finally { file.delete() }
        }
    }
    @Test fun fileReaderHandlesBlockBoundariesAndMonoDuplication() {
        val file = File.createTempFile("gp_pcm_", ".pcm")
        try {
            val bytes = ByteBuffer.allocate(10000).order(ByteOrder.LITTLE_ENDIAN)
            repeat(5000) { bytes.putShort(it.toShort()) }; file.writeBytes(bytes.array())
            PerformanceMixRenderer.FilePcm(java.io.RandomAccessFile(file, "r"), 8000, 1, 5000).use { p ->
                for (i in listOf(0, 4095, 4096, 4999, 1)) {
                    assertEquals(i / 32768.0, p.sample(i.toLong(), 1), 0.0)
                }
                assertEquals(0.0, p.sample(5000, 0), 0.0)
            }
        } finally { file.delete() }
    }
}
