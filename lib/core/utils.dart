import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:uv_ble_sdk/core/constants.dart';
import 'package:uv_ble_sdk/uv_ble_sdk.dart';

class Utils {
  static const String _logTag = "UVSDK";

  static printLogs(String logString) {
    if (UvBleSdk.instance.loggingEnabled) log("$_logTag: $logString");
  }

  static BluetoothDevice? searchForUVDevice(List<BluetoothDevice> devices) {
    try {
      return devices
          .firstWhere((element) => Constants.supportedDeviceName.contains(element.advName));
    } catch (e) {
      Utils.printLogs(e.toString());
    }
    return null;
  }

  static BluetoothDevice? searchForUVDeviceFromScanResult(List<ScanResult> devices) {
    try {
      return devices.firstWhere((element) {
        if (kDebugMode) {
          print(element.device.advName);
        }
        return Constants.supportedDeviceName.contains(element.device.advName);
      }).device;
    } catch (e) {
      Utils.printLogs(e.toString());
    }
    return null;
  }
}
