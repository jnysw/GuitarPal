import 'dart:io';
import 'dart:typed_data';

import '../domain/legacy_algorithm_models.dart';

/// Validate container AND PCM metadata before publishing or trusting a cache.
Future<void> validateStemAudio(File file, LegacyStemFile stem) async {
  final input = await file.open();
  try {
    final length = await input.length();
    if (length != stem.sizeBytes) throw const FormatException('音轨文件不完整');
    int rate = 0, channels = 0, frames = 0;
    if (stem.extension == 'flac') {
      final h = await input.read(42);
      if (h.length != 42 ||
          String.fromCharCodes(h.take(4)) != 'fLaC' ||
          (h[4] & 127) != 0 ||
          h[5] != 0 ||
          h[6] != 0 ||
          h[7] != 34) {
        throw const FormatException('服务器 FLAC 文件头无效');
      }
      final packed = ByteData.sublistView(Uint8List.fromList(h))
          .getUint64(18, Endian.big);
      rate = (packed >> 44) & 0xfffff;
      channels = ((packed >> 41) & 7) + 1;
      final bits = ((packed >> 36) & 31) + 1;
      frames = packed & 0xfffffffff;
      if (bits != 16) {
        throw const FormatException('分轨需要 FLAC16，请重新分析；重复下载不能修复编码格式');
      }
    } else {
      final h = await input.read(12);
      if (h.length != 12 ||
          String.fromCharCodes(h.take(4)) != 'RIFF' ||
          String.fromCharCodes(h.skip(8)) != 'WAVE') {
        throw const FormatException('服务器 WAV 文件头无效');
      }
      final end =
          ByteData.sublistView(Uint8List.fromList(h))
              .getUint32(4, Endian.little) +
          8;
      if (end < 44 || end > length) throw const FormatException('WAV 容器被截断');
      int? dataBytes;
      var chunks = 0;
      while (await input.position() + 8 <= end) {
        if (++chunks > 4096) throw const FormatException('WAV 区块过多');
        final chunk = await input.read(8);
        final size = ByteData.sublistView(Uint8List.fromList(chunk))
            .getUint32(4, Endian.little);
        final start = await input.position();
        if (start + size > end) throw const FormatException('WAV 数据被截断');
        final tag = String.fromCharCodes(chunk.take(4));
        if (tag == 'fmt ') {
          if (rate != 0 || size < 16) throw const FormatException('WAV 编码信息无效');
          final format = ByteData.sublistView(
            Uint8List.fromList(await input.read(16)),
          );
          channels = format.getUint16(2, Endian.little);
          rate = format.getUint32(4, Endian.little);
          if (format.getUint16(0, Endian.little) != 1 ||
              format.getUint16(14, Endian.little) != 16 ||
              format.getUint16(12, Endian.little) != channels * 2 ||
              format.getUint32(8, Endian.little) != rate * channels * 2) {
            throw const FormatException('分轨需要 PCM16 WAV，请重新分析；重复下载不能修复编码格式');
          }
        } else if (tag == 'data') {
          if (dataBytes != null) throw const FormatException('WAV 音频区块重复');
          dataBytes = size;
        }
        await input.setPosition(start + size + size % 2);
      }
      if (channels <= 0 ||
          dataBytes == null ||
          dataBytes <= 0 ||
          dataBytes % (channels * 2) != 0) {
        throw const FormatException('WAV 缺少完整音频数据');
      }
      frames = dataBytes ~/ (channels * 2);
    }
    if (rate < 8000 ||
        rate > 96000 ||
        rate != stem.sampleRate ||
        channels != stem.channels ||
        frames <= 0 ||
        (frames * 1000 / rate - stem.duration.inMilliseconds).abs() > 100) {
      throw const FormatException('音轨采样率、声道或时长与服务器清单不一致；请重新分析');
    }
  } finally {
    await input.close();
  }
}
