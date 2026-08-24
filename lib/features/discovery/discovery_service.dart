import 'package:nsd/nsd.dart';



class DiscoveryService {
  Registration? _registration;
  Discovery? _discovery;
  
  Future<void> startAdvertising(int port) async {
    _registration = await register(Service(
    name: "Android",
    type: "_mediatransfer._tcp",
    port: 4040,
    ));
  }

Future<void> deviceDiscovery(void Function(dynamic peer) onPeerFound,) async {
  _discovery = await startDiscovery(
    '_mediatransfer._tcp',
    ipLookupType: IpLookupType.any,
  );

  final discovery = _discovery;

  if (discovery == null) {
    print('Failed to start discovery');
    return;
  }

  discovery.addServiceListener((service, status) {
    if (status == ServiceStatus.found) {
  print('Found peer: ${service.name}');
  onPeerFound(service);
}
  });
}

Future<void> stopAll() async {
    if (_registration != null) await unregister(_registration!);
    if (_discovery != null) await stopDiscovery(_discovery!);
  }

}