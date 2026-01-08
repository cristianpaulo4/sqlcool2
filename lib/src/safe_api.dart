import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'database.dart';
import 'models.dart';
import 'schema/models/row.dart';
import 'schema/models/schema.dart';
import 'schema/models/table.dart';

/// Uma base de dados Sqlite com API segura
class SqlDb {
  /// Construtor base
  SqlDb() {
    _db = Db(sqfliteDatabase: sqfliteDatabase);
  }

  /// Uma base de dados Sqflite existente
  Database? sqfliteDatabase;

  late Db _db;

  /// Um stream de [DatabaseChangeEvent] com todas as mudanças na base de dados
  Stream<DatabaseChangeEvent> get changefeed => _db.changefeed;

  /// A instância do Sqflite [Database]
  Database? get database => _db.database;

  /// O ficheiro da base de dados
  File? get file => _db.file;

  /// Verifica a existência de um esquema
  bool get hasSchema => _db.hasSchema;

  /// Estado da base de dados
  bool get isReady => _db.isReady;

  /// Callback disparado quando a base de dados está pronta
  Future<void> get onReady => _db.onReady;

  /// O esquema da base de dados
  DbSchema get schema => _db.schema;

  /// Inicializa a base de dados
  Future<void> init({
    required final String path,
    required final List<DbTable> schema,
    final bool absolutePath = false,
    final List<String> queries = const <String>[],
    final bool verbose = false,
    final String? fromAsset,
    final bool debug = false,
  }) async {
    await _db.init(
      path: path,
      absolutePath: absolutePath,
      queries: queries,
      schema: schema,
      verbose: verbose,
      fromAsset: fromAsset,
      debug: debug,
    );
  }

  /// Insere uma linha numa tabela
  Future<int> insert({
    required final String table,
    required final DbRow row,
    final bool verbose = false,
  }) async {
    try {
      return await _db.insert(
        table: table,
        row: row.toStringsMap(),
        verbose: verbose,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Insere uma linha gerindo conflitos
  Future<int> insertManageConflict({
    required final String table,
    required final ConflictAlgorithm conflictAlgorithm,
    required final DbRow row,
    final bool verbose = false,
  }) async {
    try {
      return await _db.insertManageConflict(
        table: table,
        conflictAlgorithm: conflictAlgorithm,
        row: row.toMap(),
        verbose: verbose,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Uma consulta select
  Future<List<DbRow>> select({
    required final String table,
    final String columns = "*",
    final String? where,
    final String? orderBy,
    final int? limit,
    final int? offset,
    final String? groupBy,
    final bool verbose = false,
  }) async {
    try {
      final data = await _db.select(
        table: table,
        columns: columns,
        where: where,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
        groupBy: groupBy,
        verbose: verbose,
      );
      return _rowsFromRawData(table, data);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualiza dados na base de dados
  Future<int> update({
    required final String table,
    required final DbRow row,
    required final String where,
    final bool verbose = false,
  }) async {
    try {
      return await _db.update(
        table: table,
        row: row.toStringsMap(),
        where: where,
        verbose: verbose,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Insere ou atualiza (Upsert)
  Future<void> upsert({
    required final String table,
    required final DbRow row,
    final List<String> preserveColumns = const [],
    final String? indexColumn,
    final bool verbose = false,
  }) async {
    try {
      await _db.upsert(
        table: table,
        row: row.toStringsMap(),
        preserveColumns: preserveColumns,
        indexColumn: indexColumn,
        verbose: verbose,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Insere várias linhas em lote
  Future<List<dynamic>> batchInsert({
    required final String table,
    required final List<DbRow> rows,
    final ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.rollback,
    final bool verbose = false,
  }) async {
    final data = <Map<String, String>>[];
    for (final row in rows) {
      data.add(row.toStringsMap());
    }
    try {
      return await _db.batchInsert(
        table: table,
        rows: data,
        conflictAlgorithm: conflictAlgorithm,
        verbose: verbose,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Uma consulta select com join simples
  Future<List<DbRow>> join({
    required final String table,
    required final String joinTable,
    required final String joinOn,
    final String columns = "*",
    final int? offset,
    final int? limit,
    final String? orderBy,
    final String? where,
    final String? groupBy,
    final bool verbose = false,
  }) async {
    try {
      final data = await _db.join(
        table: table,
        joinTable: joinTable,
        joinOn: joinOn,
        columns: columns,
        offset: offset,
        limit: limit,
        orderBy: orderBy,
        where: where,
        groupBy: groupBy,
        verbose: verbose,
      );
      return _rowsFromRawData(table, data);
    } catch (e) {
      rethrow;
    }
  }

  /// Uma consulta select com múltiplos joins
  Future<List<DbRow>> mJoin({
    required final String table,
    required final List<String> joinsTables,
    required final List<String> joinsOn,
    final String columns = "*",
    final int? offset,
    final int? limit,
    final String? orderBy,
    final String? where,
    final String? groupBy,
    final bool verbose = false,
  }) async {
    try {
      final data = await _db.mJoin(
        table: table,
        joinsTables: joinsTables,
        joinsOn: joinsOn,
        columns: columns,
        offset: offset,
        limit: limit,
        orderBy: orderBy,
        where: where,
        groupBy: groupBy,
        verbose: verbose,
      );
      return _rowsFromRawData(table, data);
    } catch (e) {
      rethrow;
    }
  }

  /// Elimina registos da base de dados
  Future<int> delete({
    required final String table,
    required final String where,
    final bool verbose = false,
  }) async =>
      _db.delete(table: table, where: where, verbose: verbose);

  /// Executa uma query SQL direta
  Future<List<Map<String, dynamic>>> query(
    final String q, {
    final bool verbose = false,
  }) async =>
      _db.query(q, verbose: verbose);

  /// Conta linhas numa tabela
  Future<int> count({
    required final String table,
    final String? where,
    final String columns = "id",
    final bool verbose = false,
  }) async =>
      _db.count(
        table: table,
        where: where,
        columns: columns,
        verbose: verbose,
      );

  List<DbRow> _rowsFromRawData(
      final String table, final List<Map<String, dynamic>> data) {
    final rows = <DbRow>[];
    final t = schema.table(table);
    if (t == null) {
      throw Exception("Tabela $table não encontrada no esquema");
    }
    for (final r in data) {
      rows.add(DbRow.fromMap(t, r));
    }
    return rows;
  }

  /// Verifica se um valor existe na tabela
  Future<bool> exists({
    required final String table,
    required final String where,
    final bool verbose = false,
  }) async =>
      _db.exists(table: table, where: where, verbose: verbose);

  /// Liberta recursos
  void dispose() => _db.dispose();
}
