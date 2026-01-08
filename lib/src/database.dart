import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';

import 'exceptions.dart';
import 'models.dart';
import 'schema/models/schema.dart';
import 'schema/models/table.dart';

/// Uma classe para gerir operações de base de dados
class Db {
  /// Uma base de dados Sqlite existente
  final Database? sqfliteDatabase;

  Database? _db;

  final _mutex = Lock();

  final Completer<void> _readyCompleter = Completer<void>();
  final StreamController<DatabaseChangeEvent> _changeFeedController =
      StreamController<DatabaseChangeEvent>.broadcast();
  File? _dbFile;
  bool _isReady = false;
  final _schema = DbSchema();

  /// Uma base de dados vazia. Deve ser inicializada com [init]
  Db({this.sqfliteDatabase}) {
    if (sqfliteDatabase != null) {
      _db = sqfliteDatabase;
      _dbFile = File(sqfliteDatabase!.path);
      _isReady = true;
      _readyCompleter.complete();
    }
  }

  /// Um stream de [DatabaseChangeEvent] com todas as mudanças na base de dados
  Stream<DatabaseChangeEvent> get changefeed => _changeFeedController.stream;

  /// A instância do Sqflite [Database]
  Database? get database => _db;

  /// O ficheiro Sqlite
  File? get file => _dbFile;

  /// Verifica a existência de um esquema
  bool get hasSchema => true;

  /// Estado da base de dados
  bool get isReady => _isReady;

  /// Callback disparado quando a base de dados está pronta
  Future<void> get onReady => _readyCompleter.future;

  /// O esquema da base de dados
  DbSchema get schema => _schema;

