import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA9NJ_psfn6yne6aSV7C7QWUDddPICqxKM',
    appId: '1:128572934581:android:17a4d37b9a18ea3df531fc',
    messagingSenderId: '128572934581',
    projectId: 'app-quan-ly-ban-hang-aa6cc',
    storageBucket: 'app-quan-ly-ban-hang-aa6cc.appspot.com',
  );
}