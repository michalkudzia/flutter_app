export 'mapinsider_auth_stub.dart'
    if (dart.library.js_interop) 'mapinsider_auth_web.dart'
    if (dart.library.io) 'mapinsider_auth_native.dart';
