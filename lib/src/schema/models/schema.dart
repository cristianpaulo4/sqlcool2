import 'table.dart';

/// A representação do esquema da base de dados
class DbSchema {
  /// Fornece um conjunto de [DbTable]
  DbSchema([final Set<DbTable>? tables]) {
    this.tables = tables ?? <DbTable>{};
  }

  /// As tabelas na base de dados
  late Set<DbTable> tables;

  /// Obtém uma [DbTable] no esquema a partir do seu nome
  DbTable? table(final String name) {
    for (final table in tables) {
      if (table.name == name) return table;
    }
    return null;
  }

  /// Verifica se uma tabela existe no esquema
  bool hasTable(final String name) {
    for (final table in tables) {
      if (table.name == name) return true;
    }
    return false;
  }

  /// Imprime uma descrição do esquema
  void describe() {
    for (final table in tables) {
      print("Tabela: ${table.name}");
    }
  }
}
