import 'package:uuid/uuid.dart';

class UuidHelper {
  UuidHelper._();

  static const Uuid _uuid = Uuid();

  static String generateUuid() => _uuid.v4();

  static String generateOperationId() =>
      'op_${_uuid.v4().replaceAll('-', '').substring(0, 16)}';
}
