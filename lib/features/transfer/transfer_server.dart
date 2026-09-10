
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'transfer_protocol.dart';

class TransferServer {
  final void Function(String filePath)? onFileReceived;

  final Future<bool> Function(String deviceName)?
      onConnectionRequest;

  TransferServer({
    this.onFileReceived,
    this.onConnectionRequest,
  });

  // ============================================================
  // GET RECEIVED FILES
  // ============================================================

  Future<List<File>> getReceivedFiles() async {
    final directory =
        await getApplicationDocumentsDirectory();

    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) {
      final filename =
          file.path.split(Platform.pathSeparator).last;

      return filename.startsWith('received_');
    }).toList();

    return files;
  }

  // ============================================================
  // START SERVER
  // ============================================================

  Future<void> startListening(int port) async {
    final ServerSocket server =
        await ServerSocket.bind(
      InternetAddress.anyIPv4,
      port,
    );

    print(
      'Server listening on port $port',
    );

    server.listen((Socket client) {
      print('Client connected');

      _handleClient(client);
    });
  }

  // ============================================================
  // HANDLE CLIENT
  // ============================================================

  Future<void> _handleClient(
    Socket client,
  ) async {
    try {
      await _receiveFile(client);
    } catch (e) {
      print(
        'Client error: $e',
      );
    } finally {
      await client.close();

      print(
        'Client disconnected',
      );
    }
  }

  // ============================================================
  // RECEIVE MESSAGES
  // ============================================================

  Future<void> _receiveFile(
    Socket client,
  ) async {
    final List<int> buffer = [];

    int? headerLength;

    Map<String, dynamic>? header;

    IOSink? fileSink;

    int bytesReceived = 0;

    int? fileSize;

    String? savedFilePath;

    // ==========================================================
    // READ TCP STREAM
    // ==========================================================

    await for (
      final List<int> chunk in client
    ) {
      buffer.addAll(chunk);

      // ========================================================
      // STEP 1:
      // Read the 4-byte message length
      // ========================================================

      if (headerLength == null &&
          buffer.length >= 4) {
        final lengthBytes =
            buffer.sublist(0, 4);

        headerLength =
            TransferProtocol.decodeLength(
          lengthBytes,
        );

        buffer.removeRange(0, 4);

        print(
          'Header length: $headerLength',
        );
      }

      // ========================================================
      // STEP 2:
      // Read complete JSON header
      // ========================================================

      if (headerLength != null &&
          header == null &&
          buffer.length >= headerLength!) {
        final headerBytes =
            buffer.sublist(
          0,
          headerLength!,
        );

        header =
            TransferProtocol.decodeHeader(
          headerBytes,
        );

        buffer.removeRange(
          0,
          headerLength!,
        );

        final messageType =
            header!['type'];

        print(
          'Message type: $messageType',
        );

        // ======================================================
        // CONNECTION REQUEST
        // ======================================================

        if (messageType ==
            TransferProtocol
                .msgConnectionRequest) {
          final deviceName =
              header!['deviceName'] as String;

          print(
            'Connection request from: '
            '$deviceName',
          );

          print(
            'Calling onConnectionRequest...',
          );

          final accepted =
              await onConnectionRequest?.call(
                    deviceName,
                  ) ??
                  false;

          print(
            'User decision: $accepted',
          );

          // ====================================================
          // ACCEPT
          // ====================================================

          if (accepted) {
            print(
              'Connection accepted: '
              '$deviceName',
            );

            final response =
                TransferProtocol
                    .encodeConnectionAccepted();

            client.add(
              TransferProtocol.encodeLength(
                response.length,
              ),
            );

            client.add(response);

            await client.flush();

            print(
              'Sent CONNECTION_ACCEPTED',
            );
          }

          // ====================================================
          // REJECT
          // ====================================================

          else {
            print(
              'Connection rejected: '
              '$deviceName',
            );

            final response =
                TransferProtocol
                    .encodeConnectionRejected();

            client.add(
              TransferProtocol.encodeLength(
                response.length,
              ),
            );

            client.add(response);

            await client.flush();

            print(
              'Sent CONNECTION_REJECTED',
            );

            await client.close();

            return;
          }

          // Reset message state.
          headerLength = null;
          header = null;

          continue;
        }

        // ======================================================
        // FILE TRANSFER
        // ======================================================

        else if (messageType ==
            TransferProtocol
                .msgFileTransfer) {
          final filename =
              header!['filename'] as String;

          fileSize =
              header!['filesize'] as int;

          print(
            'Receiving: $filename',
          );

          print(
            'Size: $fileSize bytes',
          );

          final directory =
              await getApplicationDocumentsDirectory();

          final file = File(
            '${directory.path}/received_$filename',
          );

          savedFilePath =
              file.path;

          print(
            'Saving to: $savedFilePath',
          );

          fileSink =
              file.openWrite();
        }

        // ======================================================
        // UNKNOWN MESSAGE
        // ======================================================

        else {
          print(
            'Unknown message type: '
            '$messageType',
          );

          headerLength = null;
          header = null;

          continue;
        }
      }

      // ========================================================
      // STEP 3:
      // RECEIVE FILE DATA
      // ========================================================

      if (header != null &&
          header!['type'] ==
              TransferProtocol
                  .msgFileTransfer &&
          buffer.isNotEmpty) {
        final remaining =
            fileSize! - bytesReceived;

        final bytesToWrite =
            buffer.length > remaining
                ? remaining
                : buffer.length;

        fileSink!.add(
          buffer.sublist(
            0,
            bytesToWrite,
          ),
        );

        bytesReceived +=
            bytesToWrite;

        buffer.removeRange(
          0,
          bytesToWrite,
        );

        print(
          'Received: '
          '$bytesReceived / $fileSize bytes',
        );

        // ======================================================
        // FILE COMPLETE
        // ======================================================

        if (bytesReceived ==
            fileSize) {
          await fileSink.close();

          print(
            'File received successfully',
          );

          if (savedFilePath != null) {
            onFileReceived?.call(
              savedFilePath!,
            );
          }

          // Reset file state.
          headerLength = null;

          header = null;

          fileSink = null;

          bytesReceived = 0;

          fileSize = null;

          savedFilePath = null;

          print(
            'Ready to receive next message',
          );
        }
      }
    }

    await fileSink?.close();
  }
}

