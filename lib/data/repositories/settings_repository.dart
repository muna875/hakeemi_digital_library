import 'package:sqflite/sqflite.dart';
import '../../models/settings/app_settings_model.dart';
import '../database/app_database.dart';

class SettingsRepository {
  final AppDatabase _appDb;

  SettingsRepository(this._appDb);

  Future<AppSettingsModel> loadSettings() async {
    final db = await _appDb.database;
    final rows = await db.query('app_settings');
    final map = <String, String>{};
    for (final row in rows) {
      map[row['key'] as String] = row['value'] as String;
    }
    return AppSettingsModel.fromKeyValueMap(map);
  }

  Future<void> saveSettings(AppSettingsModel settings) async {
    final db = await _appDb.database;
    final map = settings.toKeyValueMap();
    await db.transaction((txn) async {
      for (final entry in map.entries) {
        await txn.insert(
          'app_settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
