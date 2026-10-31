package com.guitarpal.guitar_pal

import android.app.Activity
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.media.PlaybackParams
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.util.ArrayDeque
import kotlin.math.sqrt
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.math.max
import kotlin.math.min

/** One PCM stream and hardware clock for every stem; no independently seeking players. */
class AlgorithmMixPlugin(private val activity: Activity, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "com.guitarpal/algorithm_mix")
    private val audio = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val levels = EventChannel(messenger, "com.guitarpal/algorithm_mix_levels")
    private val handler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private val publish = object : Runnable {
        override fun run() {
            if (sink == null) return
            val level = engine?.levelSnapshot() ?: mapOf("isPlaying" to false, "leftRms" to 0.0, "rightRms" to 0.0, "leftPeak" to 0.0, "rightPeak" to 0.0, "epoch" to 0L, "positionMs" to 0L)
            val volume = if (audio.isStreamMute(AudioManager.STREAM_MUSIC)) 0.0 else audio.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() / max(1, audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC))
            sink?.success(level + mapOf("generation" to generation, "systemVolume" to volume))
            handler.postDelayed(this, 50)
        }
    }
    private var engine: StemMixEngine? = null
    private var generation = 0
    private var pending: MethodChannel.Result? = null
    private val focus = AudioManager.OnAudioFocusChangeListener { change -> if (change != AudioManager.AUDIOFOCUS_GAIN) engine?.pause() }
    init {
        channel.setMethodCallHandler(this)
        levels.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) { sink = events; handler.removeCallbacks(publish); handler.post(publish) }
            override fun onCancel(arguments: Any?) { sink = null; handler.removeCallbacks(publish) }
        })
    }

    @Suppress("DEPRECATION")
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "load" -> {
                    val tracks = requireNotNull(call.argument<List<Map<String, Any?>>>("tracks"))
                    stop()
                    val token = generation
                    pending = result
                    Thread {
                        var created: StemMixEngine? = null
                        try {
                            created = StemMixEngine.open(tracks, File(activity.filesDir, "algorithm_stems"))
                            val ready = created
                            activity.runOnUiThread {
                                if (token != generation) ready.close()
                                else { engine = ready; pending = null; result.success(ready.snapshot()) }
                            }
                        } catch (e: Throwable) {
                            created?.close()
                            activity.runOnUiThread {
                                if (token == generation) { pending = null; result.error("mix_load_failed", e.message ?: "无法载入混音", null) }
                            }
                        }
                    }.start()
                }
                "play" -> {
                    val current = requireNotNull(engine) { "请先载入音轨" }
                    check(audio.requestAudioFocus(focus, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) { "暂时无法取得音频播放权限" }
                    current.play(); result.success(null)
                }
                "pause" -> { engine?.pause(); audio.abandonAudioFocus(focus); result.success(null) }
                "seek" -> { requireNotNull(engine).seek(requireNotNull(call.argument<Number>("positionMs")).toLong()); result.success(null) }
                "configure" -> { requireNotNull(engine).configure(call.arguments as Map<*, *>); result.success(null) }
                "snapshot" -> result.success((engine?.snapshot() ?: mapOf("isLoaded" to false, "isPlaying" to false)) + mapOf("generation" to generation))
                "stop" -> { stop(); result.success(null) }
                else -> result.notImplemented()
            }
        } catch (e: Throwable) { result.error("mix_failed", e.message ?: "混音操作失败", null) }
    }

    @Suppress("DEPRECATION")
    fun onHostStop() { engine?.pause(); audio.abandonAudioFocus(focus) }
    @Suppress("DEPRECATION")
    fun stop() {
        generation++
        pending?.error("mix_interrupted", "载入已停止", null); pending = null
        engine?.close(); engine = null
        audio.abandonAudioFocus(focus)
    }
    fun dispose() { sink = null; handler.removeCallbacks(publish); levels.setStreamHandler(null); stop(); channel.setMethodCallHandler(null) }
}

