import 'dart:async';

import 'package:bell_poc/models/job.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('jobs.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE queued_jobs (
      id INTEGER PRIMARY KEY,
      name TEXT,
      status TEXT
    )
    ''');
  }

  Future<int> addJob(Job job) async {
    final db = await instance.database;
    return await db.insert('queued_jobs', job.toMap());
  }

  Future<List<Job>> fetchJobs() async {
    final db = await instance.database;
    final result = await db.query('queued_jobs');
    return result.map((e) => Job.fromMap(e)).toList();
  }

  Future<List<Job>> fetchJobsWithStatus(String status) async {
    final db = await database;
    final maps = await db.query(
      'queued_jobs', // table name
      where: 'status = ?', // filter by status
      whereArgs: [status], // argument for status
    );

    return List.generate(maps.length, (i) {
      return Job(
        maps[i]['name'] as String, // Assuming this is a String
        maps[i]['status'] as String, // Assuming this is a String
        maps[i]['id'] as int, // Explicit cast to int
      );
    });
  }

  Future<List<Job>> getJobsByStatuses({
    required List<String> statuses,
    required int limit,
  }) async {
    final db = await database;
    final whereClause = 'status IN (${List.filled(statuses.length, '?').join(', ')})';

    final maps = await db.query(
      'queued_jobs',
      where: whereClause,
      whereArgs: statuses,
      limit: limit,
    );

    return List.generate(maps.length, (i) {
      return Job(
        maps[i]['name'] as String,
        maps[i]['status'] as String,
        maps[i]['id'] as int,
      );
    });
  }

  Future<int> updateJob(Job job) async {
    final db = await instance.database;
    return await db.update(
      'queued_jobs',
      job.toMap(),
      where: 'id = ?',
      whereArgs: [job.id],
    );
  }

  Future<int> deleteJob(int id) async {
    final db = await instance.database;
    return await db.delete(
      'queued_jobs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> hasPendingJobs() async {
    final db = await database;
    final result = await db.rawQuery('''
    SELECT COUNT(*) as count FROM queued_jobs 
    WHERE status NOT IN (?, ?)
  ''', ['created', 'completed']);

    final count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  Future<int> countJobsByStatus(String status) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM queued_jobs WHERE status = ?', [status]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countJobs() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM queued_jobs');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
