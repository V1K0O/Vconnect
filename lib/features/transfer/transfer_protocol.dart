
import 'dart:convert';
import 'dart:typed_data';

class TransferProtocol {
  // ============================================================
  // MESSAGE TYPES
  // ============================================================

  static const String msgConnectionRequest =
      'CONNECTION_REQUEST';

  static const String msgConnectionAccepted =
      'CONNECTION_ACCEPTED';

  static const String msgConnectionRejected =
      'CONNECTION_REJECTED';

  static const String msgFileTransfer =
      'FILE_TRANSFER';

  // ============================================================
  // FILE TRANSFER HEADER
  // ============================================================

  static List<int> encodeHeader(
    String filename,
    int filesize,
    String mimetype,
  ) {
    final Map<String, dynamic> header = {
      'type': msgFileTransfer,
      'filename': filename,
      'filesize': filesize,
      'mimetype': mimetype,
    };

    final String jsonString = jsonEncode(header);

    return utf8.encode(jsonString);
  }

  // ============================================================
  // CONNECTION REQUEST
  // ============================================================

  static List<int> encodeConnectionRequest(
    String deviceName,
  ) {
    final Map<String, dynamic> header = {
      'type': msgConnectionRequest,
      'deviceName': deviceName,
    };

    final String jsonString = jsonEncode(header);

    return utf8.encode(jsonString);
  }

  // ============================================================
  // CONNECTION ACCEPTED
  // ============================================================

  static List<int> encodeConnectionAccepted() {
    final Map<String, dynamic> header = {
      'type': msgConnectionAccepted,
    };

    final String jsonString = jsonEncode(header);

    return utf8.encode(jsonString);
  }

  // ============================================================
  // CONNECTION REJECTED
  // ============================================================

  static List<int> encodeConnectionRejected() {
    final Map<String, dynamic> header = {
      'type': msgConnectionRejected,
    };

    final String jsonString = jsonEncode(header);

    return utf8.encode(jsonString);
  }

  // ============================================================
  // DECODE JSON HEADER
  // ============================================================

  static Map<String, dynamic> decodeHeader(
    List<int> bytes,
  ) {
    final String jsonString = utf8.decode(bytes);

    return jsonDecode(jsonString)
        as Map<String, dynamic>;
  }

  // ============================================================
  // ENCODE LENGTH
  //
  // Every message starts with:
  //
  // [4 BYTES LENGTH]
  // [JSON HEADER]
  //
  // ============================================================

  static List<int> encodeLength(int length) {
    final ByteData data = ByteData(4);

    data.setInt32(0, length);

    return data.buffer.asUint8List();
  }

  // ============================================================
  // DECODE LENGTH
  // ============================================================

  static int decodeLength(
    List<int> bytes,
  ) {
    final ByteData data =
        ByteData.sublistView(
      Uint8List.fromList(bytes),
    );

    return data.getInt32(0);
  }
}

