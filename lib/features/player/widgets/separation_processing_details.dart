import 'package:flutter/material.dart';

import '../../audio_tools/domain/separation_processing_info.dart';

class SeparationProcessingDetails extends StatelessWidget {
  const SeparationProcessingDetails({super.key, required this.info});
  final SeparationProcessingInfo info;
  @override
  Widget build(BuildContext context) {
    final rows = <String, Duration?>{
      '排队等待': info.queue,
      '准备音频': info.preparing,
      '准备模型': info.loading,
      '分离音轨': info.inference,
      '编码音轨': info.encoding,
      '校验并保存': info.publishing,
      '服务器处理合计': info.processing,
    };
    return ExpansionTile(
      title: const Text('服务器处理详情'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (info.gpu != null) Text('处理方式：${info.gpu! ? 'GPU 加速' : 'CPU'}'),
        for (final e in rows.entries)
          if (e.value != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(child: Text(e.key)),
                  Text(_time(e.value!)),
                ],
              ),
            ),
        const Text('以上为服务器记录的耗时；上传、下载和本机载入另行计算。'),
      ],
    );
  }
}

String _time(Duration d) =>
    '${(d.inMicroseconds / 1000000).toStringAsFixed(2)} 秒';
