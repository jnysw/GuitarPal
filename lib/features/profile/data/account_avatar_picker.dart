import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';

Future<Uint8List?> pickAccountAvatar() async {
  const maxSide = 384;
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: maxSide.toDouble(),
    maxHeight: maxSide.toDouble(),
    requestFullMetadata: false,
  );
  if (file == null) return null;
  if (await file.length() > 12 * 1024 * 1024) {
    throw const FormatException('图片太大，请换一张照片');
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(
    await file.readAsBytes(),
  );
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final landscape = descriptor.width >= descriptor.height;
      final codec = await descriptor.instantiateCodec(
        targetWidth: landscape ? math.min(maxSide, descriptor.width) : null,
        targetHeight: landscape ? null : math.min(maxSide, descriptor.height),
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final data = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (data == null) throw const FormatException('无法读取这张照片');
          return data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}
