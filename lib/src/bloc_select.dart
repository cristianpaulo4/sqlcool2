import 'dart:async';
import 'package:flutter/foundation.dart';
import 'database.dart';

class SelectBloc {
  SelectBloc({
    required this.database,
    this.query,
    this.table,
    this.offset,
    this.limit,
    this.where,
    this.columns = "*",
    this.joinTable,
    this.joinOn,
    this.orderBy,
    this.reactive = false,
    this.verbose = false,
  }) {
    if ((query == null) && (table == null)) {
      throw ArgumentError("Please provide either a table or a query argument");
    }

    _getItems();
    if (reactive) {
      _changefeed = database.changefeed.listen((final change) {
        if ((table != null && change.table == table) ||
            (query != null && change.query == query)) {
          _getItems();
        }
      });
    }
  }

  final Db database;
  final String? table;
  final String? query;
  int? offset;
  int? limit;
  String? orderBy;
  String columns;
  String? where;
  String? joinTable;
  String? joinOn;
  bool reactive;
  bool verbose;

  late StreamSubscription _changefeed;
  final _itemController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  bool _changefeedIsActive = true;

  Stream<List<Map<String, dynamic>>> get items => _itemController.stream;

  void dispose() {
    _itemController.close();
    if (reactive) {
      _changefeed.cancel();
      _changefeedIsActive = false;
    }
  }

  Future<void> _getItems() async {
    var res = <Map<String, dynamic>>[];
    try {
      if (query != null) {
        res = await database.query(query!, verbose: verbose);
      } else if (table != null) {
        var q = "SELECT $columns FROM $table";
        if (where != null) q += " WHERE $where";
        res = await database.query(q, verbose: verbose);
      }
      if (_changefeedIsActive) _itemController.sink.add(res);
    } catch (e) {
      if (_changefeedIsActive) _itemController.sink.addError(e);
    }
  }
}
