import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'column.dart';
import 'table.dart';

/// Um registo de base de dados
@immutable
class DbRecord<T> {
  /// Construtor padrão
  DbRecord(this.key, this.value) {
    if (!(value is T)) {
      throw ArgumentError(
          "Providencie um valor do tipo $T para o registo $key");
    }
  }

  /// O nome da coluna do registo
  final String key;

  /// O valor do registo
  final T value;

  /// Obtém o tipo
  Type get type => T;

  /// Obtém uma cópia de um registo com um tipo específico
  ///
  /// Tipos aceites: String, int, double, bool e Uint8List
  DbRecord? copyWithType(final Type t) {
    switch (t) {
      case String:
        return DbRecord<String>(key, value.toString());
      case int:
        try {
          final v = int.parse(value.toString());
          return DbRecord<int>(key, v);
        } catch (e) {
          throw Exception(
              "Não é possível converter $value para $t para a chave $key");
        }
      case double:
        try {
          final v = double.parse(value.toString());
          return DbRecord<double>(key, v);
        } catch (e) {
          throw Exception(
              "Não é possível converter $value para $t para a chave $key");
        }
      case bool:
        final dynamic val = value.toString();
        if (val == "true" || val == "1") {
          return DbRecord<bool>(key, true);
        } else if (val == "false" || val == "0") {
          return DbRecord<bool>(key, false);
        } else {
          throw Exception(
              "Não é possível converter $value para $t para a chave $key");
        }
      case Uint8List:
        try {
          final v = value as Uint8List;
          return DbRecord<Uint8List>(key, v);
        } catch (e) {
          throw Exception(
              "Não é possível converter $value para $t para a chave $key");
        }
    }
    return null;
  }

  @override
  String toString() {
    return "$key : $value <$type>";
  }
}

/// Uma linha da base de dados
@immutable
class DbRow {
  /// Construtor padrão
  const DbRow(this.records);

  /// Constrói uma linha a partir de um único registo
  factory DbRow.fromRecord(final DbRecord record) => DbRow(<DbRecord>[record]);

  /// Cria a partir de um mapa vindo do Sqflite
  factory DbRow.fromMap(final DbTable table, final Map<String, dynamic> row) {
    final recs = <DbRecord>[];
    row.forEach((final key, final dynamic value) {
      if (key == "id") {
        recs.add(DbRecord<int>(key, value as int));
      } else {
        final col = table.column(key);
        if (col == null) {
          recs.add(DbRecord<dynamic>(key, value));
        } else {
          switch (col.type) {
            case DbColumnType.varchar:
            case DbColumnType.text:
              recs.add(DbRecord<String>(key, value.toString()));
              break;
            case DbColumnType.integer:
            case DbColumnType.timestamp:
              recs.add(DbRecord<int>(key, value as int));
              break;
            case DbColumnType.real:
              recs.add(DbRecord<double>(key, (value as num).toDouble()));
              break;
            case DbColumnType.boolean:
              bool v;
              if (value == "false" || value == 0 || value == "0") {
                v = false;
              } else if (value == "true" || value == 1 || value == "1") {
                v = true;
              } else {
                throw Exception(
                    "Valor incorreto $value para o campo booleano $key");
              }
              recs.add(DbRecord<bool>(key, v));
              break;
            case DbColumnType.blob:
              recs.add(DbRecord<Uint8List>(key, value as Uint8List));
              break;
          }
        }
      }
    });
    return DbRow(recs);
  }

  /// Os registos da linha
  final List<DbRecord> records;

  /// Obtém o valor de um registo
  T? record<T>(final String key) {
    try {
      final rec = records.firstWhere((final r) => r.key == key);
      if (rec.type != dynamic) {
        return rec.value as T;
      } else {
        final r = rec.copyWithType(T);
        return r?.value as T?;
      }
    } catch (e) {
      return null;
    }
  }

  /// Converte para um mapa
  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{};
    for (final r in records) {
      data[r.key] = r.value;
    }
    return data;
  }

  /// Converte para um mapa de strings
  Map<String, String> toStringsMap() {
    final data = <String, String>{};
    for (final r in records) {
      data[r.key] = r.value?.toString() ?? "NULL";
    }
    return data;
  }

  /// Obtém uma representação em string da linha
  String line() {
    final l = <String>[];
    for (final rec in records) {
      l.add("${rec.key} : ${rec.value}");
    }
    return l.join(",");
  }
}
