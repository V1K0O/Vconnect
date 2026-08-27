import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'transfer_protocol.dart';

class TransferServer {
  // Callback to notify main.dart when a file is completely received.
  final void Function(String filePath)? onFileReceived;

  TransferServer({
    this.onFileReceived,
  });

  Future<List<File>> getReceivedFiles() async {
    final directory = await getApplicationDocumentsDirectory();

    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) {
          final filename =
              file.path.split(Platform.pathSeparator).last;

          return filename.startsWith('received_');
        })
        .toList();

    return files;
  }


  Future<void> startListening(int port) async {
    final ServerSocket server =
        await ServerSocket.bind(
      InternetAddress.anyIPv4,
      port,
    );

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

    // Path of the file currently being received.
    String? savedFilePath;

    await for (final List<int> chunk in client) {
      // Add newly received TCP bytes to the buffer.
      buffer.addAll(chunk);


      if (headerLength == null && buffer.length >= 4) {
        final lengthBytes = buffer.sublist(0, 4);

        headerLength =
            TransferProtocol.decodeLength(lengthBytes);

        // Remove the 4 length bytes.
        buffer.removeRange(0, 4);

        print('Header length: $headerLength');
      }


      if (headerLength != null &&
          header == null &&
          buffer.length >= headerLength!) {
        final headerBytes =
            buffer.sublist(0, headerLength!);

        header =
            TransferProtocol.decodeHeader(headerBytes);

        // Remove the header from the buffer.
        buffer.removeRange(0, headerLength!);

        final filename =
            header!['filename'] as String;

        fileSize =
            header!['filesize'] as int;

        print('Receiving: $filename');
        print('Size: $fileSize bytes');

        // Get application documents directory.
        final directory =
            await getApplicationDocumentsDirectory();

        final file = File(
          '${directory.path}/received_$filename',
        );

        // Remember the complete path.
        savedFilePath = file.path;

        print('Saving to: $savedFilePath');

        fileSink = file.openWrite();
      }


      if (header != null && buffer.isNotEmpty) {
        final remaining =
            fileSize! - bytesReceived;

        final bytesToWrite =
            buffer.length > remaining
                ? remaining
                : buffer.length;

        fileSink!.add(
          buffer.sublist(0, bytesToWrite),
        );

        bytesReceived += bytesToWrite;

        buffer.removeRange(
          0,
          bytesToWrite,
        );

        print(
          'Received: '
          '$bytesReceived / $fileSize bytes',
        );


        if (bytesReceived == fileSize) {
          await fileSink.close();

          print('File received successfully');

          // Notify main.dart.
          if (savedFilePath != null) {
            onFileReceived?.call(savedFilePath!);
          }

          // Reset for next file.
          buffer.clear();

          headerLength = null;
          header = null;

          fileSink = null;

          bytesReceived = 0;
          fileSize = null;

          savedFilePath = null;
        }
      }
    }

    await fileSink?.close();
  }
}