internal class StemMixEngine(private val waves: List<StemPcmWave>) {
    private val lock = java.lang.Object()
    private val rate = waves.first().rate
    private val channels = waves.first().channels
    private val frames = waves.minOf { it.frames }
    // Always output stereo so mono stems can also be positioned left/right.
    private val outputChannels = 2
    private val format = AudioFormat.CHANNEL_OUT_STEREO
    private val minimum = AudioTrack.getMinBufferSize(rate, format, AudioFormat.ENCODING_PCM_16BIT)
    private val track = AudioTrack.Builder()
        .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
        .setAudioFormat(AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_16BIT).setSampleRate(rate).setChannelMask(format).build())
        .setTransferMode(AudioTrack.MODE_STREAM)
        .setBufferSizeInBytes(max(minimum * 2, rate * outputChannels * 2 / 10)).build()
    private val gains = waves.associate { it.id to 1.0 }.toMutableMap()
    private val pans = waves.associate { it.id to 0.0 }.toMutableMap()
    private var master = 0.8
    private var speed = 1.0f
    private var playing = false
    @Volatile private var closed = false
    private var error: String? = null
    private var start = 0L
    private var cursor = 0L
    private var emitted = 0L
    private var realEnd: Long? = null
    private var loopA: Long? = null
    private var loopB: Long? = null
    private var completedLoops = 0L
    private var lastHead = 0L
    private var headWrap = 0L
    private val scratch = waves.map { ByteArray(512 * channels * 2) }
    private val output = ShortArray(512 * outputChannels)
    private data class Meter(val start: Long, val end: Long, val left: Double, val right: Double, val leftPeak: Double, val rightPeak: Double)
    private val meters = ArrayDeque<Meter>()
    private var meterEpoch = 0L
    // Meter only frames actually accepted by AudioTrack, after all mix controls and limiting.
    private fun meter(accepted: Int) {
        if (accepted <= 0) return
        var l = 0.0; var r = 0.0; var lp = 0.0; var rp = 0.0
        for (i in 0 until accepted step 2) {
            val a = output[i].toDouble() / 32768.0; val b = output[i + 1].toDouble() / 32768.0
            l += a * a; r += b * b; lp = max(lp, kotlin.math.abs(a)); rp = max(rp, kotlin.math.abs(b))
        }
        val count = accepted / 2
        meters.addLast(Meter(emitted, emitted + count, sqrt(l / count), sqrt(r / count), lp, rp))
        while (meters.size > 256) meters.removeFirst()
    }
    fun levelSnapshot(): Map<String, Any?> = synchronized(lock) {
        val h = if (closed) 0L else head()
        while (meters.size > 1 && meters.first.end <= h) meters.removeFirst()
        val current = meters.peekFirst()?.takeIf { playing && !closed && error == null && h > 0 && h >= it.start && h < it.end }
        mapOf("isPlaying" to (playing && !closed), "epoch" to meterEpoch,
            "positionMs" to (if (closed) 0L else position(h) * 1000 / rate),
            "leftRms" to (current?.left ?: 0.0), "rightRms" to (current?.right ?: 0.0),
            "leftPeak" to (current?.leftPeak ?: 0.0), "rightPeak" to (current?.rightPeak ?: 0.0))
    }
    private val thread = Thread({ render() }, "guitarpal-stem-mix")

    init {
        try {
            check(minimum > 0 && track.state == AudioTrack.STATE_INITIALIZED) { "设备无法初始化混音输出" }
            thread.start()
        } catch (e: Throwable) { track.release(); throw e }
    }

    private fun head(): Long {
        val raw = track.playbackHeadPosition.toLong() and 0xffffffffL
        if (raw < lastHead) headWrap += 1L shl 32
        lastHead = raw
        return min(emitted, headWrap + raw)
    }
    private fun position(h: Long): Long {
        val a = loopA; val b = loopB
        return if (a != null && b != null) a + (start - a + h) % (b - a) else min(frames, start + h)
    }
    private fun loops(h: Long): Long = if (loopA != null && loopB != null) (start - loopA!! + h) / (loopB!! - loopA!!) else 0

    private fun reset(target: Long) {
        track.pause(); track.flush()
        lastHead = 0; headWrap = 0
        meters.clear(); meterEpoch++
        val a = loopA; val b = loopB
        start = if (a != null && b != null) target.coerceIn(a, b - 1) else target.coerceIn(0, frames)
        cursor = start; emitted = 0
        realEnd = null
        if (playing) track.play()
    }

    fun play() = synchronized(lock) {
        check(!closed && error == null) { error ?: "混音已关闭" }
        if (loopA == null && position(head()) >= frames) reset(0)
        playing = true; track.play(); lock.notifyAll()
    }
    fun pause() = synchronized(lock) { if (!closed) { playing = false; track.pause() } }
    fun seek(ms: Long) = synchronized(lock) {
        check(!closed); require(ms >= 0)
        completedLoops += loops(head())
        reset((ms * rate / 1000).coerceIn(0, frames))
    }
    fun configure(args: Map<*, *>) = synchronized(lock) {
        check(!closed)
        val nextGains = requireNotNull(args["gains"] as? Map<*, *>)
        require(nextGains.keys.toSet() == gains.keys) { "音轨控制与载入清单不一致" }
        val checked = nextGains.map { (id, value) ->
            val gain = (value as Number).toDouble()
            require(gain.isFinite() && gain in 0.0..1.0)
            id as String to gain
        }.toMap()
        val nextPans = args["pans"] as? Map<*, *>
        val checkedPans = if (nextPans == null) pans.toMap() else {
            require(nextPans.keys.toSet() == pans.keys) { "声像控制与载入清单不一致" }
            nextPans.map { (id, value) ->
                val pan = (value as Number).toDouble()
                require(pan.isFinite() && pan in -1.0..1.0)
                id as String to pan
            }.toMap()
        }
        val nextMaster = (args["master"] as Number).toDouble()
        val nextSpeed = (args["speed"] as Number).toFloat()
        require(nextMaster.isFinite() && nextMaster in 0.0..1.0 && nextSpeed.isFinite() && nextSpeed in 0.5f..2.0f)
        val a = (args["loopStartMs"] as? Number)?.toLong()?.let { it * rate / 1000 }
        val b = (args["loopEndMs"] as? Number)?.toLong()?.let { it * rate / 1000 }
        require((a == null && b == null) || (a != null && b != null && a >= 0 && b <= frames && b - a >= rate / 4)) { "循环区间至少 0.25 秒，且不能超出音轨" }
        if (nextSpeed != speed) {
            track.playbackParams = PlaybackParams().setSpeed(nextSpeed).setPitch(1f)
            if (!playing) track.pause()
            speed = nextSpeed
        }
        if (a != loopA || b != loopB) {
            val h = head(); val current = position(h); completedLoops += loops(h)
            loopA = a; loopB = b
            reset(if (a != null && b != null && current !in a until b) a else current)
        }
        gains.putAll(checked); pans.putAll(checkedPans); master = nextMaster
    }
    fun snapshot(): Map<String, Any?> = synchronized(lock) {
        if (closed) return@synchronized mapOf("isLoaded" to false, "isPlaying" to false, "error" to error)
        val h = head()
        mapOf("isLoaded" to true, "isPlaying" to playing, "positionMs" to position(h) * 1000 / rate,
            "durationMs" to frames * 1000 / rate, "completedLoops" to completedLoops + loops(h),
            "epoch" to meterEpoch, "master" to master, "speed" to speed.toDouble(), "gains" to gains.toMap(), "pans" to pans.toMap(), "error" to error) + levelSnapshot()
    }

    private fun render() {
        try {
            android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_AUDIO)
            while (!closed) {
                var wrote = false
                synchronized(lock) {
                    while (!closed && !playing) lock.wait()
                    if (!closed && playing) {
                        val end = loopB ?: frames
                        if (cursor >= end && loopA != null) cursor = loopA!!
                        val count = min(512L, end - cursor).toInt()
                        if (count > 0) {
                            waves.forEachIndexed { index, wave -> wave.read(cursor, count, scratch[index]) }
                            // Fixed per-track gains: muting/soloing must not amplify other stems.
                            for (i in 0 until count * outputChannels) {
                                var sum = 0.0
                                waves.forEachIndexed { index, wave ->
                                    val bytes = scratch[index]
                                    val side = i % outputChannels
                                    val source = (i / outputChannels * channels + if (channels == 1) 0 else side) * 2
                                    val sample = ((bytes[source].toInt() and 255) or (bytes[source + 1].toInt() shl 8)).toShort()
                                    val pan = pans.getValue(wave.id)
                                    // Stereo balance: center is unchanged; moving right attenuates left.
                                    val balance = if (side == 0) 1.0 - max(0.0, pan) else 1.0 + min(0.0, pan)
                                    sum += sample * gains.getValue(wave.id) * balance
                                }
                                output[i] = (sum * master).toInt().coerceIn(-32768, 32767).toShort()
                            }
                            val accepted = track.write(output, 0, count * outputChannels, AudioTrack.WRITE_NON_BLOCKING)
                            check(accepted >= 0 && accepted % outputChannels == 0) { "设备混音输出失败 ($accepted)" }
                            meter(accepted)
                            cursor += accepted / outputChannels; emitted += accepted / outputChannels
                            wrote = accepted > 0
                        } else {
                            // AudioTrack's time stretcher needs trailing input to drain a short tail.
                            // Count only real source frames as the end, not the silent drain padding.
                            if (realEnd == null) realEnd = emitted
                            if (head() >= realEnd!!) {
                                playing = false; track.pause()
                            } else if (emitted - realEnd!! < rate) {
                                output.fill(0)
                                val accepted = track.write(output, 0, output.size, AudioTrack.WRITE_NON_BLOCKING)
                                check(accepted >= 0 && accepted % outputChannels == 0) { "设备混音尾音输出失败" }
                                emitted += accepted / outputChannels
                                wrote = accepted > 0
                            }
                        }
                    }
                }
                if (!wrote) Thread.sleep(4)
            }
        } catch (_: InterruptedException) { /* closed by owner */ }
        catch (e: Throwable) { synchronized(lock) { error = e.message ?: "混音读取失败"; playing = false; closed = true } }
        finally {
            synchronized(lock) { try { track.release() } catch (_: Throwable) { } }
            waves.forEach { try { it.file.close() } catch (_: Throwable) { } }
        }
    }
    fun close() = synchronized(lock) {
        if (!closed) { closed = true; playing = false; try { track.pause(); track.flush() } catch (_: Throwable) { }; thread.interrupt() }
    }

    companion object {
        fun open(tracks: List<Map<String, Any?>>, root: File): StemMixEngine {
            val ids = tracks.map { it["id"] as String }
            require(ids.size in 1..16 && ids.toSet().size == ids.size && ids.all { it.matches(Regex("[A-Za-z0-9_-]{1,128}")) }) { "音轨清单无效" }
            require("instrumental" !in ids || ids.all { it in setOf("vocals", "instrumental") }) { "伴奏不能与乐器分轨重复叠加" }
            val opened = mutableListOf<StemPcmWave>()
            try {
                tracks.forEach { opened.add(StemPcmWave.open(it["id"] as String, it["path"] as String, root)) }
                val first = opened.first()
                require(opened.all { it.rate == first.rate && it.channels == first.channels && kotlin.math.abs(it.frames - first.frames) <= 1 }) { "音轨采样率、声道或时长不一致" }
                return StemMixEngine(opened)
            } catch (e: Throwable) { opened.forEach { it.file.close() }; throw e }
        }
    }
}
