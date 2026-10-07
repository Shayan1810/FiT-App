import 'dart:convert';
import 'dart:io';

import 'hive_boxes.dart';
import 'hive_store.dart';

/// Full-data backup as one compact line of text (gzip + base64), so it can
/// be copied to a note, a message to yourself or cloud storage and restored
/// on any phone — no file permissions or plugins needed.
///
/// Format: `FITBACKUP1:` + base64(gzip(JSON)), where the JSON is
/// `{format, version, createdAt, boxes: {boxName: {key: value}}}`.
class BackupService {
  BackupService({List<String>? boxes})
    : _boxes = boxes ?? HiveBoxes.all.where((b) => b != HiveBoxes.nutritionCache).toList();

  static const String prefix = 'FITBACKUP1:';
  final List<String> _boxes;

  /// Encodes every box (except the re-creatable AI cache).
  String export() {
    final data = <String, Object?>{
      'format': 'fit-backup',
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'boxes': {
        for (final name in _boxes)
          name: {
            for (final k in HiveBoxes.box(name).keys) k.toString(): deepCast(HiveBoxes.box(name).get(k)),
          },
      },
    };
    final bytes = GZipCodec(level: 9).encode(utf8.encode(jsonEncode(data)));
    return '$prefix${base64Encode(bytes)}';
  }

  /// Number of records per box in a backup, without restoring it.
  /// Throws [FormatException] if [text] is not a FiT backup.
  Map<String, int> inspect(String text) => _decode(text).map((box, records) => MapEntry(box, records.length));

  /// Replaces all data with the backup. Throws [FormatException] if invalid
  /// (in which case nothing is changed).
  Future<void> restore(String text) async {
    final boxes = _decode(text);
    for (final name in _boxes) {
      final box = HiveBoxes.box(name);
      await box.clear();
      final records = boxes[name];
      if (records != null && records.isNotEmpty) await box.putAll(records);
    }
  }

  Map<String, Map<String, Object?>> _decode(String text) {
    final t = text.trim().replaceAll(RegExp(r'\s'), '');
    if (!t.startsWith(prefix)) throw const FormatException('This is not a FiT backup.');
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(GZipCodec().decode(base64Decode(t.substring(prefix.length)))));
    } catch (_) {
      throw const FormatException('The backup text is incomplete or damaged. Copy it again in full.');
    }
    if (json is! Map || json['format'] != 'fit-backup' || json['boxes'] is! Map) {
      throw const FormatException('This is not a FiT backup.');
    }
    return {
      for (final e in (json['boxes'] as Map).entries)
        if (_boxes.contains(e.key)) e.key as String: Map<String, Object?>.from(e.value as Map),
    };
  }
}
