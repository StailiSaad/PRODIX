import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (Platform.isMacOS) {
      return macos;
    }
    if (Platform.isIOS) {
      return ios;
    }
    if (Platform.isAndroid) {
      return android;
    }
    // Fallback for desktop/web
    return android;

  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDRhTHnOEVXISjNMOPrXSfc1TrJetzwmCQ',
    appId: '1:1057439091548:android:7b2ebc54fbd56989b58f99',
    messagingSenderId: '1057439091548',
    projectId: 'prodix-6889a',
    storageBucket: 'prodix-6889a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC-q_1UlUy0xNOkt_Q8HiTNenBwOtXLRjw',
    appId: '1:1057439091548:ios:a514a93a5b62da57b58f99',
    messagingSenderId: '1057439091548',
    projectId: 'prodix-6889a',
    storageBucket: 'prodix-6889a.firebasestorage.app',
    iosBundleId: 'com.example.prodix',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '',
    projectId: '',
    storageBucket: '',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '',
    projectId: '',
    storageBucket: '',
  );
}