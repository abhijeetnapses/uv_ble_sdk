import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'uv_ble_sdk_method_channel.dart';

abstract class UvBleSdkPlatform extends PlatformInterface {
  /// Constructs a UvBleSdkPlatform.
  UvBleSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static UvBleSdkPlatform _instance = MethodChannelUvBleSdk();

  /// The default instance of [UvBleSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelUvBleSdk].
  static UvBleSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [UvBleSdkPlatform] when
  /// they register themselves.
  static set instance(UvBleSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
