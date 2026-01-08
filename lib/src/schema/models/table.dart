import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'column.dart';

/// Tipos de ações on delete para chaves estrangeiras
enum OnDelete {
  /// Elimina os filhos quando a chave estrangeira é eliminada
  cascade,

  /// Protege os filhos quando a chave estrangeira é eliminada
  restrict,

  /// Define os filhos como nulos quando a chave estrangeira é eliminada
  setNull,

  /// Define os filhos para o valor padrão quando a chave estrangeira é eliminada
  setDefault
}

/// A classe usada para criar tabelas
class DbTable {
  /// Construtor padrão
  DbTable(this.name);

  /// Nome da tabela: sem espaços
  final String name;

  final List<String> _columns = <String>["id INTEGER PRIMARY KEY"];
  final List<String> _queries = <String>[];
  final List<DbColumn> _columnsData = <DbColumn>[];
  final List<String> _fkConstraints = <String>[];

  /// Informação das colunas
  List<DbColumn> get columns => _columnsData;

  /// As colunas de chave estrangeira
  List<DbColumn> get foreignKeys => _foreignKeys();

  /// Obtém a lista de queries para a inicialização da base de dados
  List<String> get queries => _getQueries();

  /// Obtém as restrições da tabela
  List<String> get constraints => _fkConstraints;

  /// Verifica se uma coluna existe
  bool hasColumn(final String name) => _hasColumn(name);

  /// Obtém uma coluna pelo nome
  DbColumn? column(final String name) {
    DbColumn? col;
    for (final c in _columnsData) {
      if (c.name == name) {
        col = c;
        break;
      }
    }
    return col;
  }

  /// Adiciona um índice a uma coluna
  void index(final String column, {final String? indexName}) {
    final idxName = indexName ?? "idx_$column";
    final q = "CREATE UNIQUE INDEX IF NOT EXISTS $idxName ON $name($column)";
    _queries.add(q);
  }

  /// Adiciona uma restrição de unicidade para valores combinados de duas colunas
  void uniqueTogether(final String column1, final String column2) {
    final q = 'UNIQUE("$column1", "$column2")';
    _columns.add(q);
  }

  /// Adiciona uma chave estrangeira a uma coluna
  void foreignKey(final String name,
      {final String? reference,
      final bool nullable = false,
      final bool unique = false,
      final String? defaultValue,
      final OnDelete onDelete = OnDelete.restrict}) {
    var q = "$name INTEGER";
    if (unique) {
      q += " UNIQUE";
    }
    if (!nullable) {
      q += " NOT NULL";
    }
    if (defaultValue != null) {
      q += " DEFAULT $defaultValue";
    }
    String fk;
    fk = "  FOREIGN KEY ($name)\n";
    final ref = reference ?? name;
    fk += "  REFERENCES $ref(id)\n";
    fk += "  ON DELETE ";
    switch (onDelete) {
      case OnDelete.cascade:
        fk += "CASCADE";
        break;
      case OnDelete.setNull:
        fk += "SET NULL";
        break;
      case OnDelete.setDefault:
        fk += "SET DEFAULT";
        break;
      default:
        fk += "RESTRICT";
    }
    _columns.add(q);
    _fkConstraints.add(fk);
    _columnsData.add(DbColumn(
        name: name,
        unique: unique,
        nullable: nullable,
        defaultValue: defaultValue,
        type: DbColumnType.integer,
        isForeignKey: true,
        reference: ref,
        onDelete: onDelete));
  }

  /// Adiciona uma coluna varchar
  void varchar(final String name,
      {final int? maxLength,
      final bool nullable = false,
      final bool unique = false,
      final String? defaultValue,
      final String? check}) {
    var q = "$name VARCHAR";
    if (maxLength != null) {
      q += "($maxLength)";
    }
    if (unique) {
      q += " UNIQUE";
    }
    if (!nullable) {
      q += " NOT NULL";
    }
    if (defaultValue != null) {
      q += " DEFAULT $defaultValue";
    }
    if (check != null) {
      q += " CHECK($check)";
    }
    _columns.add(q);
    _columnsData.add(DbColumn(
        name: name,
        unique: unique,
        nullable: nullable,
        defaultValue: defaultValue,
        check: check,
        type: DbColumnType.varchar));
  }

