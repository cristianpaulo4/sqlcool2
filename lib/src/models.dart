import 'package:flutter/foundation.dart';

enum DatabaseChange { insert, update, delete, upsert }

class DatabaseChangeEvent {
  DatabaseChangeEvent({
    required this.type,
    required this.value,
    required this.query,
    required this.table,
    required this.executionTime,
    this.data,
  });

  final DatabaseChange type;
  final int value;
  final String query;
  final num executionTime;
  final String table;
  final Map<String, String>? data;

  @override
  String toString() {
    return "$type no $table: $value item(s) em $executionTime ms";
  }
}
