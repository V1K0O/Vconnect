import 'dart:io';
import 'transfer_protocol.dart';
import 'package:path_provider/path_provider.dart';

class TransferClient {
  Socket? _socket;

  Future<void> connect(String host, int port) async {
    _socket = await Socket.connect(host, port);

    print('Connected to server');
  }

  Future<void> sendFile(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw Exception('File does not exist');
    }

    final fileName = file.path.split(Platform.pathSeparator).last;
    final fileSize = await file.length();

    final header = TransferProtocol.encodeHeader(
      fileName,
      fileSize,
      'application/octet-stream',
    );

    // Send 4 bytes containing the header length first.
    final headerLength = TransferProtocol.encodeLength(header.length);
    _socket!.add(headerLength);

    // Then send the header.
    _socket!.add(header);
    await _socket!.flush();

    print('Sending: $fileName');
    print('Size: $fileSize bytes');

    // Finally, send the actual file bytes.
    await for (final chunk in file.openRead()) {
      _socket!.add(chunk);
    }

    await _socket!.flush();

    print('File sent successfully');
  }

  Future<void> sendTestFile() async {
  // Create a small test file in the documents directory
  final directory = await getApplicationDocumentsDirectory();
  final testFile = File('${directory.path}/test.txt');
  await testFile.writeAsString('Hello from the other side!');
  await sendFile(testFile.path);
}


  

  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
  }
}