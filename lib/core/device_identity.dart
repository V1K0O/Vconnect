import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdentity {
  static const String _prefsKey = 'device_identity_name';

  static final List<String> _adjectives = [
    'Blue', 'Red', 'Swift', 'Silent', 'Clever', 'Brave', 'Mighty', 
    'Wandering', 'Happy', 'Fierce', 'Cosmic', 'Neon', 'Golden'
  ];

  static final List<String> _animals = [
    'Fox', 'Bear', 'Wolf', 'Eagle', 'Tiger', 'Panda', 'Lion', 
    'Hawk', 'Shark', 'Falcon', 'Panther', 'Owl', 'Dolphin'
  ];

  /// Retrieves the saved device name, or generates and saves a new one on first launch.
  static Future<String> getDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if a name already exists
    String? savedName = prefs.getString(_prefsKey);
    if (savedName != null) {
      return savedName;
    }


    final random = Random();
    final adjective = _adjectives[random.nextInt(_adjectives.length)];
    final animal = _animals[random.nextInt(_animals.length)];
    

    final number = random.nextInt(9000) + 1000; 

    final newName = '$adjective-$animal-$number';

    // Save for subsequent launches
    await prefs.setString(_prefsKey, newName);

    return newName;
  }
  
  /// Optional utility to force reset the identity
  static Future<void> resetIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}