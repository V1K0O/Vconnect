import 'package:flutter/material.dart';

import 'features/discovery/discovery_service.dart';
import 'features/transfer/transfer_server.dart';
import 'features/transfer/transfer_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final DiscoveryService discoveryService = DiscoveryService();

  final TransferServer transferServer = TransferServer();
  final TransferClient transferClient = TransferClient();

  @override
  void initState() {
    super.initState();

    // Start listening for incoming TCP connections.
    transferServer.startListening(4040);

    // Advertise this device and its TCP port.
    discoveryService.startAdvertising(4040);

    // Start looking for other devices.
    discoveryService.deviceDiscovery((peer) {
      print('Connecting to ${peer.host}:${peer.port}');

      transferClient.connect(peer.host, peer.port);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Searching for peers...'),
        ),
      ),
    );
  }
}