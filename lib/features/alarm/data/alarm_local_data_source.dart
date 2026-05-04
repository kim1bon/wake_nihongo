import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/constants/alarm_sound_ids.dart';
import '../domain/alarm.dart';

class AlarmLocalDataSource {
  AlarmLocalDataSource();

  Database? _db;

  static const _version = 3;

  Future<void> open() async {
    final dbPath = join(await getDatabasesPath(), 'wake_nihongo.db');
    _db = await openDatabase(
      dbPath,
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE alarms (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  hour INTEGER NOT NULL,
  minute INTEGER NOT NULL,
  weekdays TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  sound_id TEXT NOT NULL DEFAULT 'Alram_01',
  reschedule_enabled INTEGER NOT NULL DEFAULT 0,
  reschedule_delay_minutes INTEGER NOT NULL DEFAULT 5,
  reschedule_max_count INTEGER NOT NULL DEFAULT 3
)
''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE alarms ADD COLUMN sound_id TEXT NOT NULL DEFAULT 'Alram_01'",
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE alarms ADD COLUMN reschedule_enabled INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE alarms ADD COLUMN reschedule_delay_minutes INTEGER NOT NULL DEFAULT 5',
          );
          await db.execute(
            'ALTER TABLE alarms ADD COLUMN reschedule_max_count INTEGER NOT NULL DEFAULT 3',
          );
        }
      },
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Alarm _rowToAlarm(Map<String, Object?> row) {
    final raw = row['weekdays'] as String;
    final weekdays = raw
        .split(',')
        .where((s) => s.isNotEmpty)
        .map(int.parse)
        .toSet();
    final soundId = row['sound_id'] as String? ?? AlarmSoundIds.defaultId;
    final re = row['reschedule_enabled'] as int?;
    final rd = row['reschedule_delay_minutes'] as int?;
    final rm = row['reschedule_max_count'] as int?;
    return Alarm(
      id: row['id'] as int,
      hour: row['hour'] as int,
      minute: row['minute'] as int,
      weekdays: weekdays,
      enabled: (row['enabled'] as int) == 1,
      soundId: AlarmSoundIds.isValid(soundId) ? soundId : AlarmSoundIds.defaultId,
      rescheduleEnabled: re == 1,
      rescheduleDelayMinutes: (rd ?? 5).clamp(1, 15),
      rescheduleMaxCount: (rm ?? 3).clamp(1, 10),
    );
  }

  Future<List<Alarm>> getAll() async {
    final rows = await _db!.query('alarms', orderBy: 'hour ASC, minute ASC, id ASC');
    return rows.map(_rowToAlarm).toList();
  }

  Future<Alarm?> getById(int id) async {
    final rows = await _db!.query('alarms', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _rowToAlarm(rows.first);
  }

  Future<Alarm> insertAlarm({
    required int hour,
    required int minute,
    required Set<int> weekdays,
    required String soundId,
    bool rescheduleEnabled = false,
    int rescheduleDelayMinutes = 5,
    int rescheduleMaxCount = 3,
  }) async {
    final sorted = weekdays.toList()..sort();
    final delay = rescheduleDelayMinutes.clamp(1, 15);
    final maxC = rescheduleMaxCount.clamp(1, 10);
    final id = await _db!.insert('alarms', {
      'hour': hour,
      'minute': minute,
      'weekdays': sorted.join(','),
      'enabled': 1,
      'sound_id': soundId,
      'reschedule_enabled': rescheduleEnabled ? 1 : 0,
      'reschedule_delay_minutes': delay,
      'reschedule_max_count': maxC,
    });
    return Alarm(
      id: id,
      hour: hour,
      minute: minute,
      weekdays: Set<int>.from(weekdays),
      enabled: true,
      soundId: soundId,
      rescheduleEnabled: rescheduleEnabled,
      rescheduleDelayMinutes: delay,
      rescheduleMaxCount: maxC,
    );
  }

  Future<void> updateAlarm({
    required int id,
    required int hour,
    required int minute,
    required Set<int> weekdays,
    required bool enabled,
    required String soundId,
    bool rescheduleEnabled = false,
    int rescheduleDelayMinutes = 5,
    int rescheduleMaxCount = 3,
  }) async {
    final sorted = weekdays.toList()..sort();
    final delay = rescheduleDelayMinutes.clamp(1, 15);
    final maxC = rescheduleMaxCount.clamp(1, 10);
    await _db!.update(
      'alarms',
      {
        'hour': hour,
        'minute': minute,
        'weekdays': sorted.join(','),
        'enabled': enabled ? 1 : 0,
        'sound_id': soundId,
        'reschedule_enabled': rescheduleEnabled ? 1 : 0,
        'reschedule_delay_minutes': delay,
        'reschedule_max_count': maxC,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    await _db!.delete('alarms', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setAlarmEnabled(int id, bool enabled) async {
    await _db!.update(
      'alarms',
      {'enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
