import 'package:sqlcool2/sqlcool.dart';

import 'conf.dart';

const table = "product";

Future<void> saveItem(String itemName) async {
  final row = DbRow(<DbRecord>[
    DbRecord<String>("name", itemName),
    DbRecord<int>("price", 50),
    DbRecord<int>("category", 1),
  ]);
  await db.insert(table: table, row: row, verbose: true);
}

Future<void> updateItem(String oldItemName, String newItemName) async {
  final row = DbRow(<DbRecord>[DbRecord<String>("name", newItemName)]);
  await db.update(
    table: table,
    where: 'name="$oldItemName"',
    row: row,
    verbose: true,
  );
}

Future<void> deleteItem(int itemId) async {
  await db.delete(table: table, where: 'id="$itemId"', verbose: true);
}