  /// Adiciona uma coluna de texto
  void text(final String name,
      {final bool nullable = false,
      final bool unique = false,
      final String? defaultValue,
      final String? check}) {
    var q = "$name TEXT";
    if (unique) {
      q += " UNIQUE";
    }
    if (!nullable) {
      q += " NOT NULL";
    }
    if (defaultValue != null) {
      q += " DEFAULT $defaultValue";
    }
    if (check != null) {
      q += " CHECK($check)";
    }
    _columns.add(q);
    _columnsData.add(DbColumn(
        name: name,
        unique: unique,
        nullable: nullable,
        defaultValue: defaultValue,
        check: check,
        type: DbColumnType.text));
  }

  /// Adiciona uma coluna real (float)
  void real(final String name,
      {final bool nullable = false,
      final bool unique = false,
      final double? defaultValue,
      final String? check}) {
    var q = "$name REAL";
    if (unique) {
      q += " UNIQUE";
    }
    if (!nullable) {
      q += " NOT NULL";
    }
    if (defaultValue != null) {
      q += " DEFAULT $defaultValue";
    }
    if (check != null) {
      q += " CHECK($check)";
    }
    _columns.add(q);
    _columnsData.add(DbColumn(
        name: name,
        unique: unique,
        nullable: nullable,
        defaultValue: defaultValue != null ? "$defaultValue" : null,
        check: check,
        type: DbColumnType.real));
  }

  /// Adiciona uma coluna inteira
  void integer(
    final String name, {
    final bool nullable = false,
    final bool unique = false,
    final int? defaultValue,
    final String? check,
  }) {
    var q = "$name INTEGER";
    if (unique) {
      q += " UNIQUE";
    }
    if (!nullable) {
      q += " NOT NULL";
    }
    if (defaultValue != null) {
      q += " DEFAULT $defaultValue";
    }
    if (check != null) {
      q += " CHECK($check)";
    }
    _columns.add(q);
    _columnsData.add(DbColumn(
        name: name,
        unique: unique,
        nullable: nullable,
        defaultValue: defaultValue != null ? "$defaultValue" : null,
        check: check,
        type: DbColumnType.integer));
  }

  /// Adiciona uma coluna booleana
  void boolean(final String name, {required final bool defaultValue}) {
    var q = "$name BOOLEAN";
    q += " DEFAULT ${defaultValue ? 1 : 0}";
    _columns.add(q);
    _columnsData.add(DbColumn(
        name: name, defaultValue: "$defaultValue", type: DbColumnType.boolean));
  }

  /// Adiciona uma coluna blob
  void blob(
    final String name, {
    final bool nullable = false,
    final bool unique = false,
    final Uint8List? defaultValue,
    final String? check,
  }) {
    var q = "$name BLOB";
    if (unique) {
      q += " UNIQUE";
    }
    if (!nullable) {
      q += " NOT NULL";
    }
    if (defaultValue != null) {
      q += " DEFAULT $defaultValue";
    }
    if (check != null) {
      q += " CHECK($check)";
    }
    _columns.add(q);
    _columnsData.add(DbColumn(
        name: name,
        unique: unique,
        nullable: nullable,
        defaultValue: defaultValue != null ? "$defaultValue" : null,
        check: check,
        type: DbColumnType.blob));
  }

  /// Adiciona um timestamp automático
  void timestamp([final String name = "timestamp"]) {
    final q =
        "$name INTEGER DEFAULT (cast(strftime('%s','now') as int)) NOT NULL";
    _columns.add(q);
    _columnsData.add(DbColumn(name: name, type: DbColumnType.timestamp));
  }

  /// Imprime as queries a executar para a inicialização da base de dados
  void printQueries() {
    for (final q in queries) {
      print("----------");
      print(q);
    }
  }

  /// Imprime uma descrição do esquema
  void describe({final String spacer = ""}) {
    print("${spacer}Table $name:");
    for (final column in columns) {
      // Nota: assumindo que DbColumn tem o método describe ajustado para null safety
      print("$spacer  ${column}");
    }
  }

  @override
  String toString() => name;

  /// A string para a query de criação da tabela
  String queryString() {
    var q = "CREATE TABLE IF NOT EXISTS $name (\n";
    q += _columns.join(",\n");
    if (_fkConstraints.isNotEmpty) {
      q += ",\n";
      q += _fkConstraints.join(",\n");
    }
    return q += "\n)";
  }

  List<String> _getQueries() {
    final qs = <String>[this.queryString(), ..._queries];
    return qs;
  }

  List<DbColumn> _foreignKeys() {
    final fks = <DbColumn>[];
    for (final col in _columnsData) {
      if (col.isForeignKey) {
        fks.add(col);
      }
    }
    return fks;
  }

  bool _hasColumn(final String name) {
    final col = column(name);
    return col != null;
  }
}
