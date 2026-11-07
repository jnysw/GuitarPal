import 'dart:math';
import 'dart:typed_data';

List<int> syntheticAlgorithmWav({int seconds = 8}) {
  const rate = 16000;
  final bytes = Uint8List(44 + rate * seconds * 2);
  final data = ByteData.sublistView(bytes);
  void text(int offset, String value) =>
      bytes.setRange(offset, offset + value.length, value.codeUnits);
  text(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  text(36, 'data');
  data.setUint32(40, bytes.length - 44, Endian.little);
  for (var i = 0; i < rate * seconds; i++) {
    data.setInt16(
      44 + i * 2,
      (3000 * sin(2 * pi * 440 * i / rate)).round(),
      Endian.little,
    );
  }
  return bytes;
}

Map<String, Object?> separationFixture({
  String jobId = 'contract_job_1',
  String expires = '2035-01-01T00:00:00Z',
  int size = 256044,
}) => {
  'job_id': jobId,
  'status': 'completed',
  'duration_seconds': 8,
  'expires_at': expires,
  'output_format': 'wav_s16',
  'stems': [
    for (final id in [
      'vocals',
      'drums',
      'bass',
      'guitar',
      'piano',
      'other',
      'instrumental',
    ])
      {
        'id': id,
        'origin': id == 'instrumental' ? 'derived' : 'model',
        'filename': '$id.wav',
        'content_type': 'audio/wav',
        'size_bytes': size,
        'duration_seconds': 8,
        'sample_rate': 16000,
        'channels': 1,
        'download_url': '/api/v1/separation/jobs/$jobId/files/$id',
      },
  ],
};
