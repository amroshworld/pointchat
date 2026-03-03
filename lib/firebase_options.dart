import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        return web;
      case TargetPlatform.windows:
        return web;
      case TargetPlatform.linux:
        return web;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAqTK3GULVmQmNmMASIgnF_YSgP9sgF9iI',
    appId: '1:661146478033:android:c361714cb4106e7ebe2cf0',
    messagingSenderId: '661146478033',
    projectId: 'point-chat-f22b3',
    storageBucket: 'point-chat-f22b3.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAa6HSxSiEARuMEIMa5PP3yA4LXlsFz3Is',
    appId: '1:661146478033:ios:87b7ed759d9fc808be2cf0',
    messagingSenderId: '661146478033',
    projectId: 'point-chat-f22b3',
    storageBucket: 'point-chat-f22b3.firebasestorage.app',
    iosBundleId: 'com.amrosh.Pointchat',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBfIrXkOYeyEddSwi2IZALmlssytIsSJDE',
    appId: '1:661146478033:web:163c3fd07355e4a1be2cf0',
    messagingSenderId: '661146478033',
    projectId: 'point-chat-f22b3',
    storageBucket: 'point-chat-f22b3.firebasestorage.app',
    authDomain: 'point-chat-f22b3.firebaseapp.com',
  );
}
