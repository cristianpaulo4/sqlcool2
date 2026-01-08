import 'package:flutter/foundation.dart';
import 'table.dart';

/// Uma representação de coluna de base de dados
@immutable
class DbColumn {
  /// Fornece um nome e um tipo
  const DbColumn({
    required this.name,
    required this.type,
    this.unique = false,
    this.nullable = false,
    this.check,
    this.defaultValue,
    this.isForeignKey = false,
    this.reference,
    this.onDelete,
  });

  /// O nome da coluna
  final String name;

  /// O tipo de dados da coluna
  final DbColumnType type;

  /// Se a coluna é única
  final bool unique;

  /// Se a coluna aceita nulos
  final bool nullable;

  /// O valor padrão da coluna
  final String? defaultValue;

  /// Uma restrição de verificação (CHECK)
  final String? check;

  /// Se a coluna é uma chave estrangeira
  final bool isForeignKey;

  /// Referência ao nome da tabela da chave estrangeira
  final String? reference;

  /// A restrição ON DELETE na chave estrangeira
  final OnDelete? onDelete;

  @override
  String toString() => "$name $type";
}

/// O tipo de uma coluna de base de dados
enum DbColumnType {
  varchar,
  integer,
  real,
  text,
  boolean,
  blob,
  timestamp,
}