  /// Inicializa a base de dados
  Future<void> init(
      {required final String path,
      final bool absolutePath = false,
      final List<String> queries = const <String>[],
      final List<DbTable> schema = const <DbTable>[],
      final bool verbose = false,
      final String? fromAsset,
      final bool debug = false}) async {
    if (debug) {
      await Sqflite.setDebugModeOn(true);
    }
    var dbpath = path;
    if (!absolutePath) {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      dbpath = "${documentsDirectory.path}/$path";
    }
    if (verbose) {
      print("INITIALIZING DATABASE at $dbpath");
    }

    var checkCreateQueries = false;
    if (fromAsset != null) {
      final file = File(dbpath);
      if (!file.existsSync()) {
        if (verbose) {
          print("Copying the database from asset $fromAsset");
        }
        try {
          final data = await rootBundle.load(fromAsset);
          final bytes =
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
          if (!file.parent.existsSync()) {
            file.parent.createSync(recursive: true);
          }
          await file.writeAsBytes(bytes);
          checkCreateQueries = true;
        } catch (e) {
          throw DatabaseAssetProblem("Unable to read database from asset: $e");
        }
      }
    }

    if (this._db == null) {
      await _mutex.synchronized(() async {
        if (verbose) {
          print("OPENING database");
        }
        this._db = await openDatabase(dbpath, version: 1,
            onCreate: (final Database _sqfliteDb, final int version) async {
          await _initQueries(schema, queries, _sqfliteDb, verbose);
        }, onOpen: (final Database _sqfliteDb) async {
          if (fromAsset != null && checkCreateQueries) {
            await _initQueries(schema, queries, _sqfliteDb, verbose);
          }
        });
      });
    }

    if (verbose) {
      print("DATABASE INITIALIZED");
    }
    _dbFile = File(dbpath);
    _schema.tables = schema.toSet();

    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete();
    }
    _isReady = true;
  }

  /// Insere uma linha se ela ainda não estiver presente
  @Deprecated("A função insertIfNotExists será removida após a versão 4.4.0")
  Future<int> insertIfNotExists(
      {required final String table,
      required final Map<String, String> row,
      final bool verbose = false}) async {
    return _insert(table: table, row: row, ifNotExists: true, verbose: verbose);
  }

  /// Insere uma linha numa tabela
  Future<int> insert(
      {required final String table,
      required final Map<String, String> row,
      final bool verbose = false}) async {
    return _insert(table: table, row: row, verbose: verbose);
  }

  /// Insere uma linha gerindo conflitos
  Future<int> insertManageConflict(
      {required final String table,
      required final ConflictAlgorithm conflictAlgorithm,
      required final Map<String, dynamic> row,
      final bool verbose = false}) async {
    var id = 0;
    try {
      if (!_isReady) throw DatabaseNotReady();
      await _db!.transaction((final txn) async {
        id = await txn.insert(table, row, conflictAlgorithm: conflictAlgorithm);
      });
    } catch (e) {
      throw WriteQueryException("Can not insert in table $table: $e");
    }
    return id;
  }

  Future<int> _insert(
      {required final String table,
      required final Map<String, String> row,
      final bool ifNotExists = false,
      final bool verbose = false}) async {
    var id = 0;
    await _mutex.synchronized(() async {
      try {
        if (!_isReady) throw DatabaseNotReady();
        final timer = Stopwatch()..start();
        final datapoint = row.values.toList();
        final fields = row.keys.join(",");
        final placeholders = List.filled(row.length, "?").join(",");

        final q = "INSERT INTO $table ($fields) VALUES ($placeholders)";

        await _db!.transaction((final txn) async {
          id = await txn.rawInsert(q, datapoint);
        });

        timer.stop();
        _changeFeedController.sink.add(DatabaseChangeEvent(
            type: DatabaseChange.insert,
            value: 1,
            data: row,
            query: q,
            table: table,
            executionTime: timer.elapsedMicroseconds));

        if (verbose) {
          print("$q $row in ${timer.elapsedMilliseconds} ms");
        }
      } catch (e) {
        rethrow;
      }
    });
    return id;
  }

  /// Uma consulta select com join
  Future<List<Map<String, dynamic>>> join(
          {required final String table,
          required final String joinTable,
          required final String joinOn,
          final String columns = "*",
          final int? offset,
          final int? limit,
          final String? orderBy,
          final String? where,
          final String? groupBy,
          final bool verbose = false}) async =>
      _join(
          table: table,
          joinTable: joinTable,
          joinOn: joinOn,
          columns: columns,
          offset: offset,
          limit: limit,
          orderBy: orderBy,
          where: where,
          groupBy: groupBy,
          verbose: verbose);

  /// Uma consulta select com múltiplos joins
  Future<List<Map<String, dynamic>>> mJoin(
      {required final String table,
      required final List<String> joinsTables,
      required final List<String> joinsOn,
      final String columns = "*",
      final int? offset,
      final int? limit,
      final String? orderBy,
      final String? where,
      final String? groupBy,
      final bool verbose = false}) async {
    if (!_isReady) throw DatabaseNotReady();
    final timer = Stopwatch()..start();
    var q = "SELECT $columns FROM $table";
    for (var i = 0; i < joinsTables.length; i++) {
      q = "$q INNER JOIN ${joinsTables[i]} ON ${joinsOn[i]}";
    }

    if (where != null) q += " WHERE $where";
    if (groupBy != null) q += " GROUP BY $groupBy";
    if (orderBy != null) q += " ORDER BY $orderBy";
    if (limit != null) q += " LIMIT $limit";
    if (offset != null) q += " OFFSET $offset";

    final res = await _db!.rawQuery(q);
    timer.stop();
    if (verbose) {
      print("$q in ${timer.elapsedMilliseconds} ms");
    }
    return res;
  }

  /// Executa uma query SQL direta
  Future<List<Map<String, dynamic>>> query(final String q,
      {final bool verbose = false}) async {
    if (!_isReady) throw DatabaseNotReady();
    final timer = Stopwatch()..start();
    final res = await _db!.rawQuery(q);
    timer.stop();
    if (verbose) {
      print("$q in ${timer.elapsedMilliseconds} ms");
    }
    return res;
  }

  /// Uma consulta select
  Future<List<Map<String, dynamic>>> select(
      {required final String table,
      final String columns = "*",
      final String? where,
      final String? orderBy,
      final int? limit,
      final int? offset,
      final String? groupBy,
      final bool verbose = false}) async {
    if (!_isReady) throw DatabaseNotReady();
    final timer = Stopwatch()..start();
    var q = "SELECT $columns FROM $table";
    if (where != null) q += " WHERE $where";
    if (groupBy != null) q += " GROUP BY $groupBy";
    if (orderBy != null) q += " ORDER BY $orderBy";
    if (limit != null) q += " LIMIT $limit";
    if (offset != null) q += " OFFSET $offset";

    final res = await _db!.rawQuery(q);
    timer.stop();
    if (verbose) {
      print("$q in ${timer.elapsedMilliseconds} ms");
    }
    return res;
  }

  /// Atualiza dados na base de dados
  Future<int> update(
      {required final String table,
      required final Map<String, String> row,
      required final String where,
      final bool verbose = false}) async {
    var updated = 0;
    await _mutex.synchronized(() async {
      if (!_isReady) throw DatabaseNotReady();
      final timer = Stopwatch()..start();
      try {
        final datapoint = <String>[];
        final setStatements = <String>[];
        row.forEach((final key, final value) {
          setStatements.add("$key = ?");
          datapoint.add(value);
        });

        final q = 'UPDATE $table SET ${setStatements.join(", ")} WHERE $where';
        await _db!.transaction((final txn) async {
          updated = await txn.rawUpdate(q, datapoint);
        });

        timer.stop();
        _changeFeedController.sink.add(DatabaseChangeEvent(
            type: DatabaseChange.update,
            value: updated,
            query: q,
            table: table,
            data: row,
            executionTime: timer.elapsedMicroseconds));
        return updated;
      } catch (e) {
        rethrow;
      }
    });
    return updated;
  }

  /// Insere ou atualiza (Upsert)
  Future<void> upsert(
      {required final String table,
      required final Map<String, String> row,
      final List<String> preserveColumns = const [],
      final String? indexColumn,
      final bool verbose = false}) async {
    await _mutex.synchronized(() async {
      if (!_isReady) throw DatabaseNotReady();
      final timer = Stopwatch()..start();

      final fields = <String>[];
      final values = <String>[];

      row.forEach((final k, final v) {
        fields.add(k);
        if (preserveColumns.contains(k)) {
          values.add(
              "(SELECT $k FROM $table WHERE $indexColumn='${row[indexColumn]}')");
        } else {
          values.add("'$v'");
        }
      });

      final q =
          "INSERT OR REPLACE INTO $table (${fields.join(',')}) VALUES(${values.join(',')})";
      await _db!.execute(q);
      timer.stop();

      _changeFeedController.sink.add(DatabaseChangeEvent(
          type: DatabaseChange.upsert,
          value: row.length,
          query: q,
          table: table,
          data: row,
          executionTime: timer.elapsedMicroseconds));
    });
  }

  /// Insere várias linhas em lote
  Future<List<dynamic>> batchInsert({
    required final String table,
    required final List<Map<String, String>> rows,
    final ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.rollback,
    final bool verbose = false,
  }) async {
    if (!_isReady) throw DatabaseNotReady();
    final timer = Stopwatch()..start();
    var res = <dynamic>[];

    await _db!.transaction((final txn) async {
      final batch = txn.batch();
      for (final row in rows) {
        batch.insert(table, row, conflictAlgorithm: conflictAlgorithm);
        _changeFeedController.sink.add(DatabaseChangeEvent(
          type: DatabaseChange.insert,
          value: 1,
          query: "BATCH INSERT",
          table: table,
          data: row,
          executionTime: timer.elapsedMicroseconds,
        ));
      }
      res = await batch.commit();
    });
    return res;
  }

  /// Conta linhas numa tabela
  Future<int> count(
      {required final String table,
      final String? where,
      final String columns = "id",
      final bool verbose = false}) async {
    if (!_isReady) throw DatabaseNotReady();
    var q = "SELECT COUNT($columns) FROM $table";
    if (where != null) q += " WHERE $where";
    final res = await _db!.rawQuery(q);
    return Sqflite.firstIntValue(res) ?? 0;
  }

  /// Elimina registos da base de dados
  Future<int> delete(
      {required final String table,
      required final String where,
      final bool verbose = false}) async {
    var deleted = 0;
    await _mutex.synchronized(() async {
      if (!_isReady) throw DatabaseNotReady();
      final timer = Stopwatch()..start();
      final q = 'DELETE FROM $table WHERE $where';
      await _db!.transaction((final txn) async {
        deleted = await txn.rawDelete(q);
      });
      timer.stop();
      _changeFeedController.sink.add(DatabaseChangeEvent(
          type: DatabaseChange.delete,
          value: deleted,
          query: q,
          table: table,
          executionTime: timer.elapsedMicroseconds));
      return deleted;
    });
    return deleted;
  }

  /// Verifica se um valor existe na tabela
  Future<bool> exists(
      {required final String table,
      required final String where,
      final bool verbose = false}) async {
    final c = await count(table: table, where: where, verbose: verbose);
    return c > 0;
  }

  Future<void> _initQueries(
      final List<DbTable> schema,
      final List<String> queries,
      final Database _sqfliteDb,
      final bool verbose) async {
    final allQueries = <String>[];
    for (final table in schema) {
      allQueries.addAll(table.queries);
    }
    allQueries.addAll(queries);

    if (allQueries.isNotEmpty) {
      await _sqfliteDb.transaction((final txn) async {
        for (final q in allQueries) {
          await txn.execute(q);
        }
      });
    }
  }

  Future<List<Map<String, dynamic>>> _join(
      {required final String table,
      required final String joinTable,
      required final String joinOn,
      final String columns = "*",
      final int? offset,
      final int? limit,
      final String? orderBy,
      final String? where,
      final String? groupBy,
      final bool byPassReady = false,
      final bool verbose = false}) async {
    if (!byPassReady && !_isReady) throw DatabaseNotReady();
    final timer = Stopwatch()..start();
    var q = "SELECT $columns FROM $table";
    q = "$q INNER JOIN $joinTable ON $joinOn";
    if (where != null) q += " WHERE $where";
    if (groupBy != null) q += " GROUP BY $groupBy";
    if (orderBy != null) q += " ORDER BY $orderBy";
    if (limit != null) q += " LIMIT $limit";
    if (offset != null) q += " OFFSET $offset";

    final res = await _db!.rawQuery(q);
    timer.stop();
    if (verbose) {
      print("$q in ${timer.elapsedMilliseconds} ms");
    }
    return res;
  }

  /// Fecha o changefeed
  void dispose() {
    _changeFeedController.close();
  }
}
