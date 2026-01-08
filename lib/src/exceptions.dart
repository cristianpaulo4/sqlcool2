class DatabaseNotReady implements Exception {
  DatabaseNotReady([this.message]);
  String? message;
  final String _msg =
      "The Sqlcool database is not ready. This happens when a query is "
      "fired and the database has not finished initializing.";

  @override
  String toString() => message ?? _msg;
}

class OnDeleteConstraintUnknown implements Exception {
  OnDeleteConstraintUnknown(this.message);
  final String message;
}

class DatabaseAssetProblem implements Exception {
  DatabaseAssetProblem(this.message);
  final String message;
}

class ReadQueryException implements Exception {
  ReadQueryException(this.message);
  final String message;
}

class WriteQueryException implements Exception {
  WriteQueryException(this.message);
  final String message;
}

class RawQueryException implements Exception {
  RawQueryException(this.message);
  final String message;
}
