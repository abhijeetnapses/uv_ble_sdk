import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:uv_ble_sdk/uv_ble_sdk_method_channel.dart';
import 'package:uv_ble_sdk/uv_ble_sdk_platform_interface.dart';

class MockUvBleSdkPlatform with MockPlatformInterfaceMixin implements UvBleSdkPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final UvBleSdkPlatform initialPlatform = UvBleSdkPlatform.instance;

  test('$MethodChannelUvBleSdk is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelUvBleSdk>());
  });

  test('getPlatformVersion', () async {
    // UvBleSdk uvBleSdkPlugin = UvBleSdk.instance;
    // MockUvBleSdkPlatform fakePlatform = MockUvBleSdkPlatform();
    // UvBleSdkPlatform.instance = fakePlatform;
  });
}
