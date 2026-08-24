import 'dart:convert';
import 'dart:typed_data';

class TransferProtocol {
  static List<int> encodeHeader(
    String filename,
    int filesize,
    String mimetype,
  ) {
    final Map<String, dynamic> header = {
      'filename': filename,
      'filesize': filesize,
      'mimetype': mimetype,
    };

    final String jsonString = jsonEncode(header);

    return utf8.encode(jsonString);
  }

  static Map<String, dynamic> decodeHeader(List<int> bytes) {
    final String jsonString = utf8.decode(bytes);

    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  // Convert an integer into exactly 4 bytes.
  static List<int> encodeLength(int length) {
    final ByteData data = ByteData(4);

    data.setInt32(0, length);

    return data.buffer.asUint8List();
  }

  // Convert 4 bytes back into an integer.
  static int decodeLength(List<int> bytes) {
    final ByteData data = ByteData.sublistView(
      Uint8List.fromList(bytes),
    );

    return data.getInt32(0);
  }
}