import 'dart:io';

import 'transfer_protocol.dart';

class TransferClient {
  Socket? _socket;

  Future<void> connect(String host, int port) async {
    _socket = await Socket.connect(host, port);

    print('Connected to server');
  }

  Future<void> sendFile(
    File file, {
    required void Function(int sent, int total) onProgress,
  }) async {
    if (_socket == null) {
      throw Exception('Not connected to server');
    }

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

    // Send 4 bytes containing the header length
    final headerLength = TransferProtocol.encodeLength(header.length);
    _socket!.add(headerLength);

    // Send the header
    _socket!.add(header);
    await _socket!.flush();

    print('Sending: $fileName');
    print('Size: $fileSize bytes');

    int sentBytes = 0;

    // Send actual file bytes
    await for (final chunk in file.openRead()) {
      _socket!.add(chunk);

      sentBytes += chunk.length;

      // Update UI progress
      onProgress(sentBytes, fileSize);
    }

    await _socket!.flush();

    print('File sent successfully');
  }

  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
  }
}