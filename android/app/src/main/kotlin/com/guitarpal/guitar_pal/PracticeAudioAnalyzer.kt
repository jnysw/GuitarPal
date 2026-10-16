package com.guitarpal.guitar_pal

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Build
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sqrt

internal object PracticeAudioAnalyzer {
    private const val dequeueTimeoutMicroseconds = 10_000L
    private const val windowMilliseconds = 20
    private const val maximumWaveformPoints = 120
    private const val silenceThresholdDbfs = -45.0
    private const val onsetThresholdDbfs = -42.0
    private const val minimumOnsetGapWindows = 4
    private const val algorithmVersion = "energy-onset-v1"

    fun analyze(file: File): Map<String, Any?> {
        val extractor = MediaExtractor()
        var decoder: MediaCodec? = null
        try {
            extractor.setDataSource(file.absolutePath)
            val trackIndex = (0 until extractor.trackCount).firstOrNull { index ->
                extractor.getTrackFormat(index)
                    .getString(MediaFormat.KEY_MIME)
                    ?.startsWith("audio/") == true
            } ?: throw IllegalArgumentException("录音中没有可分析的音轨")
            extractor.selectTrack(trackIndex)
            val inputFormat = extractor.getTrackFormat(trackIndex)
            val mime = inputFormat.getString(MediaFormat.KEY_MIME)
                ?: throw IllegalArgumentException("录音音轨格式无效")
            var sampleRate = inputFormat.integerOrNull(MediaFormat.KEY_SAMPLE_RATE) ?: 44_100
            var channelCount = inputFormat.integerOrNull(MediaFormat.KEY_CHANNEL_COUNT) ?: 1
            var pcmEncoding = AudioFormat.ENCODING_PCM_16BIT
            val declaredDurationMicroseconds = inputFormat.longOrNull(MediaFormat.KEY_DURATION) ?: 0L
            val accumulator = PcmAccumulator(sampleRate, channelCount)

            decoder = MediaCodec.createDecoderByType(mime).apply {
                configure(inputFormat, null, null, 0)
                start()
            }
            val bufferInfo = MediaCodec.BufferInfo()
            var inputEnded = false
            var outputEnded = false
            while (!outputEnded) {
                if (!inputEnded) {
                    val inputIndex = decoder.dequeueInputBuffer(dequeueTimeoutMicroseconds)
                    if (inputIndex >= 0) {
                        val inputBuffer = decoder.getInputBuffer(inputIndex)
                            ?: throw IllegalStateException("无法读取音频解码输入")
                        inputBuffer.clear()
                        val sampleSize = extractor.readSampleData(inputBuffer, 0)
                        if (sampleSize < 0) {
                            decoder.queueInputBuffer(
                                inputIndex,
                                0,
                                0,
                                0,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            inputEnded = true
                        } else {
                            decoder.queueInputBuffer(
                                inputIndex,
                                0,
                                sampleSize,
                                extractor.sampleTime.coerceAtLeast(0L),
                                extractor.sampleFlags,
                            )
                            extractor.advance()
                        }
                    }
                }

                when (val outputIndex = decoder.dequeueOutputBuffer(
                    bufferInfo,
                    dequeueTimeoutMicroseconds,
                )) {
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val outputFormat = decoder.outputFormat
                        sampleRate = outputFormat.integerOrNull(MediaFormat.KEY_SAMPLE_RATE)
                            ?: sampleRate
                        channelCount = outputFormat.integerOrNull(MediaFormat.KEY_CHANNEL_COUNT)
                            ?: channelCount
                        pcmEncoding = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            outputFormat.integerOrNull(MediaFormat.KEY_PCM_ENCODING)
                                ?: AudioFormat.ENCODING_PCM_16BIT
                        } else {
                            AudioFormat.ENCODING_PCM_16BIT
                        }
                        accumulator.updateFormat(sampleRate, channelCount)
                    }
                    MediaCodec.INFO_TRY_AGAIN_LATER,
                    MediaCodec.INFO_OUTPUT_BUFFERS_CHANGED,
                    -> Unit
                    else -> if (outputIndex >= 0) {
                        if (
                            bufferInfo.size > 0 &&
                            bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0
                        ) {
                            val outputBuffer = decoder.getOutputBuffer(outputIndex)
                                ?: throw IllegalStateException("无法读取音频解码输出")
                            val end = bufferInfo.offset + bufferInfo.size
                            outputBuffer.position(bufferInfo.offset)
                            outputBuffer.limit(end)
                            accumulator.consume(
                                outputBuffer.slice().order(ByteOrder.LITTLE_ENDIAN),
                                pcmEncoding,
                            )
                        }
                        outputEnded =
                            bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                        decoder.releaseOutputBuffer(outputIndex, false)
                    }
                }
            }

            val decoded = accumulator.finish()
            if (decoded.sampleCount <= 0 || decoded.windowRms.isEmpty()) {
                throw IllegalArgumentException("录音中没有可分析的采样")
            }
            val decodedDurationMilliseconds =
                decoded.sampleCount.toDouble() /
                    (sampleRate * channelCount).coerceAtLeast(1) * 1000.0
            val durationMilliseconds = max(
                (declaredDurationMicroseconds / 1000L).toInt(),
                decodedDurationMilliseconds.roundToInt(),
            ).coerceAtLeast(1)
            return buildResult(
                decoded = decoded,
                durationMilliseconds = durationMilliseconds,
                sampleRate = sampleRate,
                channelCount = channelCount,
            )
        } finally {
            try {
                decoder?.stop()
            } catch (_: Throwable) {
                // The decoder may not have reached its started state.
            }
            try {
                decoder?.release()
            } catch (_: Throwable) {
                // Ignore cleanup failures after analysis.
            }
            extractor.release()
        }
    }

    private fun buildResult(
        decoded: DecodedSamples,
        durationMilliseconds: Int,
        sampleRate: Int,
        channelCount: Int,
    ): Map<String, Any?> {
        val averageRms = sqrt(decoded.totalSquares / decoded.sampleCount)
        val onsetWindows = detectOnsets(decoded.windowRms)
        val onsetIntervals = onsetWindows.zipWithNext { left, right ->
            (right - left) * windowMilliseconds
        }
        val medianInterval = onsetIntervals.medianOrNull()
        val intervalVariation = onsetIntervals.coefficientOfVariationOrNull()
        val silenceWindows = decoded.windowRms.count { dbfs(it) <= silenceThresholdDbfs }
        return mapOf(
            "durationMilliseconds" to durationMilliseconds,
            "waveform" to compactWaveform(decoded.windowRms),
            "averageLoudnessDbfs" to dbfs(averageRms),
            "peakLevelDbfs" to dbfs(decoded.peak),
            "silenceRatio" to silenceWindows.toDouble() / decoded.windowRms.size,
            "onsetCount" to onsetWindows.size,
            "medianOnsetIntervalMilliseconds" to medianInterval,
            "onsetIntervalVariation" to intervalVariation,
            "sampleRate" to sampleRate,
            "channelCount" to channelCount,
            "algorithmVersion" to algorithmVersion,
        )
    }

    private fun detectOnsets(windowRms: List<Double>): List<Int> {
        if (windowRms.size < 3) return emptyList()
        val threshold = 10.0.pow(onsetThresholdDbfs / 20.0)
        val onsets = mutableListOf<Int>()
        var previousOnset = -minimumOnsetGapWindows
        for (index in 1 until windowRms.size) {
            val current = windowRms[index]
            val previous = windowRms[index - 1]
            val historyStart = max(0, index - 8)
            val history = windowRms.subList(historyStart, index)
            val localAverage = history.average().coerceAtLeast(1e-9)
            if (
                current >= threshold &&
                current >= previous * 1.25 &&
                current >= localAverage * 1.45 &&
                index - previousOnset >= minimumOnsetGapWindows
            ) {
                onsets += index
                previousOnset = index
            }
        }
        return onsets
    }

    private fun compactWaveform(windowRms: List<Double>): List<Double> {
        val pointCount = min(maximumWaveformPoints, windowRms.size).coerceAtLeast(1)
        return List(pointCount) { point ->
            val start = floor(point.toDouble() * windowRms.size / pointCount)
                .toInt()
                .coerceIn(0, windowRms.lastIndex)
            val end = ceil((point + 1.0) * windowRms.size / pointCount)
                .toInt()
                .coerceIn(start + 1, windowRms.size)
            val peak = windowRms.subList(start, end).maxOrNull() ?: 0.0
            ((dbfs(peak) + 60.0) / 60.0).coerceIn(0.0, 1.0)
        }
    }

    private fun dbfs(value: Double): Double {
        return (20.0 * log10(value.coerceAtLeast(1e-6))).coerceIn(-120.0, 0.0)
    }

    private fun List<Int>.medianOrNull(): Int? {
        if (isEmpty()) return null
        val sorted = sorted()
        val middle = sorted.size / 2
        return if (sorted.size % 2 == 1) {
            sorted[middle]
        } else {
            ((sorted[middle - 1] + sorted[middle]) / 2.0).roundToInt()
        }
    }

    private fun List<Int>.coefficientOfVariationOrNull(): Double? {
        if (size < 2) return null
        val mean = average()
        if (mean <= 0.0) return null
        val variance = sumOf { value -> (value - mean) * (value - mean) } / size
        return sqrt(variance) / mean
    }

    private fun MediaFormat.integerOrNull(key: String): Int? {
        return if (containsKey(key)) runCatching { getInteger(key) }.getOrNull() else null
    }

    private fun MediaFormat.longOrNull(key: String): Long? {
        return if (containsKey(key)) runCatching { getLong(key) }.getOrNull() else null
    }

    private data class DecodedSamples(
        val windowRms: List<Double>,
        val totalSquares: Double,
        val sampleCount: Long,
        val peak: Double,
    )

    private class PcmAccumulator(sampleRate: Int, channelCount: Int) {
        private var samplesPerWindow = 1
        private var windowSquares = 0.0
        private var windowSamples = 0
        private val windows = mutableListOf<Double>()
        private var totalSquares = 0.0
        private var totalSamples = 0L
        private var peak = 0.0

        init {
            updateFormat(sampleRate, channelCount)
        }

        fun updateFormat(sampleRate: Int, channelCount: Int) {
            samplesPerWindow = max(
                1,
                sampleRate * channelCount * windowMilliseconds / 1000,
            )
        }

        fun consume(buffer: ByteBuffer, encoding: Int) {
            when (encoding) {
                AudioFormat.ENCODING_PCM_8BIT -> while (buffer.remaining() >= 1) {
                    addSample(((buffer.get().toInt() and 0xff) - 128) / 128.0)
                }
                AudioFormat.ENCODING_PCM_FLOAT -> while (buffer.remaining() >= 4) {
                    addSample(buffer.float.toDouble().coerceIn(-1.0, 1.0))
                }
                AudioFormat.ENCODING_PCM_24BIT_PACKED -> while (buffer.remaining() >= 3) {
                    val raw =
                        (buffer.get().toInt() and 0xff) or
                            ((buffer.get().toInt() and 0xff) shl 8) or
                            ((buffer.get().toInt() and 0xff) shl 16)
                    val signed = if (raw and 0x800000 != 0) raw or -0x1000000 else raw
                    addSample(signed / 8_388_608.0)
                }
                AudioFormat.ENCODING_PCM_32BIT -> while (buffer.remaining() >= 4) {
                    addSample(buffer.int / 2_147_483_648.0)
                }
                else -> while (buffer.remaining() >= 2) {
                    addSample(buffer.short / 32_768.0)
                }
            }
        }

        private fun addSample(value: Double) {
            val normalized = value.coerceIn(-1.0, 1.0)
            val square = normalized * normalized
            totalSquares += square
            totalSamples += 1
            windowSquares += square
            windowSamples += 1
            peak = max(peak, abs(normalized))
            if (windowSamples >= samplesPerWindow) finishWindow()
        }

        private fun finishWindow() {
            if (windowSamples <= 0) return
            windows += sqrt(windowSquares / windowSamples)
            windowSquares = 0.0
            windowSamples = 0
        }

        fun finish(): DecodedSamples {
            finishWindow()
            return DecodedSamples(
                windowRms = windows.toList(),
                totalSquares = totalSquares,
                sampleCount = totalSamples,
                peak = peak,
            )
        }
    }
}
