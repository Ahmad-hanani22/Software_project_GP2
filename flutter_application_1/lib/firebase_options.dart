// File generated using FlutterFire CLI
// https://firebase.flutter.dev/docs/cli

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC-4Ks0gQj86FbHIKMxbW-V9biIgR2C7nI',
    appId: '1:214403166778:web:093cac0fa3382e9835fb03',
    messagingSenderId: '214403166778',
    projectId: 'shaqati-e900c',
    authDomain: 'shaqati-e900c.firebaseapp.com',
    storageBucket: 'shaqati-e900c.firebasestorage.app',
    measurementId: 'G-5QZ49VNLQ1',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDo1p1XtlLrpHGQeOo_nYuLfGNSDK2pTI8',
    appId: '1:214403166778:android:5cdeff1bc8aa21ef35fb03',
    messagingSenderId: '214403166778',
    projectId: 'shaqati-e900c',
    storageBucket: 'shaqati-e900c.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDo1p1XtlLrpHGQeOo_nYuLfGNSDK2pTI8',
    appId: '1:214403166778:ios:xxxxx',
    messagingSenderId: '214403166778',
    projectId: 'shaqati-e900c',
    storageBucket: 'shaqati-e900c.firebasestorage.app',
    iosBundleId: 'com.example.flutterApplication1',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDo1p1XtlLrpHGQeOo_nYuLfGNSDK2pTI8',
    appId: '1:214403166778:ios:xxxxx',
    messagingSenderId: '214403166778',
    projectId: 'shaqati-e900c',
    storageBucket: 'shaqati-e900c.firebasestorage.app',
    iosBundleId: 'com.example.flutterApplication1',
  );
}

