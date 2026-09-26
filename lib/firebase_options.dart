// ignore_for_file: type=lint
// Generated Firebase options for the Mathalino Student App.
// These per-platform options ensure Firebase initializes with credentials
// that match the native configuration on each platform (avoiding the
// [core/duplicate-app] error caused by mismatch between the WEB apiKey
// hardcoded in main.dart and the ANDROID credentials auto-loaded from
// google-services.json).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

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
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for fuchsia.',
        );
    }
  }

  /// Android configuration (sourced from android/app/google-services.json).
  ///
  /// Project: readquest-efa09
  /// Package: com.mathalino.mathalino_student_app
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyADTYiA7OB7upL5SeMscgvs-HCXMlMtNmw',
    appId: '1:855967293515:android:5456a129e7e9b2bbd26dce',
    messagingSenderId: '855967293515',
    projectId: 'readquest-efa09',
    authDomain: 'readquest-efa09.firebaseapp.com',
    storageBucket: 'readquest-efa09.firebasestorage.app',
  );

  /// iOS configuration.
  ///
  /// No GoogleService-Info.plist is present in the project; web credentials are
  /// used as a fallback so the app compiles and can initialize on iOS if a
  /// plist is added later.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA0o6oyI9Sc_ARHjy9q01jPCO464ZfAbM0',
    appId: '1:855967293515:web:5e5d6aa40a91a374d26dce',
    messagingSenderId: '855967293515',
    projectId: 'readquest-efa09',
    authDomain: 'readquest-efa09.firebaseapp.com',
    storageBucket: 'readquest-efa09.firebasestorage.app',
    iosBundleId: 'com.mathalino.mathalino_student_app',
  );

  /// macOS configuration (fallback to web credentials; no native config).
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA0o6oyI9Sc_ARHjy9q01jPCO464ZfAbM0',
    appId: '1:855967293515:web:5e5d6aa40a91a374d26dce',
    messagingSenderId: '855967293515',
    projectId: 'readquest-efa09',
    authDomain: 'readquest-efa09.firebaseapp.com',
    storageBucket: 'readquest-efa09.firebasestorage.app',
  );

  /// Windows configuration (fallback to web credentials; no native config).
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyA0o6oyI9Sc_ARHjy9q01jPCO464ZfAbM0',
    appId: '1:855967293515:web:5e5d6aa40a91a374d26dce',
    messagingSenderId: '855967293515',
    projectId: 'readquest-efa09',
    authDomain: 'readquest-efa09.firebaseapp.com',
    storageBucket: 'readquest-efa09.firebasestorage.app',
  );

  /// Linux configuration (fallback to web credentials; no native config).
  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyA0o6oyI9Sc_ARHjy9q01jPCO464ZfAbM0',
    appId: '1:855967293515:web:5e5d6aa40a91a374d26dce',
    messagingSenderId: '855967293515',
    projectId: 'readquest-efa09',
    authDomain: 'readquest-efa09.firebaseapp.com',
    storageBucket: 'readquest-efa09.firebasestorage.app',
  );
}