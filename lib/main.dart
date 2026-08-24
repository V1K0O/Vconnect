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

    transferServer.startListening(4040);

    Future.delayed(const Duration(seconds: 2), () {
      discoveryService.startAdvertising(4040);

      Future.delayed(const Duration(seconds: 1), () {
        discoveryService.deviceDiscovery((peer) {
          print('Peer host: ${peer.host}');
          print('Peer port: ${peer.port}');
          print('Peer addresses: ${peer.addresses}');

          final address = peer.addresses?.isNotEmpty == true
              ? peer.addresses!.first.address
              : peer.host;

          if (address == null) {
            print('No address found for peer');
            return;
          }

          transferClient.connect(address, peer.port ?? 4040).then((_) {
            transferClient.sendTestFile();
          });
        });
      });
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