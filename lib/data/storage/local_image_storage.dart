import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Persists cover and inline book images inside app-private storage so they
/// survive cache clears and can be archived cleanly in backups.
class LocalImageStorage {
  final Uuid _uuid = const Uuid();
  final Directory? overrideDirectory;

  LocalImageStorage({this.overrideDirectory});

  Future<Directory> getImagesDirectory() async {
    final base = overrideDirectory ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'hakeemi_images'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> persistImageFile(String sourcePath) async {
    final src = File(sourcePath);
    if (!await src.exists()) {
      throw FileSystemException('Selected image not found', sourcePath);
    }
    final dir = await getImagesDirectory();
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final fileName = 'img_${_uuid.v4()}$ext';
    final destPath = p.join(dir.path, fileName);
    await src.copy(destPath);
    return destPath;
  }

  Future<List<File>> listStoredImages() async {
    final dir = await getImagesDirectory();
    if (!await dir.exists()) return [];
    return dir.listSync().whereType<File>().toList();
  }
}
