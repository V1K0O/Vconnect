
import 'dart:async';
import 'dart:io';

import 'transfer_protocol.dart';

class TransferClient {
  Socket? _socket;

  String? _lastHost;

  int? _lastPort;

  String? _lastDeviceName;

  bool _isConnected = false;

  // ============================================================
  // CONNECT + HANDSHAKE
  // ============================================================

  Future<bool> connect(
    String host,
    int port,
    String deviceName,
  ) async {
    _lastHost = host;

    _lastPort = port;

    _lastDeviceName = deviceName;

    try {
      // Close old socket if it exists.
      await _socket?.close();

      _socket = null;

      _isConnected = false;

      print(
        'Connecting to $host:$port...',
      );

      // ========================================================
      // STEP 1:
      // Establish TCP connection
      // ========================================================

      _socket = await Socket.connect(
        host,
        port,
        timeout:
            const Duration(seconds: 10),
      );

      print(
        'TCP connection established',
      );

      // ========================================================
      // STEP 2:
      // Create CONNECTION_REQUEST
      // ========================================================

      final request =
          TransferProtocol
              .encodeConnectionRequest(
        deviceName,
      );

      // ========================================================
      // STEP 3:
      // Send request length
      // ========================================================

      _socket!.add(
        TransferProtocol.encodeLength(
          request.length,
        ),
      );

      // ========================================================
      // STEP 4:
      // Send request JSON
      // ========================================================

      _socket!.add(request);

      await _socket!.flush();

      print(
        'Sent CONNECTION_REQUEST '
        'from $deviceName',
      );

      // ========================================================
      // STEP 5:
      // Wait for server response
      // ========================================================

      final responseType =
          await _readHandshakeResponse();

      print(
        'Received handshake response: '
        '$responseType',
      );

      // ========================================================
      // STEP 6:
      // CONNECTION ACCEPTED
      // ========================================================

      if (responseType ==
          TransferProtocol
              .msgConnectionAccepted) {
        _isConnected = true;

        print(
          'Connection accepted by peer',
        );

        return true;
      }

      // ========================================================
      // STEP 7:
      // CONNECTION REJECTED
      // ========================================================

      if (responseType ==
          TransferProtocol
              .msgConnectionRejected) {
        print(
          'Connection rejected by peer',
        );

        _isConnected = false;

        await _socket?.close();

        _socket = null;

        return false;
      }

      // ========================================================
      // UNKNOWN RESPONSE
      // ========================================================

      print(
        'Unknown handshake response: '
        '$responseType',
      );

      _isConnected = false;

      await _socket?.close();

      _socket = null;

      return false;
    } catch (e) {
      print(
        'Connection failed: $e',
      );

      _isConnected = false;

      await _socket?.close();

      _socket = null;

      return false;
    }
  }

  // ============================================================
  // READ HANDSHAKE RESPONSE
  // ============================================================

  Future<String?> _readHandshakeResponse() async {
    final socket = _socket;

    if (socket == null) {
      return null;
    }

    final Completer<String?> completer =
        Completer<String?>();

    final List<int> buffer = [];

    late StreamSubscription<List<int>>
        subscription;

    subscription = socket.listen(
      (List<int> chunk) async {
        buffer.addAll(chunk);

        // Need 4 bytes for length.
        if (buffer.length < 4) {
          return;
        }

        final lengthBytes =
            buffer.sublist(0, 4);

        final messageLength =
            TransferProtocol.decodeLength(
          lengthBytes,
        );

        // Remove length.
        buffer.removeRange(0, 4);

        print(
          'Handshake response length: '
          '$messageLength',
        );

        // Wait until complete message.
        if (buffer.length <
            messageLength) {
          // Put the length back.
          buffer.insertAll(
            0,
            lengthBytes,
          );

          return;
        }

        final messageBytes =
            buffer.sublist(
          0,
          messageLength,
        );

        final header =
            TransferProtocol.decodeHeader(
          messageBytes,
        );

        final type =
            header['type'] as String?;

        if (!completer.isCompleted) {
          completer.complete(type);
        }

        await subscription.cancel();
      },
      onError: (Object error) async {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }

        await subscription.cancel();
      },
      onDone: () async {
        if (!completer.isCompleted) {
          completer.complete(null);
        }

        await subscription.cancel();
      },
    );

    return completer.future;
  }

  // ============================================================
  // ENSURE CONNECTION
  // ============================================================

  Future<void> _ensureConnected() async {
    if (_isConnected &&
        _socket != null) {
      return;
    }

    if (_lastHost == null ||
        _lastPort == null ||
        _lastDeviceName == null) {
      throw Exception(
        'No previous connection information available',
      );
    }

    print(
      'Connection lost. Reconnecting...',
    );

    final connected = await connect(
      _lastHost!,
      _lastPort!,
      _lastDeviceName!,
    );

    if (!connected) {
      throw Exception(
        'Connection rejected by peer',
      );
    }
  }

  // ============================================================
  // SEND FILE
  // ============================================================

  Future<void> sendFile(
    File file, {
    required void Function(
      int sent,
      int total,
    ) onProgress,
  }) async {
    await _ensureConnected();

    // ==========================================================
    // Check file
    // ==========================================================

    if (!await file.exists()) {
      throw Exception(
        'File does not exist',
      );
    }

    final fileName =
        file.path.split(
      Platform.pathSeparator,
    ).last;

    final fileSize =
        await file.length();

    // ==========================================================
    // Create file header
    // ==========================================================

    final header =
        TransferProtocol.encodeHeader(
      fileName,
      fileSize,
      'application/octet-stream',
    );

    // ==========================================================
    // Send header length
    // ==========================================================

    final headerLength =
        TransferProtocol.encodeLength(
      header.length,
    );

    _socket!.add(headerLength);

    // ==========================================================
    // Send header
    // ==========================================================

    _socket!.add(header);

    await _socket!.flush();

    print(
      'Sending: $fileName',
    );

    print(
      'Size: $fileSize bytes',
    );

    int sentBytes = 0;

    // ==========================================================
    // Send actual file
    // ==========================================================

    await for (
      final chunk in file.openRead()
    ) {
      _socket!.add(chunk);

      sentBytes += chunk.length;

      onProgress(
        sentBytes,
        fileSize,
      );
    }

    await _socket!.flush();

    print(
      'File sent successfully',
    );
  }

  // ============================================================
  // DISCONNECT
  // ============================================================

  Future<void> disconnect() async {
    _isConnected = false;

    await _socket?.close();

    _socket = null;

    print(
      'Disconnected',
    );
  }
}

