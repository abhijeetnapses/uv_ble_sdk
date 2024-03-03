import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'uv_ble_sdk_platform_interface.dart';

/// An implementation of [UvBleSdkPlatform] that uses method channels.
class MethodChannelUvBleSdk extends UvBleSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('uv_ble_sdk');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
