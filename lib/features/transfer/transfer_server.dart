import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'transfer_protocol.dart';

class TransferServer {
  Future<void> startListening(int port) async {
    final ServerSocket server =
        await ServerSocket.bind(InternetAddress.anyIPv4, port);

    print('Server listening on port $port');

    server.listen((Socket client) {
      print('Client connected');
      _receiveFile(client);
    });
  }

  Future<void> _receiveFile(Socket client) async {
    final List<int> buffer = [];

    int? headerLength;
    Map<String, dynamic>? header;

    IOSink? fileSink;
    int bytesReceived = 0;
    int? fileSize;

    await for (final List<int> chunk in client) {
      // Add newly received TCP bytes to the buffer.
      buffer.addAll(chunk);

      // STEP 1: Wait until we have exactly enough bytes
      // to read the 4-byte header length.
      if (headerLength == null && buffer.length >= 4) {
        final lengthBytes = buffer.sublist(0, 4);

        headerLength = TransferProtocol.decodeLength(lengthBytes);

        // Remove the 4 length bytes after processing them.
        buffer.removeRange(0, 4);

        print('Header length: $headerLength');
      }

      // STEP 2: Wait until the complete header has arrived.
      if (headerLength != null &&
          header == null &&
          buffer.length >= headerLength) {
        final headerBytes = buffer.sublist(0, headerLength);

        header = TransferProtocol.decodeHeader(headerBytes);

        // Remove the header from the buffer.
        buffer.removeRange(0, headerLength);

        final filename = header['filename'] as String;
        fileSize = header['filesize'] as int;

        print('Receiving: $filename');
        print('Size: $fileSize bytes');

        // Save inside the app's documents directory.
        final directory = await getApplicationDocumentsDirectory();

        final file = File(
          '${directory.path}/received_$filename',
        );

        fileSink = file.openWrite();
      }

      // STEP 3: Write remaining bytes as file data.
      if (header != null && buffer.isNotEmpty) {
        final remaining = fileSize! - bytesReceived;

        final bytesToWrite =
            buffer.length > remaining ? remaining : buffer.length;

        fileSink!.add(buffer.sublist(0, bytesToWrite));

        bytesReceived += bytesToWrite;

        buffer.removeRange(0, bytesToWrite);

        print('Received: $bytesReceived / $fileSize bytes');

        // File transfer is complete.
        if (bytesReceived == fileSize) {
          await fileSink.close();

          print('File received successfully');

          await client.close();
          return;
        }
      }
    }

    // Clean up if the connection closes unexpectedly.
    await fileSink?.close();
  }
}