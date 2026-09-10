import 'package:media_transfer/core/device_identity.dart';
import 'package:nsd/nsd.dart';
import 'dart:io';



class DiscoveryService {
  Registration? _registration;
  Discovery? _discovery;
  
  Future<void> startAdvertising(int port) async {
    final deviceName = await DeviceIdentity.getDeviceName();
    _registration = await register(Service(
    name: deviceName,
    type: "_mediatransfer._tcp",
    port: 4040,
    ));
  }



  Future<String?> getLocalIpAddress() async {
  final interfaces = await NetworkInterface.list();
  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      if (address.type == InternetAddressType.IPv4 &&
          !address.isLoopback) {
        return address.address;
      }
    }
  }

  return null;
}



Future<void> deviceDiscovery(void Function(dynamic peer) onPeerFound,) async {
  _discovery = await startDiscovery(
    '_mediatransfer._tcp',
    ipLookupType: IpLookupType.any,
  );

  final ip1= await getLocalIpAddress();


  final discovery = _discovery;

  if (discovery == null) {
    print('Failed to start discovery');
    return;
  }

  discovery.addServiceListener((service, status) {
    
    if (status == ServiceStatus.found) {
        final ip2= service.addresses?.isNotEmpty==true?service.addresses!.first.address:null;

        if(ip2==null){
          print("No address for peer");
          return;
        }

        if(ip2==ip1){
          print("Discover Ourself,skip");
          return;
        }

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