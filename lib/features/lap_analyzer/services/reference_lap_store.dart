import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/lap_capture.dart';

/// ターゲット/ベストラップをJSONファイルとして永続化する(常に最新1件のみ保持、上書き方式)
/// Persists the target/best lap as a JSON file (always overwritten, keeping only the latest)
class ReferenceLapStore {
  Future<Directory> _referenceDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/gt7_lap_analyzer/reference');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _fileName(LapType type) {
    assert(type != LapType.practice);
    return type == LapType.target ? 'target_lap.json' : 'best_lap.json';
  }

  Future<void> save(LapCapture lap) async {
    final dir = await _referenceDir();
    final file = File('${dir.path}/${_fileName(lap.type)}');
    await file.writeAsString(jsonEncode(lap.toJson()));
  }

  Future<LapCapture?> load(LapType type) async {
    final dir = await _referenceDir();
    final file = File('${dir.path}/${_fileName(type)}');
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    return LapCapture.fromJson(jsonDecode(content) as Map<String, dynamic>);
  }

  Future<void> delete(LapType type) async {
    final dir = await _referenceDir();
    final file = File('${dir.path}/${_fileName(type)}');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
