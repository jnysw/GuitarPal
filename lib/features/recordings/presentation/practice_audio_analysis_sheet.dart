import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/practice_audio_analyzer.dart';
import '../../../domain/practice_recording/practice_recording.dart';
import '../practice_recording_providers.dart';

Future<void> showPracticeAudioAnalysis(
  BuildContext context,
  PracticeRecording recording,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.82,
      child: PracticeAudioAnalysisSheet(recording: recording),
    ),
  );
}

class PracticeAudioAnalysisSheet extends ConsumerStatefulWidget {
  const PracticeAudioAnalysisSheet({required this.recording, super.key});

  final PracticeRecording recording;

  @override
  ConsumerState<PracticeAudioAnalysisSheet> createState() =>
      _PracticeAudioAnalysisSheetState();
}

class _PracticeAudioAnalysisSheetState
    extends ConsumerState<PracticeAudioAnalysisSheet> {
  late Future<PracticeAudioAnalysis> _analysis;

  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  void _startAnalysis() {
    _analysis = ref
        .read(practiceAudioAnalyzerProvider)
        .analyzeRecording(widget.recording.filePath);
  }

  void _retry() {
    setState(_startAnalysis);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: const Key('practice_audio_analysis_sheet'),
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.graphic_eq_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '实验音频分析',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        widget.recording.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<PracticeAudioAnalysis>(
                future: _analysis,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 14),
                          Text('正在本地解码并分析录音…'),
                        ],
                      ),
                    );
                  }
                  final analysis = snapshot.data;
                  if (analysis == null) {
                    return _AnalysisError(onRetry: _retry);
                  }
                  return _AnalysisContent(analysis: analysis);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisContent extends StatelessWidget {
  const _AnalysisContent({required this.analysis});

  final PracticeAudioAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final variation = analysis.onsetIntervalVariation;
    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text('结果只依据这条用户录音的能量变化，不是演奏评分，也尚未与原曲音轨对齐。请结合实际回听判断。'),
        ),
        const SizedBox(height: 18),
        Text(
          '录音波形概览',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          key: const Key('practice_audio_analysis_waveform'),
          height: 112,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: CustomPaint(
            painter: _WaveformPainter(
              values: analysis.waveform,
              color: colors.primary,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricTile(
              key: const Key('analysis_average_loudness'),
              label: '平均响度',
              value: '${analysis.averageLoudnessDbfs.toStringAsFixed(1)} dBFS',
            ),
            _MetricTile(
              label: '峰值',
              value: '${analysis.peakLevelDbfs.toStringAsFixed(1)} dBFS',
            ),
            _MetricTile(
              label: '静音占比',
              value: '${(analysis.silenceRatio * 100).round()}%',
            ),
            _MetricTile(label: '检测到的起音', value: '${analysis.onsetCount} 次'),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          '节奏线索',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (analysis.hasRhythmEstimate && variation != null)
          Card.filled(
            key: const Key('analysis_rhythm_estimate'),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                '相邻起音的中位间隔约为 '
                '${analysis.medianOnsetInterval!.inMilliseconds} ms，'
                '间隔波动约 ${(variation * 100).round()}%。波动越低通常表示起音间隔越一致，'
                '但它不能判断是否跟原曲拍点一致。',
              ),
            ),
          )
        else
          const Card.filled(
            key: Key('analysis_rhythm_insufficient'),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('可识别的起音样本不足，暂不展示节奏间隔结论。可以尝试录制更长、串音更少的片段。'),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          '${analysis.sampleRate} Hz · ${analysis.channelCount} 声道 · '
          '算法 ${analysis.algorithmVersion}',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 3),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AnalysisError extends StatelessWidget {
  const _AnalysisError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 40),
          const SizedBox(height: 10),
          const Text('暂时无法分析这条录音。音频文件可能已损坏或格式不受支持。'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('practice_audio_analysis_retry'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final centerY = size.height / 2;
    final spacing = size.width / values.length;
    for (var index = 0; index < values.length; index += 1) {
      final height = (values[index].clamp(0.0, 1.0) * size.height).clamp(
        2.0,
        size.height,
      );
      final x = spacing * (index + 0.5);
      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}
